# tvOS Simulator Login Issue — Investigation Report

**Branch:** `pr-1770-filters`
**Date:** 2026-05-25
**Scope:** Why the staged branch ships a hardcoded API key as a "login fallback" on simulator, and what the real root cause is.

---

## 1. What is currently in the staged branch

In `Shared/SwiftfinStore/SwiftinStore+UserState.swift`, the `accessToken` getter on `UserState` has been changed from:

```swift
guard let accessToken = Container.shared.keychainService().get("\(id)-accessToken") else {
    assertionFailure("access token missing in keychain")
    return ""
}
return accessToken
```

to:

```swift
if let accessToken = Container.shared.keychainService().get("\(id)-accessToken") {
    return accessToken
}
#if targetEnvironment(simulator)
// Local-only workaround: simulator keychain rejects writes without
// a keychain-access-groups entitlement, so fall back to a dev API key.
return "b127840fe9c84798b8edc7f846bfac2c"
#else
assertionFailure("access token missing in keychain")
return ""
#endif
```

The comment correctly identifies the *symptom* (simulator keychain rejects writes when there is no entitlements file), but the "fix" is a workaround that introduces several serious problems and does not actually repair the login flow.

## 2. Why this workaround is not acceptable

1. **Leaked credential in source.** `b127840fe9c84798b8edc7f846bfac2c` is a real Jellyfin API key tied to whoever generated it. Once it lands in git history, treat it as compromised. It should be rotated/deleted on that server.
2. **Compile flag is too broad.** `#if targetEnvironment(simulator)` fires on the **iOS simulator** as well as the tvOS simulator, even though the problem only exists on the tvOS target (see §3). Anyone running the iOS simulator without a saved user will silently authenticate as some unknown remote account.
3. **It does not fix login.** It only patches the *read* path of `accessToken`. The keychain `set` still silently fails on simulator, so a fresh `signIn` round-trip still won't persist between launches; users will see the login screen again next launch and get pushed back onto the hardcoded key.
4. **It is gated by user id.** The accessor is `Container.shared.keychainService().get("\(id)-accessToken")`. The fallback ignores `id` entirely and returns the same key for every user object — anything stamped through `UserState` ends up acting as a single ghost account.
5. **It hides a real configuration bug** (the missing tvOS entitlements file) instead of fixing it. The next developer will paper over a different symptom because the underlying environment is still broken.

## 3. Real root cause

### 3.1 The tvOS target has no entitlements file

`Swiftfin.xcodeproj/project.pbxproj` shows two targets:

| Target | `CODE_SIGN_ENTITLEMENTS` | `DEVELOPMENT_TEAM` |
| --- | --- | --- |
| Swiftfin (iOS)      | `Swiftfin/Resources/Swiftfin.entitlements` | `""` (empty) |
| Swiftfin tvOS       | *(not set)*                                  | `""` (empty) |

The iOS target at least references `Swiftfin.entitlements`, which contains:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
```

Having any entitlement at all forces Xcode to inject an `application-identifier` entitlement into the simulator build, which is what the keychain APIs require. The tvOS target has **zero** entitlements declared, so the built simulator app gets *no* `application-identifier` and *no* `keychain-access-groups` — and every `SecItemAdd`/`SecItemCopyMatching` returns `errSecMissingEntitlement` (-34018).

### 3.2 `KeychainSwift` (the wrapper this project uses) swallows the error

`Shared/Services/Keychain.swift`:

```swift
var keychainService: Factory<KeychainSwift> {
    self { KeychainSwift() }.singleton
}
// TODO: take a look at all security options
```

`KeychainSwift.set(...)` returns a `Bool` indicating success, but the project ignores the return value in `UserState.accessToken.set`. So on tvOS simulator the write fails *silently*, then the subsequent `get` returns `nil`, which previously triggered the `assertionFailure("access token missing in keychain")` — i.e. the *original* assertion was already pointing at the real failure.

### 3.3 Why this is documented Apple behaviour

This is a well-known simulator-only failure mode. Summary of the public guidance from Apple's developer forums and the wider community (links in §6):

- The simulator does not run real code-signing, it *simulates* entitlements. With no `.entitlements` file *and* an empty `DEVELOPMENT_TEAM`, Xcode does not inject the `application-identifier` entitlement.
- The Security framework requires `application-identifier` (or a matching `keychain-access-groups`) to satisfy the default access group lookup. Without it, every keychain call fails with `-34018 errSecMissingEntitlement`.
- The same code works fine on a real Apple TV device because device builds always carry an `application-identifier` derived from the provisioning profile.
- Apple's recommended fix: ensure the target has an entitlements file with **at least one** entry. Any entry (Keychain Sharing, App Sandbox, App Groups, even an empty `keychain-access-groups` array) is enough to force `application-identifier` into the simulator build.

## 4. Recommended fix (do **not** apply now — the user asked for a report only)

In order of preference:

### Option A — minimal: give the tvOS target its own entitlements file

1. Create `Swiftfin tvOS/Resources/Swiftfin tvOS.entitlements` with one of:
   ```xml
   <key>keychain-access-groups</key>
   <array>
     <string>$(AppIdentifierPrefix)org.jellyfin.swiftfin</string>
   </array>
   ```
   (or simply `com.apple.security.app-sandbox`/`com.apple.security.network.client` like the iOS target).
2. In Xcode → *Swiftfin tvOS* target → *Build Settings* → set `CODE_SIGN_ENTITLEMENTS = "Swiftfin tvOS/Resources/Swiftfin tvOS.entitlements"` for both Debug and Release.
3. Revert the `SwiftinStore+UserState.swift` hack to the original `assertionFailure` form. Delete the hardcoded key from history (or rotate it server-side).

### Option B — share an entitlements file between iOS and tvOS

The existing `Swiftfin.entitlements` can be reused by both targets. Same change in `CODE_SIGN_ENTITLEMENTS`, but pointed at the existing file. Slightly less hygienic because the tvOS app then inherits `app-sandbox`, which is a no-op on tvOS but is at least harmless.

### Option C — debug-only persistent fallback (only if A/B are blocked)

If for some reason the team cannot add an entitlements file in CI right now, the *right* way to keep iterating on tvOS in the simulator is to swap the persistence layer, not to fake a token:

```swift
#if DEBUG && targetEnvironment(simulator)
    // Fall back to UserDefaults purely for dev iteration.
    // Never read or write a real shared secret.
#endif
```

…but this should still be gated to `DEBUG`, scoped to per-user keys, and explicitly never read any third-party API key. Option A is strictly preferred.

### Verification once a fix is in

After applying Option A or B, in a terminal:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.apple.security"' --level debug
# Then launch the tvOS simulator build and sign in.
```

Or, on the built `.app`:

```bash
codesign -d --entitlements :- "<DerivedData path>/Swiftfin tvOS.app"
```

You should see `application-identifier` and/or `keychain-access-groups` in the output. If both are missing, the fix did not take.

## 5. Other findings worth flagging

- The diff is enormous (~13.5k lines, ~800 files). Most of the changes are cosmetic copyright bumps from `2025 → 2026` and comment style (`// → ///`). These should ideally be split out of the filters PR — they make review of the actual login change much harder, which is partially how a hardcoded key slipped in.
- `Shared/Services/Keychain.swift` still carries a `// TODO: take a look at all security options` from before this branch. Whoever fixes the entitlements should also pin down `accessGroup`, `accessibility` (likely `.afterFirstUnlockThisDeviceOnly`) and use the `synchronizable: false` form explicitly.
- Pre-existing GitHub issues that look related and may be the same root cause:
  - jellyfin/Swiftfin#163 — `[tvOS] Login does not persist`
  - jellyfin/Swiftfin#776 — `Logged Out Between Sessions [TVOS]`
  - jellyfin/Swiftfin#809 — `tvOS - Signing out of server constantly`
  - jellyfin/Swiftfin#930 — `tvOS: Can no longer sign in`
  These reports describe exactly what a missing simulator entitlement *plus* a missing device-side keychain accessibility setting would look like. Fixing the entitlements file may close several of them.

## 6. Sources

- [Troubleshooting -34018 Keychain Errors — Apple Developer Forums](https://developer.apple.com/forums/thread/114456)
- [OSStatus error: -34018 — Apple Developer Forums](https://developer.apple.com/forums/thread/761542)
- [Keychain error -34018 is Back — Apple Developer Forums](https://forums.developer.apple.com/thread/51071)
- [iOS 10 simulators keychain error -34018 — Apple Developer Forums](https://developer.apple.com/forums/thread/60617)
- [errSecMissingEntitlement — Apple Developer Documentation](https://developer.apple.com/documentation/security/errsecmissingentitlement)
- [Simulator: enabling Security framework (fix for error -34018) — dkimitsa](https://dkimitsa.github.io/2020/01/05/simulator-enabling-security-framework-err-34018-fix/)
- [KeychainAccess — Error -34018 required entitlement (issue #52)](https://github.com/kishikawakatsumi/KeychainAccess/issues/52)
- [Swiftfin issue #163 — [tvOS] Login does not persist](https://github.com/jellyfin/Swiftfin/issues/163)
- [Swiftfin issue #776 — Logged Out Between Sessions [TVOS]](https://github.com/jellyfin/Swiftfin/issues/776)
- [Swiftfin issue #809 — tvOS - Signing out of server constantly](https://github.com/jellyfin/Swiftfin/issues/809)
- [Swiftfin issue #930 — tvOS: Can no longer sign in](https://github.com/jellyfin/Swiftfin/issues/930)

## 7. TL;DR

The hardcoded API key in `SwiftinStore+UserState.swift` masks a configuration bug: the **Swiftfin tvOS** target has no `CODE_SIGN_ENTITLEMENTS` file. On the tvOS simulator that leaves the built app without an `application-identifier` entitlement, so every keychain read/write fails with `-34018` and the saved access token is lost. The right fix is to add a tvOS entitlements file (Option A above) and revert the workaround. The committed key should also be rotated/revoked on the corresponding Jellyfin server since it is now in repo history.
