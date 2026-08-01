# tvOS Filter Persistence — Research Notes

**Date:** 2026-05-28
**Branch:** `local/appletv-dev`
**Status:** Research only. No code change yet. Need to validate the actual failure mode on real device before picking a fix.

---

## Observed symptom

On a real Apple TV device, library filter selections in Swiftfin tvOS are **not maintained across reboot / force-quit**. The user expected the recently-added "always persist filters" behavior (commit `1a2ac2a3` — "P5 polish — multi-pill filters, persistence, …") to survive a reboot, and it does not.

---

## Current implementation map (tvOS)

| Concern | File | Lines | Notes |
|---|---|---|---|
| Filter write (onChange) | `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` | 360–378 | Always persists, no gate. Writes sortBy/sortOrder/genres/letter/tags/traits/years into `StoredValues[.User.libraryFilters(parentID: id)]`. |
| Filter read (init) | `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift` | 184–201 | Always restores from same key. |
| Key definition | `Shared/SwiftfinStore/StoredValue/StoredValues+User.swift` | 142–148 | `field: "setting-libraryFilters"`, `ownerID: currentUser.id`. Resolved name `setting-libraryFilters-{parentID}`. |
| Storage backend selector | `Shared/SwiftfinStore/StoredValue/StoredValue.swift` | 106–111 | **tvOS forced to `.defaults`** (UserDefaults). iOS uses CoreStore `.sql`. |
| Suite construction | `Shared/SwiftfinStore/StoredValue/StoredValue.swift` | 87–91 | `UserDefaults(suiteName: ownerID)!` — suite name is the **current user's UUID**. |
| Settings toggles | `Shared/Views/SettingsView/CustomizeSettingsView.swift` | 49–52, 265–267 | `Customization.Library.rememberFiltering` and `Customization.Library.rememberSort`. **Toggles are effectively no-ops on tvOS** — only the iOS write/read path honors them (see `Swiftfin/Views/PagingLibraryView/PagingLibraryView.swift:393–416`). |
| Defaults declarations | `Shared/Services/SwiftfinDefaults.swift` | 224, 228 | `rememberSort` and `rememberFiltering` keys, default `true`. |
| Entitlements | `Swiftfin tvOS/Swiftfin tvOSRelease.entitlements` | — | Keychain-access-group only: `org.jellyfin.swiftfin.local.cnaimi`. **No `com.apple.security.application-groups`.** |

So today on tvOS, filter persistence path is:
`PagingLibraryView.onChange` → `StoredValues[…]` → `.defaults` → `Defaults.Key(name, suite: UserDefaults(suiteName: <userUUID>))` → writes to `…/Library/Preferences/<userUUID>.plist` inside the tvOS app's data container.

---

## What Apple says about persistence on tvOS

**tvOS provides no guaranteed local persistence for any storage type.** This is documented (Apple/Microsoft archived docs + multiple secondary sources):

> "Unlike iOS devices, the new Apple TV provides extremely limited persistent, local storage for tvOS apps or data. For very small items (such as user preferences), your tvOS app still has access to NSUserDefaults with a limit of 500 KB of data."
>
> "If your tvOS app needs to persist larger amounts of information, it must store and retrieve that data from iCloud."
>
> "your app has no guarantee that any information it previously downloaded will be available the next time it is run."

Officially blessed persistent stores on tvOS:
- **iCloud Key-Value Storage (`NSUbiquitousKeyValueStore`)** — ≤ 1 MB total, ≤ 1 MB per value, ≤ 1024 keys. Auto-syncs across user's devices. Ideal for UI preferences like filter state.
- **CloudKit** — for larger data.

Everything else — `UserDefaults.standard`, `UserDefaults(suiteName:)`, CoreData/SQLite in the app container — sits in storage that tvOS can evict under disk pressure or across system updates.

Important secondary findings:
- `UserDefaults.standard` on tvOS is observed to be **the most reliable local option in practice**, despite no formal guarantee.
- `UserDefaults(suiteName:)` has additional reported quirks on tvOS 17+ (Apple Developer Forums thread 718449 — group/suite defaults sometimes not clearing on uninstall, inconsistent flush behavior).
- CoreStore *supports* tvOS, but the underlying SQLite file lives in the same evictable container. CoreData/SQLite is **not** a more reliable local option than `UserDefaults` on tvOS; Apple specifically recommends CloudKit instead.

---

## Implications for the two "quick fix" options I originally proposed

| Option | What it changes | Real-world reliability on tvOS | Verdict |
|---|---|---|---|
| **A**: Use `UserDefaults.standard` with a composite key like `setting-libraryFilters.<ownerID>.<parentID>` | Stops using `UserDefaults(suiteName:)`; uses the std suite. | More reliable than custom-suite plists in practice, but **still not guaranteed**. tvOS can evict `.standard` too. | Plausible mitigation, not a guarantee. |
| **B**: Remove the `#if os(tvOS)` override in `StoredValue.swift:106–111` so tvOS uses CoreStore SQL like iOS | Closes the iOS/tvOS divergence; data goes to SQLite in the data container. | **Same eviction risk as A.** SQLite in the app container is not protected on tvOS. Also: need to verify CoreStore actually runs/migrates on this tvOS build, which it currently doesn't exercise. | Doesn't buy persistence guarantees over A. |
| **C** (new): `NSUbiquitousKeyValueStore` (iCloud KVS) | Stores filter blob in iCloud KVS. | **Guaranteed-persistent per Apple guidance.** Requires iCloud entitlement, user signed into iCloud on the Apple TV. | The actually-correct answer if the requirement is "survives reboot, guaranteed." |

---

## But — symptom does not match Apple's "may be evicted" wording

Apple's warning is about *occasional, unpredictable* loss under storage pressure or system updates. The user is reporting **deterministic** loss on every reboot. That signature is more consistent with a code bug than tvOS eviction. Candidates:

1. **`ownerID` changes across reboot.**
   The suite is `UserDefaults(suiteName: ownerID)` where `ownerID = currentUser.id`. If the active-user selection or user record id is not stable across reboot — e.g. user has to re-pick the profile and a different id is used, or `ownerID` is empty during early-launch reads (in which case `StoredValue.subscript` short-circuits to default at lines 127 and 143) — no read will ever find the prior write. **This is the first thing to check.**
2. **Writes not flushing before termination.**
   UserDefaults batches to disk asynchronously. Force-quit immediately after changing a filter can drop the last write. A clean reboot shouldn't lose flushed data, but timing matters.
3. **Custom-suite plist actually unreliable on tvOS 17+.**
   Some forum reports (Apple Developer Forums thread 718449) describe inconsistent suite-defaults behavior. Possible, but second priority — measure first.

---

## Recommended validation plan (before any code change)

Add lightweight logging — do **not** refactor storage yet.

1. In `PagingLibraryViewModel.swift:184–201` (read), log on init:
   - `ownerID` value (or whatever `currentUser.id` resolves to at that moment)
   - `parentID`
   - the just-read `storedFilters` blob (or "default — nothing stored")
2. In `PagingLibraryView.swift:360–378` (write), log on each filter change:
   - `ownerID`, `parentID`
   - the new filter blob being written
3. Real-device test sequence:
   - **Test 1 — set, force-quit, relaunch.**
     Set a filter. Force-quit the app (long-press Play/Pause → close). Relaunch. Expect: read sees the same `ownerID` + same blob. If it doesn't → bug is in write flush *or* in `ownerID`/user-restore.
   - **Test 2 — set, reboot Apple TV, relaunch.**
     Set a filter. Full Apple TV reboot. Relaunch. Expect: same as Test 1.
   - **Test 3 — set, leave app, watch a movie or two, come back hours later.**
     Tests whether occasional tvOS eviction is part of the picture.

Branch decision off the results:
- If Test 1 already fails → not an eviction issue. Fix the user-restore / `ownerID` flow, or move to `UserDefaults.standard` with a composite key (Option A) if it turns out the custom-suite plist itself is the unreliable bit.
- If Test 1 passes and Test 2 fails consistently → look at whether reboots specifically clear the custom-suite plist. Try `UserDefaults.standard` (Option A) and re-test.
- If Tests 1 and 2 pass but Test 3 fails occasionally → that's the documented tvOS eviction. Only **Option C (iCloud KVS)** truly fixes it. May still be acceptable to live with for filter prefs.

---

## Settings toggles — separate cleanup needed

`Customization.Library.rememberFiltering` and `Customization.Library.rememberSort` are exposed in tvOS Settings but **do nothing on tvOS** (the gates were removed from both write and read paths — see comments in `PagingLibraryView.swift:362–368` and `PagingLibraryViewModel.swift:188–193`). Two options once persistence is sorted:

- Wire the toggles back into the tvOS paths so users can actually opt out of remembering filters.
- Hide the toggles in tvOS Settings to stop misleading users.

Decide after the persistence root cause is identified — the right behavior depends on whether persistence is reliable enough that "always on" is the right default.

---

## Sources

- [tvOS Resources and Data Storage — Microsoft Learn / archived Apple guidance](https://learn.microsoft.com/en-us/xamarin/ios/tvos/app-fundamentals/resources-data-storage)
- [Storing your data on tvOS, part 1 — Marisi Brothers](https://www.marisibrothers.com/2015/10/storing-your-data-on-tvos.html)
- [Apple Developer Forums — UserDefaults not cleared after Uninstall (tvOS 17 quirks)](https://developer.apple.com/forums/thread/718449)
- [Beware UserDefaults: a tale of hard to find bugs, and lost data — Christian Selig](https://christianselig.com/2024/10/beware-userdefaults/)
- [CoreStore — supported platforms (iOS / macOS / watchOS / tvOS)](https://github.com/JohnEstropia/CoreStore)
- [Apple Developer Forums — tvOS Core Data discussion](https://forums.developer.apple.com/thread/18116)
- [Apple TV hardware storage limits — AppleInsider](https://appleinsider.com/articles/24/05/20/apple-tv-hardware-storage-limits-will-keep-most-emulators-away)
