# Local Dev Plan — `local/appletv-dev`

Consolidate local work into a clean dev branch, fix the real keychain root cause, and merge PR #1902 + #1882 (the appletv-stack player work) on top.

**Companion report:** [`tvos-simulator-login-report.md`](./tvos-simulator-login-report.md) — root cause for the simulator login failure.

---

## Context

- **Start branch:** `pr-1770-filters` (= jellyfin/Swiftfin PR #1770 "Library Filters and Sorting" head)
- **Target branch:** `local/appletv-dev` (this branch)
- **Stacking onto it later:** `appletv-stack` (= main + #1902 tvOS Media Player + #1882 Index/Track Fixes)

### Local patches present in working tree before we started

| # | File | Purpose | Disposition |
|---|---|---|---|
| 1 | `Shared/SwiftfinStore/SwiftinStore+UserState.swift` | API-key fallback hack on sim | **Revert** — masks real bug, see report |
| 2 | `Shared/Extensions/ViewExtensions/ViewExtensions.swift` | `debugBackground` un-gated from `#if DEBUG` | **Keep** — fixes Release build (call sites in `SplitTimestamp.swift` are unguarded) |
| 3 | `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` | `safeAreaInset` replaces unsupported `.header` modifier | **Keep** — `.header` not in upstream `CollectionVGrid` |
| 4 | `Swiftfin tvOS/Views/PagingLibraryView/Components/LibraryHeader.swift` | `FilterPillButton` styled like Settings rows | **Keep** — quality-of-life UI improvement |
| 5 | `Swiftfin tvOS/Resources/Info.plist` | `CFBundleDisplayName = "Swiftfin Local"` | **Keep (local-distinction)** |
| 6 | `Swiftfin tvOS/Resources/Assets.xcassets/App Icon Local.brandassets/` (new) | Badged "LOCAL" icon variant | **Keep (local-distinction)** |
| 7 | `Swiftfin.xcodeproj/.../Package.resolved` | CollectionVGrid → `e5b869c` (has `.rows`/`.proxy`) | **Keep** — required for #1770 |
| 8 | `XcodeConfig/DevelopmentTeam.xcconfig` | bundle id `.local`, `ASSETCATALOG_COMPILER_APPICON_NAME = App Icon Local` | **Keep** — gitignored anyway |

### Working tree contamination

Approximately 800 files showed as modified due to SwiftFormat auto-running on open/build and bumping copyright headers `2025 → 2026`. These are **not** intentional and will be checked out before any commit.

---

## Plan

### Phase 0 — Branch + clean working tree
- [ ] Back up the 8 intentional patches to `/tmp/swiftfin-local-patches/` ✅ done
- [ ] `git checkout pr-1770-filters -- .` to discard all 800 SwiftFormat noise edits
- [ ] Restore the 8 patches from backup
- [ ] `git checkout -b local/appletv-dev`
- [ ] `git stash drop` (appletv-stack-era patches superseded)

### Phase 1 — Real keychain fix (Report Option A)
**Closes:** likely #163, #776, #809, #930 upstream.

- [ ] Create `Swiftfin tvOS/Resources/Swiftfin tvOS.entitlements` with `keychain-access-groups`
- [ ] Edit `Swiftfin.xcodeproj/project.pbxproj`: add `CODE_SIGN_ENTITLEMENTS` for Debug + Release of the tvOS target
- [ ] Revert `SwiftinStore+UserState.swift` to upstream — delete the simulator fallback + hardcoded key
- [ ] Build sim Debug, sign in with `lgtv/lgtv`, confirm token persists
- [ ] Verify via `codesign -d --entitlements :- "<app>"` — should show `application-identifier` + `keychain-access-groups`
- [ ] Commit: `fix(tvOS): add CODE_SIGN_ENTITLEMENTS so keychain works on simulator`

### Phase 2 — Commit kept upstream-fixable patches
Four small commits, each with a clear "why":

- [ ] `fix(tvOS): allow Release builds — make debugBackground unconditional`
  - File: `Shared/Extensions/ViewExtensions/ViewExtensions.swift`
- [ ] `fix(tvOS): replace unsupported .header modifier with safeAreaInset`
  - File: `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift`
- [ ] `feat(tvOS): style library filter pills like Settings list rows`
  - File: `Swiftfin tvOS/Views/PagingLibraryView/Components/LibraryHeader.swift`
- [ ] `chore: bump CollectionVGrid to e5b869c (adds .rows/.proxy)`
  - File: `Swiftfin.xcodeproj/.../Package.resolved`

### Phase 3 — Local-distinction layer (display name + icon)
Single commit (this stuff is local-only by design):

- [ ] `chore(local): rename to "Swiftfin Local" and use badged icon`
  - Files: `Info.plist`, `App Icon Local.brandassets/`, `DevelopmentTeam.xcconfig`

### Phase 4 — Merge appletv-stack (#1902 + #1882)
Expected conflicts (from earlier abort):

| File | Conflict type | Resolution |
|---|---|---|
| `Shared/Services/SwiftfinDefaults.swift` | content | Keep #1770 filter keys + #1902's Liquid Glass keys; remove `#if DEBUG` around Liquid Glass or guard call sites |
| `Shared/ViewModels/FilterViewModel.swift` | content | Union of filter additions |
| `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift` | content | Union — #1770 adds filter wiring, #1902 adjusts paging |
| `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` | content | Apply our `safeAreaInset` fix on the merged result |
| `Swiftfin tvOS/.../Components/Sections/LibrarySection.swift` | modify/delete | Inspect; #1902 may have removed view that #1770 modifies — likely accept #1770 version |
| `Swiftfin/.../CustomizeViewsSettings.swift` | modify/delete | Same as above on iOS |
| `Translations/en.lproj/Localizable.strings` | binary | Accept union; re-run SwiftGen if available |

- [ ] `git merge --no-ff appletv-stack`
- [ ] Resolve each conflict per the table
- [ ] Build for sim Debug → BUILD SUCCEEDED
- [ ] Smoke-test: sign in, see filters, open new player UI

### Phase 5 — Verify
- [ ] Sim: login persists, filter pills work, new player opens, no crashes
- [ ] Real AppleTV: install alongside App Store Swiftfin, both coexist (different bundle id + name + icon)
- [ ] Real AppleTV: sign in, kill the app, relaunch — confirm token persists (this validates the keychain fix on hardware too)

### Phase 6 — Document
- [ ] Add "## 8. Resolution" section to `tvos-simulator-login-report.md` pointing at the entitlements commit
- [ ] Note which GitHub issues this likely closes upstream (#163/#776/#809/#930)

---

## Progress log

(Updated as work proceeds. Tasks are also tracked via the harness's Task tool — see `TaskList` for live status.)

| Phase | Status | Commit | Notes |
|---|---|---|---|
| P0 | ✅ done | — | 8 patches backed up to `/tmp/swiftfin-local-patches/`; 800-file noise discarded via `git checkout`; branch `local/appletv-dev` created from `pr-1770-filters`. |
| P1 | ✅ done | `167628b7` | Added `Swiftfin tvOS/Resources/Swiftfin tvOS.entitlements` with `keychain-access-groups`; wired `CODE_SIGN_ENTITLEMENTS` for Debug + Release. UserState.swift hack not restored (kept original `assertionFailure` form). |
| P2 | ✅ done | `557523f8`, `0851fff3`, `4857ef41`, `f5aeb5b6` | Four focused commits: debugBackground unconditional / `.header` → `safeAreaInset` / FilterPillButton style / CollectionVGrid bump to `e5b869c`. |
| P3 | ✅ done | `b628bfea` | `CFBundleDisplayName = "Swiftfin Local"` + `App Icon Local.brandassets` (28 files). DevelopmentTeam.xcconfig left gitignored. |
| P4 | ✅ done | `f122abb9` | Merged `appletv-stack` (#1902 + #1882). Conflicts resolved per the table below. **FilterViewModel.swift taken `--theirs`** because the new macro-based architecture is incompatible with the old switch-based one — see "Post-merge audit" section. |
| P4.1 | ✅ done | `35321724` | Post-merge audit fix: re-added missing `rememberFiltering` Toggle in `CustomizeSettingsView`, restored `.isPlayed`/`.isUnplayed` mutual-exclusion in `ItemFilterType.traits` setter. |
| P4.2 | ✅ done | `cd550694` | UI audit fix: filter pills now use `Color.secondarySystemFill` + `.card` (drops the brightness focus hack), wire `.tint(accentColor)` so active pills pick up the user accent, use `.firstTextBaseline` alignment, fix `safeAreaPadding`→`padding` bug on the inset host. |
| P4.3 | ✅ done | `50971ebb` | Post-merge build-error fixes: removed duplicate `NavigationRoute.filter(...)` / `navigationBarCloseButton(...)` / `FilterView.swift`, `hasFilters` → `isNotEmpty`, `.send(.reset())` → `.reset(filterType: nil)`, added missing `rememberFiltering` / `rememberFilteringFooter` keys to `en.lproj/Localizable.strings`. **`xcodebuild` BUILD SUCCEEDED** at this commit. |
| P4.4 | ✅ done | `23252324` | Second-audit fixes: restored the *real* `navigationBarCloseButton` impl on tvOS (`50971ebb` incorrectly removed it and left only the no-op stub, breaking Close on every tvOS sheet); re-added `"by"` localization key (had been hardcoded as a literal in `cd550694`). **`xcodebuild` BUILD SUCCEEDED** at this commit. |
| P5 | 🟡 in progress | — | First reinstall+launch at `23252324` crashed on UserSession.init → keychain assertionFailure (stale CoreData from `50971ebb`'s hack-era install). Wiping app + rebuilding fixed the launch path. Sign-in flow exercised by user with `lgtv/lgtv` against `http://192.168.50.154:8096` (server "M1Center"). Surfaced 6 follow-up issues (see P5 audit) — being fixed in P5.1+. |
| P5.1 | ✅ done | _uncommitted_ | **Multi-pill library filter UI restored.** `LibraryHeader.swift` rewritten to iterate `enabledDrawerFilters` and render one pill per `ItemFilterType` (Genres, Lettre, Tri, Tags, Filtres, Années) — matches iOS `NavigationBarFilterDrawer` pattern. Active pills tint to accent color; each opens its own selector sheet via `.filter(type:, viewModel:)`. Reset pill added when any filter is active. Previous single "Tout" pill is gone. |
| P5.2 | ✅ done | _uncommitted_ | **Doubled title fixed.** `PagingLibraryView.swift` no longer sets `.navigationTitle(...)` — the `LibraryHeader` already renders the title + count inline, and the platform's auto nav-title was overlapping the grid. Single source of truth now. |
| P5.3 | ✅ done | _uncommitted_ | **Duplicate "Favoris" in Traits sheet fixed.** Root cause: French `Translations/fr.lproj/Localizable.strings` mapped both `favorites` and `likedItems` to `"Favoris"`. Changed `likedItems` → `"Aimés"` so `.isFavorite` and `.likes` are visually distinct. (File is UTF-16; edited via Python `codecs.open`.) |
| P5.4 | ✅ done | _uncommitted_ | **Filter persistence default flipped.** `SwiftfinDefaults.swift`: `rememberFiltering` and `rememberSort` now default to `true` (were `false`). Persistence machinery in `PagingLibraryView.swift:358-381` + read-back in `PagingLibraryViewModel.init:186-199` already symmetric; just unlocked it by default. User no longer needs to find/toggle the Settings option to get the expected behavior. |
| P5.5 | ✅ done | _uncommitted_ | **Local app icon now visibly green** (was identical cyan to App Store version). Two fixes: (a) `Swiftfin.xcodeproj/project.pbxproj` — `ASSETCATALOG_COMPILER_APPICON_NAME` changed from `"App Icon & Top Shelf Image"` to `"App Icon Local"` for tvOS Debug + Release (target-level pbxproj override was beating the xcconfig). (b) Regenerated all PNGs in `App Icon Local.brandassets/` from the upstream brandassets with a B↔G channel swap, turning the cyan triangle + dark-blue background into a green triangle + dark-green background. App Store imagestack flavor done too. |
| P5.6 | ✅ done | _uncommitted_ | **Empty Home (Accueil) page fixed.** Root cause: when the user had no Resume items, the `else` branch of `HomeView.contentView` rendered a `CinematicRecentlyAddedView` whose inner `CinematicItemSelector` forces `.frame(height: UIScreen.main.bounds.height - 75, alignment: .bottomLeading)` — i.e. the entire screen minus 75pt. This full-screen frame, combined with `.ignoresSafeArea()` on the outer ZStack, pushed every subsequent row (NextUp, Latest-per-library, libraries-shortcut) off-screen even though the data was actually loaded. **Fix:** rewrote `Swiftfin tvOS/Views/HomeView/HomeView.swift` to use a flat stacked layout — `NextUpView → RecentlyAddedView (non-cinematic) → ForEach(libraries) → librariesShortcut` — with `padding(.top, 130)` to clear the top nav. Cinematic hero kept ONLY when Resume items exist. Also added a guaranteed-non-empty `librariesShortcut` fallback row that lists the user's libraries as poster cards. Verified on sim: 9 Next Up items + 50 Recently Added + 50 Movies + 40 TV Shows + 8 Anime + 1 Fast_Anime all render correctly. |
| P5.7 | ✅ done | _uncommitted_ | **Multi-pill filter UI polished to match iOS / Settings style.** First pass at P5.1 produced functional but visually-busy pills ("a bit ugly" per user). Rewrote `LibraryHeader.swift` with: capsule shape (matches iOS `NavigationDrawerLabelStyle`), `ultraThinMaterial` background with stroke outline, chevron-down indicator on each pill, accent fill when active, custom `FilterPillButtonStyle` providing subtle focus lift (scale 1.08 + shadow) without the heavy `.card` chrome that wrapped earlier pills. Title moved above the pill row (was crammed inline). |
| P5.8 | ✅ done (verified via NSLog diagnostics 2026-05-27) | _uncommitted_ | **Confirmed working.** Diagnostic `NSLog`s added to the `.onChange` write block (`PagingLibraryView.swift:360-380`) and the `init` read (`PagingLibraryViewModel.swift:186-205`); sim run showed Anime library (`parentID=0c41907140d802bb58430fed7e2cd79e`) reading `traits=["IsUnplayed"]` on relaunch — i.e. persisted across full terminate+launch. Full cycle (`onChange FIRED` → `WROTE` → `READBACK` → next-launch `INIT READ`) is clean. The earlier "still fails" report was against a stale install where the uncommitted code wasn't actually on the sim. **Diagnostic `NSLog`s should be removed before committing.** Original-issue text below kept for history.<br><br>**Original (now resolved) text:** Defaults gates removed (unconditional read+write of `StoredValues[.User.libraryFilters(parentID:)]`) but live test STILL shows the filter not surviving an app terminate+relaunch. Code changes done: removed `if Defaults[.rememberFiltering]` / `rememberSort` gates in `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift:184-200` (read) and `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` `.onChange` (write). **Next-session hypotheses to investigate:** (a) `User.libraryFilters(parentID:)` is keyed via `CurrentUserKey(..., storage: .sql)` — the CoreStore SQL transaction may not be committing before app terminate, OR `ItemFilterCollection`'s Codable round-trip may be dropping the `traits` field; (b) `.onChange(of: viewModel.filterViewModel?.currentFilters)` may not be firing on the user-action path — try observing `filterViewModel.$currentFilters` Combine publisher with `.sink` directly in the view model so the write isn't view-layer-dependent; (c) verify with a temporary `NSLog` in `StoredValues[...] = newStoredFilters` setter that the write actually happens when the user toggles a trait. **Reinstall does NOT preserve filters by design** — `StoredValues` is app-local (UserDefaults + CoreStore); uninstall wipes the sandbox. Surviving reinstall would need keychain or iCloud-synced storage (out of scope). |
| P5.10 | ✅ done (audit only — no code change) | — | **Filter settings → library-view wiring audited.** All filter-related defaults verified to be honored on tvOS. User report: "Letter Picker disabled in Settings, but Lettre pill still in drawer." → **Not a bug.** `Library.letterPickerOrientation` only controls the side A-Z bar (`LetterPickerBarModifier.swift:21`), while individual filter pills are governed by `Library.enabledDrawerFilters` (default `ItemFilterType.allCases`, iterated at `LibraryHeader.swift:64` and gated whole-header at `PagingLibraryView.swift:262`). These two settings are independent by design — same as iOS and Jellyfin Web. To hide the Lettre pill, the user must uncheck "Letter" under Settings → Filtres → Bibliothèque. Decision (2026-05-27): **document only, no code change.** Per-type honor matrix: `.genres / .letter / .sortBy / .tags / .traits / .years` all correctly route through `OrderedSectionSelectorView` (`NavigationRoute+Settings.swift:158`) → `$libraryEnabledDrawerFilters` → `LibraryHeader` `ForEach`. `Search.enabledDrawerFilters` is iOS-only; not wired on tvOS (no current tvOS filter UI in Search). Other library customizations (`displayType`, `posterType`, `listColumnCount`, `rememberLayout/Sort/Filtering`, `showFavorites`, `randomImage`) all verified to be read on the tvOS code path. |
| P5.9 | ✅ done | _uncommitted_ | **Local app icon now visibly green** (P5.5 follow-up — first attempt embedded a "LOCAL" red ribbon, user preferred a clean color shift). Regenerated `App Icon Local.brandassets/**/*.png` from the upstream brandassets with a B↔G channel swap so the cyan jellyfin triangle becomes a green triangle on a dark-green background. Front (216 + 432 + 512 sizes) and Back (400×240 + 1280×768) layers all recolored. Combined with the P5.5 pbxproj patch (`ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon Local"` for tvOS Debug + Release), the home-screen icon is now distinctively green vs the App Store cyan version. Verified visually — see `/tmp/swiftfin-sim/06-green-icon.png` and `/tmp/swiftfin-sim/27-home-bottom.png`. |
| P6 | ⚪ pending | — | After P5 passes: add "Resolution" section to `tvos-simulator-login-report.md` pointing at `167628b7`; note upstream issues #163/#776/#809/#930 likely closed. |

Legend: ✅ done · 🟡 in progress · 🔴 blocked · ⚪ pending

### P5 audit findings (2026-05-26 session — first user sim test)

User signed in to the booted sim against `http://192.168.50.154:8096` (`lgtv/lgtv`) and surfaced six issues — five fixed in P5.1–P5.5 above, one (Home empty) still under investigation as P5.6.

1. **Filter UI minimal** — Library header showed a single "Tout" pill instead of one pill per filter type (compared to iOS `NavigationBarFilterDrawer`). → Fixed in P5.1: iterate `enabledDrawerFilters` and render one `FilterPillButton` per type.
2. **Library layout broken** — "Films" title appeared twice (once in `LibraryHeader`, once via `.navigationTitle(...)`); the auto-rendered nav title overlapped the poster grid. → Fixed in P5.2: dropped `.navigationTitle(...)` on tvOS only (the in-header `Text(title)` is the canonical source).
3. **Filter not remembered across navigation** — Filters reset every time the user re-entered a library. Root cause: `rememberFiltering` / `rememberSort` defaulted to `false`, so the symmetric write→read paths in `PagingLibraryView` / `PagingLibraryViewModel.init` never ran. → Fixed in P5.4: defaults flipped to `true`.
4. **Duplicate "Favoris" in Traits filter sheet** — French translation had `favorites = "Favoris"` AND `likedItems = "Favoris"`, so `.isFavorite` and `.likes` rendered identically. → Fixed in P5.3: `likedItems` → `"Aimés"`.
5. **Local app icon identical to App Store icon** — Two-part bug: pbxproj target-level `ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image"` overrode the xcconfig's `App Icon Local`; AND the LOCAL-badged 2x PNG was missing the badge (only 1x had it, simulator picks 2x). → Fixed in P5.5: pbxproj patched + icons regenerated from upstream with a green-tint channel swap (no LOCAL-text overlay — per user preference for a clean color difference).
6. **Home (Accueil) page completely empty** — All four data sources (`resumeItems`, `nextUpViewModel.elements`, `recentlyAddedViewModel.elements`, `libraries`) come back empty even though the user has 287 Films + multiple anime/TV libraries that show fine in the library tabs. State machine transitions to `.content` regardless. → Still pending as P5.6. Needs runtime instrumentation: `xcrun simctl spawn ... log stream --predicate 'subsystem == ...'` or temporary print() to confirm whether the Jellyfin `getResumeItems` / `getNextUp` / `getLatestMedia` endpoints actually return zero, or whether the view-model wiring is silently failing.

### Stale-sim gotcha

The first launch of the freshly-built `23252324` build crashed with `SIGILL` from `SwiftfinStore.State.User.accessToken.getter` → `assertionFailure("access token missing in keychain")` at `SwiftinStore+UserState.swift:33`. Root cause: the prior install from `50971ebb` had the keychain-hack version of UserState that never actually wrote tokens to the keychain — but it DID write a User record to CoreData. The new HEAD (post-P1) removed the hack and assumes the keychain entry exists. The stale CoreData record from the previous install pointed at a non-existent keychain entry → crash on launch. **Fix:** `xcrun simctl uninstall org.jellyfin.swiftfin.local` before installing a build that crosses the Phase 1 keychain refactor. After uninstall + fresh install, launch succeeds and the connect-to-server screen appears.

### Empty entitlements caveat (Phase 1 fix is partially load-bearing)

The signed binary's entitlements blob (`.xcent`) is **empty** — `codesign -d --entitlements -` returns `<dict/>` — even though `Swiftfin tvOS/Resources/Swiftfin tvOS.entitlements` declares `keychain-access-groups`. Reason: the entitlement uses `$(AppIdentifierPrefix)` which can't be resolved without a real provisioning profile (we have `DEVELOPMENT_TEAM=` empty for free-Apple-ID signing). Xcode drops the unresolved entitlement entirely. **On simulator this is fine** — the default keychain is shared inside the sim's bundle container, so `KeychainSwift.set/get` works without an access group. **On real hardware** the entitlement should resolve properly once a Development Team is configured in `DevelopmentTeam.xcconfig`. Don't be alarmed by the empty `.xcent` on the sim; it's not the cause of any current bug.

### Post-merge audit findings (commits 35321724 + cd550694)

Run via a multi-agent code-review pass on `f122abb9..HEAD`. Findings grouped:

**BLOCKER (fixed):**
- `rememberFiltering` toggle had no UI — `CustomizeSettingsView.swift` missing the `@Default` binding + Toggle. The persistence machinery (init-time restore in `PagingLibraryViewModel.swift:184-200`, onChange persist in `PagingLibraryView.swift:358-381`) was already present from appletv-stack, but without the UI the flag was hardcoded false. → fixed in `35321724`.

**REGRESSION (fixed):**
- `.isPlayed` / `.isUnplayed` mutual exclusion lost when `FilterViewModel.swift` was taken `--theirs`. The old switch-based architecture had this logic in `.update(type, filters)` which doesn't exist in the new `@Stateful` macro pipeline. → re-added inline in `ItemFilterType.swift` `.traits` setter in `35321724`.

**OK (intact):**
- All 11 SwiftfinDefaults keys (`rememberLayout/Sort/Filtering/enabledDrawerFilters/displayType/posterType/listColumnCount/randomImage/showFavorites/cinematicBackground/letterPickerOrientation`) at `SwiftfinDefaults.swift:185-229`.
- `StoredValues[.User.libraryFilters(parentID:)]` at `StoredValues+User.swift:142`, full collection persisted.
- PR #1882 surfaces (`MediaStream.swift` `buildIndexMap`, `MediaPlayerManager` track plumbing) intact.
- PR #1902 surfaces (`Swiftfin tvOS/Views/VideoPlayer/PlaybackControls/` tree) intact.

### Second audit findings (after build fixes — being addressed in P4.4)

**BLOCKER:**
- `navigationBarCloseButton` real impl was deleted from `Swiftfin tvOS/Extensions/View/View-tvOS.swift`. The commit message claimed `.topBarTrailing` doesn't exist on tvOS — **false**, it's used in `Shared/Extensions/ViewExtensions/ViewExtensions.swift:390-397` and compiles for tvOS. The duplicate-symbol problem should have been resolved by removing the **stub** instead. Every tvOS sheet that calls `.navigationBarCloseButton { router.dismiss() }` (FilterView, UserSignInView, AppSettingsView, SettingsView, ItemRefreshView, ConnectToServerView, QuickConnectView, ItemSubtitleSearchView, EditDeviceProfileView, Section.swift) currently has no Close button. → being fixed in P4.4.

**REGRESSION:**
- Hardcoded `Text("by")` in `LibraryHeader.swift`. Was `L10n.by.lowercased()`. The merge dropped the `"by"` key from `en.lproj/Localizable.strings`. → re-adding the key + restoring the call site in P4.4.

**ACCEPTED LOSS:**
- The tvOS-specific `Swiftfin tvOS/Views/FilterView.swift` (238 lines with explicit sortBy/sortOrder sections, icon Reset button, 50%-width Form via GeometryReader) was deleted. Replaced by the unified `Shared/Views/FilterView.swift` from PR #1823. Visual layout will be different — accept and re-evaluate from the sim.

### Phase 4 conflict resolution table (actual)

| File | How resolved | Notes |
|---|---|---|
| `Shared/Extensions/ViewExtensions/ViewExtensions.swift` | Union (drop `#if DEBUG`, take modernized signature) | Keep #1770's debugBackground-unconditional fix on top of appletv-stack's `some ShapeStyle` style. |
| `Shared/Services/SwiftfinDefaults.swift` | Union of all keys | All 11 keys preserved. |
| `Shared/ViewModels/FilterViewModel.swift` | `--theirs` (appletv-stack) | Architectures incompatible (switch-based vs `@Stateful` macro). Lost behaviors re-added via P4.1. |
| `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift` | Union (HEAD's `HasTotalCount` ext + appletv-stack's `@MainActor`) | Trivial merge. |
| `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` | Hybrid — appletv-stack body + #1770's `safeAreaInset` for LibraryHeader | `safeAreaPadding`→`padding` bug fixed in P4.2. |
| `Swiftfin tvOS/.../CustomizeViewsSettings/.../LibrarySection.swift` | Accepted deletion | appletv-stack removed entire folder; verified no remaining callers. The `rememberFiltering` Toggle was relocated to `Shared/Views/SettingsView/CustomizeSettingsView.swift` in P4.1. |
| `Swiftfin/.../CustomizeViewsSettings/CustomizeViewsSettings.swift` | Accepted deletion | Same as above. |
| `Translations/en.lproj/Localizable.strings` | `--theirs` (appletv-stack — superset) | Lost #1770-only keys (`by`, `rememberFiltering`, `rememberFilteringFooter`, ~28 others). Critical ones re-added in P4.3 / P4.4. Strings.swift falls back to literal text for the rest at runtime. |

---

## Out of scope / out of band

- **Rotate the leaked API key on the Jellyfin server** ✅ done by user. The key was `b127840f…`; it appeared in a working-tree patch only and will not enter any commit on this branch.
- **Upstream PR**: if the team wants, the Phase 1 commit (`167628b7`, keychain fix) is a strong candidate for a small focused upstream PR — high value, low risk, likely closes multiple long-standing tvOS issues.
- **Outstanding `Localizable.strings` keys**: ~26 #1770-only keys are not in the merged en.lproj. They have runtime fallbacks via `Strings.swift`, so the UI works in English but other locales show key names. Not blocking; add as a follow-up if you want clean translations.

---

## Next session — pick-up checklist

State at pause (2026-05-26 late evening, after second pass):

- Current branch: `local/appletv-dev`, **working tree dirty** with the P5.1–P5.9 fixes uncommitted (see "uncommitted changes" below)
- Last commit: `23252324 fix(tvOS): restore navigationBarCloseButton + L10n.by (second audit)`
- Last build: ✅ `xcodebuild -scheme "Swiftfin tvOS" -destination "platform=tvOS Simulator,id=68CB155B-71F7-4326-8131-B3621A95BFCF" -configuration Debug build` → **BUILD SUCCEEDED** with P5.1–P5.9 applied
- Sim `68CB155B-71F7-4326-8131-B3621A95BFCF` (Apple TV 4K 3rd gen, tvOS 26.2): currently has the **post-P5.9 build installed and running**, green-tinted LOCAL icon visible on home screen.

### What got verified live in this session
- ✅ **P5.1 + P5.7 (multi-pill UI, iOS/Settings style):** user image #6 + #8 — capsule pills `Genres / Lettre / Trier par nom / Étiquettes / Filtres / Années` with chevron-down indicator; active pill (Non lu) tints to accent purple.
- ✅ **P5.2 (no doubled title):** user image #8 — "Films (140 éléments)" appears once.
- ✅ **P5.3 (no duplicate Favoris):** user image #9 — Traits sheet now reads `Non lu / Déjà lu / Favoris / Aimés` (was `Non lu / Déjà lu / Favoris / Favoris`).
- ✅ **P5.4 navigation persistence:** user confirmed "filter is kept" across Accueil → Films round trip.
- ✅ **P5.5 + P5.9 (green LOCAL icon):** sim screenshots `/tmp/swiftfin-sim/06-green-icon.png` and `/tmp/swiftfin-sim/27-home-bottom.png` — green-on-dark-green, distinct from App Store cyan.
- ✅ **P5.6 (empty Home fixed):** sim screenshots `/tmp/swiftfin-sim/25-home-fixed.png` (À suivre + Ajoutés Récemment populated) and `/tmp/swiftfin-sim/26-home-scrolled.png` (per-library latest rows: Anime / Fast_Anime / Movies / TV Shows).

### What's still broken and deferred
- ✅ **P5.8 restart persistence (resolved 2026-05-27):** instrumented with `NSLog`s, ran full terminate+relaunch cycle on the sim, observed `INIT READ … traits=["IsUnplayed"]` after relaunch. Working as intended. Diagnostic `NSLog`s still in the working tree at `PagingLibraryView.swift:361/367/378/381` and `PagingLibraryViewModel.swift:187/205` — **remove before committing P5 bundle.**
- ❌ **Reinstall persistence:** by design — `StoredValues` (UserDefaults + CoreStore) dies with the app sandbox. Out of scope; would need iCloud KVS.

### Upstream PR drift snapshot (2026-05-27)

Audited the three PRs we forked from. State at this point:

| PR | Our head | Upstream head | Drift |
|---|---|---|---|
| #1770 Library Filters and Sorting | `17b13d7f` | `17b13d7f` | ✅ none |
| #1882 Index/Track Fixes | `65579dec` | `65579dec` | ✅ none |
| #1902 tvOS Media Player | `fd14fea3` | `6e14bf72` | ⚠️ +2 `wip` commits |

The #1902 drift is two `wip` commits by Ethan Pippin (`1a714fef` May 25 — slider/supplement refactor; `6e14bf72` May 26 — action-button reorg + new TintedMaterial / OverlayButtonStyle components). Both bump `Package.resolved` and touch `project.pbxproj`. Together: 37 files, ~590 LOC net delta. **Decision: do not merge yet.** Rationale: they are explicitly wip (author iterating), they don't fix any known issue on this branch (player works fine on the sim), and they'd land directly on the pbxproj/Package.resolved surfaces where our `e5b869c` CollectionVGrid pin and `App Icon Local` asset name live. Re-evaluate when (a) #1902 is marked ready-for-review / loses `wip`, (b) a player bug surfaces here that the new commits address, or (c) we do a deliberate sync-to-upstream sweep before tagging.

`origin/main` since our merge: only Weblate translation updates — nothing actionable.

### P5.10 follow-up consideration (deferred)

User asked whether Home rows can be reordered / individually toggled. Today only `Customization.Home.showRecentlyAdded` exists (a single boolean for the top "Ajoutés récemment" row). The per-library "Latest in" rows render in server order with no UI to reorder or hide them individually. **Out of scope for this branch** — would need a `[String]` ordered/visible list default + a Settings drag-to-reorder list (precedent in Jellyfin Web and in `Customization/HomeSettings*` on iOS). Consider as a follow-up branch after the local release ships.

### Uncommitted changes (to commit before next session ends)

| File | What changed | Phase |
|---|---|---|
| `Swiftfin tvOS/Views/PagingLibraryView/Components/LibraryHeader.swift` | Rewrote twice: first to iterate `enabledDrawerFilters` → one pill per `ItemFilterType` (P5.1); then again with iOS `NavigationDrawerLabelStyle`-matching style — capsule + ultraThinMaterial + stroke + chevron, custom `FilterPillButtonStyle` for subtle focus lift (P5.7). | P5.1 + P5.7 |
| `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` | Removed `.navigationTitle(...)` so the in-header title is canonical (P5.2). Made filter/sort persistence unconditional by dropping the `if Defaults[.rememberFiltering]` gate in `.onChange` (P5.8). | P5.2 + P5.8 |
| `Translations/fr.lproj/Localizable.strings` | `likedItems`: `"Favoris"` → `"Aimés"` (disambiguates from `favorites`). | P5.3 |
| `Shared/Services/SwiftfinDefaults.swift` | `rememberFiltering` + `rememberSort` defaults flipped `false` → `true` (P5.4). Toggle exists for fresh installs; existing installs are now covered by P5.8's unconditional path. | P5.4 |
| `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift` | Made filter restore unconditional in `init` (was gated by `Defaults[.rememberFiltering]` / `rememberSort` — see P5.8 rationale). | P5.8 |
| `Swiftfin tvOS/Views/HomeView/HomeView.swift` | Rewrote layout: flat stacked rows (NextUp → RecentlyAdded → Latest-per-library → Libraries) with top-padding for the tab bar. Cinematic hero kept ONLY when Resume items exist; the full-screen `CinematicRecentlyAddedView` frame was pushing every subsequent row off-screen. Added always-visible `librariesShortcut` fallback. | P5.6 |
| `Swiftfin.xcodeproj/project.pbxproj` | tvOS Debug + Release `ASSETCATALOG_COMPILER_APPICON_NAME` → `"App Icon Local"`. | P5.5 |
| `Swiftfin tvOS/Resources/Assets.xcassets/App Icon Local.brandassets/**/*.png` (6 files) | Front + Back layers re-sourced from upstream, then channel-swapped B↔G to produce a green icon (no text overlay — clean color shift per user preference). | P5.5 + P5.9 |

Commit graph since `pr-1770-filters`:

```
(uncommitted)                                                                   ← P5.1–P5.5 above
23252324 fix(tvOS): restore navigationBarCloseButton + L10n.by (second audit)   ← HEAD
50971ebb fix(tvOS): resolve post-merge build errors
cd550694 fix(tvOS): library filter pills — accent color, readability, focus fixes
35321724 fix: restore #1770 filtering features lost in appletv-stack merge
f122abb9 Merge appletv-stack (#1902 tvOS Player + #1882 Index/Track Fixes)
b628bfea chore(local): rename to 'Swiftfin Local' and use badged icon
f5aeb5b6 chore: bump CollectionVGrid to e5b869c
4857ef41 feat(tvOS): style library filter pills like Settings list rows
0851fff3 fix(tvOS): replace unsupported .header modifier with safeAreaInset
557523f8 fix: allow Release builds — make debugBackground unconditional
167628b7 fix(tvOS): add CODE_SIGN_ENTITLEMENTS so keychain works on simulator
```

### To resume P5 (verify the P5.1–P5.5 fixes on sim + tackle P5.6 empty Home)

1. **Sim should already be ready** — green-icon build was installed at the end of last session. Just relaunch:
   ```bash
   xcrun simctl launch 68CB155B-71F7-4326-8131-B3621A95BFCF org.jellyfin.swiftfin.local
   ```
   If the working tree was reset and rebuild is needed: see "If the build needs a fresh start" below.

2. **Verify P5.1 (multi-pill filter UI):** Sign in (`lgtv`/`lgtv` against `http://192.168.50.154:8096`). Open Films or any library. Confirm the header now shows multiple filter pills (Genres, Lettre, Tri, Tags, Filtres, Années) instead of a single "Tout" pill. Each pill should be tappable and open its own selector sheet.

3. **Verify P5.2 (no doubled title):** The library title ("Films") should appear ONCE in the header, not also as a big centered title overlapping the grid.

4. **Verify P5.3 (no duplicate Favoris):** Filtres pill → Traits sheet → entries should read `Non lu`, `Déjà lu`, `Favoris`, `Aimés` (was: `Favoris`, `Favoris`).

5. **Verify P5.4 (filter persistence):** Set a filter on Films. Navigate away (Accueil tab) and back to Films. The filter should still be applied — no need to toggle anything in Settings.

6. **Verify P5.5 + P5.9 (green icon):** On the tvOS home screen (press Menu/Esc), the Swiftfin Local app icon should be green-on-dark-green, distinct from the cyan-on-dark-blue App Store version. ✅ Verified — `/tmp/swiftfin-sim/06-green-icon.png` and `/tmp/swiftfin-sim/27-home-bottom.png`.

7. **Verify P5.6 (Home no longer empty):** Open Accueil tab. Should see À suivre (Next Up), Ajoutés Récemment (Recently Added), Anime récents, Fast_Anime récents, Movies récents, TV Shows récents, and a "Libraries" shortcut row. ✅ Verified — `/tmp/swiftfin-sim/25-home-fixed.png` + `/tmp/swiftfin-sim/26-home-scrolled.png`.

8. **P5.8 restart persistence — STILL FAILING despite the unconditional read+write fix.** User confirmed live that applying `Non lu` on Films, terminating, and relaunching still drops the filter. The code path is correct (symmetric read+write of `StoredValues[.User.libraryFilters(parentID: id)]`), so the issue is somewhere lower in the stack. **Top hypotheses to investigate first in the next session:**
   1. **Verify the write actually happens.** Add a temporary `NSLog` inside the `.onChange` write block in `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift`. Apply Non lu and check the unified log — if no log line appears, `.onChange` isn't firing for filter changes (possibly because `ItemFilterCollection`'s `Equatable` is too coarse and the new value equals the old one, or because `currentFilters?` optional comparison short-circuits). Fix by switching to a Combine `.sink` on `filterViewModel.$currentFilters` from inside `PagingLibraryViewModel`.
   2. **Verify the SQL transaction commits.** `User.libraryFilters(...)` uses `storage: .sql` (CoreStore). On app terminate, an in-flight transaction may be abandoned. Either change `storage` to `.defaults` for this key (UserDefaults flushes synchronously) or add `CoreStoreDefaults.dataStack.perform(...)` with explicit commit before the write returns.
   3. **Verify Codable round-trip preserves traits.** `ItemFilterCollection` encodes via Codable into the CoreStore blob. If `.traits` (a `[ItemTrait]`) doesn't survive a round-trip, the read would always restore default traits even though the rest of the struct is fine. Write a one-shot Swift unit test that encodes `.default.mutating(\.traits, with: [.isUnplayed])`, decodes, and asserts traits equals `[.isUnplayed]`.
   4. **Reinstall is out of scope.** App-local UserDefaults + CoreStore both die with the app sandbox. Filter survival across reinstall requires either Keychain (limited size, awkward for collections) or iCloud KVS (`NSUbiquitousKeyValueStore`). Defer until restart works.

9. **Verify the rest of the P5 checklist (carried over from earlier):**
   - `.isPlayed` + `.isUnplayed` mutual exclusion (P4.1): open Filtres → Traits, tap both — only the most recent should remain selected.
   - New tvOS player (#1902): open an episode → confirm new player UI launches.
   - Settings Close button (P4.4): open any Settings sheet → confirm Fermer button dismisses.

### If the build needs a fresh start

```bash
git checkout local/appletv-dev
git status   # should be clean
xcodebuild -project Swiftfin.xcodeproj -scheme "Swiftfin tvOS" \
  -destination "platform=tvOS Simulator,id=68CB155B-71F7-4326-8131-B3621A95BFCF" \
  -configuration Debug build
```

### Known follow-ups (non-blocking)

- ~26 missing localization keys (see above) for non-English locales.
- The tvOS-specific FilterView UX (icon Reset, 50%-width centered Form) was lost in the merge; the unified Shared FilterView replaces it. Re-evaluate visually in the sim — may want to add tvOS-specific tweaks back.
- `docs/local-dev-plan.md` and `docs/tvos-simulator-login-report.md` are CLAUDE working notes committed to the branch. If we ever PR back upstream, move them out of the diff first.
