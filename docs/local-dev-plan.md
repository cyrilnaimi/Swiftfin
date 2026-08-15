# Local Dev Plan — `local/appletv-dev`

---

# ⛑ RESTORE POINTS — read this first if something is broken

**Last updated 2026-08-15.** Working branch: **`local/appletv-dev-v4`**, base = tag `1.5`.
Every restore point below is a real annotated tag; none of them has ever been force-moved.

### What is where

| Restore point | Commit | State | Where it runs |
|---|---|---|---|
| `local-v4-1.6-cherrypicks-2026-08-15` | `8b1bccc2` | v4 + hero-logo fix + **15 cherry-picks from upstream 1.6** | **← ON THE APPLE TV** (Release, profile expires **2026-08-22 18:06**) |
| `local-v4-hero-logo-fix-2026-08-15` | `fa89102f` | v4 + hero-logo fix only. Last state pushed to `origin` | briefly on the TV earlier the same day |
| `local-v4-pre-scrolling-grid-2026-08-08` | `82ff8161` | v4 **before** the drawer/title scrolling rewrite | — |
| `local-v2-2026-08-01` (branch `local/appletv-dev-v2`) | `c3596382` | the long-deployed v2 build | was on the TV until 2026-08-15 |
| `local/appletv-dev` | `3ce19f76` | P9 legacy, untouched since 2026-07-12 | — |
| `local-v3-archive-2026-08-02` | `0400265a` | wiped v3 (rebuilt on `upstream/main` — **rejected**, do not resurrect) | — |

### Rollback recipes

**Roll the branch back** (loses nothing — the tags keep every state reachable):

    git reset --hard local-v4-hero-logo-fix-2026-08-15

**Put an older build back on the Apple TV** — the deploy script builds from the working tree, so
check the tag out first:

    git checkout local-v4-hero-logo-fix-2026-08-15   # detached HEAD
    ./Scripts/deploy-appletv.sh
    git checkout local/appletv-dev-v4                # back to work

**Drop a single bad cherry-pick** instead of rolling everything back — each one is an isolated
commit carrying its upstream hash in the message:

    git revert <commit>          # e.g. git revert 942c79ee   (the HEVC device profile)

### Sync state — IMPORTANT

`origin/local/appletv-dev-v4` is at **`fa89102f`**. The 16 commits after it and the tag
`local-v4-1.6-cherrypicks-2026-08-15` are **local-only** — they exist on this machine and on the
Apple TV, nowhere else. Push before relying on them surviving a disk loss:

    git push origin local/appletv-dev-v4 && git push origin local-v4-1.6-cherrypicks-2026-08-15

### Standing traps when verifying a rollback

- Bundle id is `org.jellyfin.swiftfin.local.cnaimi` (from the gitignored
  `XcodeConfig/DevelopmentTeam.xcconfig`). `simctl install/launch org.jellyfin.swiftfin.local`
  silently runs a **stale** app while reporting success — always resolve the id from the built
  `Info.plist` and md5-compare the installed binary against the built one before trusting a test.
- The Apple TV always gets a **Release** build (`deploy-appletvos`), so
  `Swiftfin tvOSRelease.entitlements` must stay wired or keychain filter persistence fails *only*
  on the device.
- Free-Apple-ID profiles last **7 days**; re-run the deploy script (or the "Swiftfin.local update"
  Shortcut) weekly or the app dies on launch.

---

> _(2026-08-02 note, superseded by the table above)_ v3 was wiped after the user rejected it on the TV — its regressions were upstream-main UI redesigns, not our code. See "Session 2026-08-02".

> _(2026-07-12 note, historical)_ v2 upstream-rebuild on branch `local/appletv-dev-v2`: M0–M6 done, M7 verified 2026-07-31, deployed.

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
- [ ] Build sim Debug, sign in with `<user>/<pass>`, confirm token persists
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
| P5 | 🟡 in progress | — | First reinstall+launch at `23252324` crashed on UserSession.init → keychain assertionFailure (stale CoreData from `50971ebb`'s hack-era install). Wiping app + rebuilding fixed the launch path. Sign-in flow exercised by user with `<user>/<pass>` against `http://192.168.50.154:8096` (server "M1Center"). Surfaced 6 follow-up issues (see P5 audit) — being fixed in P5.1+. |
| P5.1 | ✅ done | `1a2ac2a3` | **Multi-pill library filter UI restored.** `LibraryHeader.swift` rewritten to iterate `enabledDrawerFilters` and render one pill per `ItemFilterType` (Genres, Lettre, Tri, Tags, Filtres, Années) — matches iOS `NavigationBarFilterDrawer` pattern. Active pills tint to accent color; each opens its own selector sheet via `.filter(type:, viewModel:)`. Reset pill added when any filter is active. Previous single "Tout" pill is gone. |
| P5.2 | ✅ done | `1a2ac2a3` | **Doubled title fixed.** `PagingLibraryView.swift` no longer sets `.navigationTitle(...)` — the `LibraryHeader` already renders the title + count inline, and the platform's auto nav-title was overlapping the grid. Single source of truth now. |
| P5.3 | ✅ done | `1a2ac2a3` | **Duplicate "Favoris" in Traits sheet fixed.** Root cause: French `Translations/fr.lproj/Localizable.strings` mapped both `favorites` and `likedItems` to `"Favoris"`. Changed `likedItems` → `"Aimés"` so `.isFavorite` and `.likes` are visually distinct. (File is UTF-16; edited via Python `codecs.open`.) |
| P5.4 | ✅ done | `1a2ac2a3` | **Filter persistence default flipped.** `SwiftfinDefaults.swift`: `rememberFiltering` and `rememberSort` now default to `true` (were `false`). Persistence machinery in `PagingLibraryView.swift:358-381` + read-back in `PagingLibraryViewModel.init:186-199` already symmetric; just unlocked it by default. User no longer needs to find/toggle the Settings option to get the expected behavior. |
| P5.5 | ✅ done | `1a2ac2a3` | **Local app icon now visibly green** (was identical cyan to App Store version). Two fixes: (a) `Swiftfin.xcodeproj/project.pbxproj` — `ASSETCATALOG_COMPILER_APPICON_NAME` changed from `"App Icon & Top Shelf Image"` to `"App Icon Local"` for tvOS Debug + Release (target-level pbxproj override was beating the xcconfig). (b) Regenerated all PNGs in `App Icon Local.brandassets/` from the upstream brandassets with a B↔G channel swap, turning the cyan triangle + dark-blue background into a green triangle + dark-green background. App Store imagestack flavor done too. |
| P5.6 | ✅ done | `1a2ac2a3` | **Empty Home (Accueil) page fixed.** Root cause: when the user had no Resume items, the `else` branch of `HomeView.contentView` rendered a `CinematicRecentlyAddedView` whose inner `CinematicItemSelector` forces `.frame(height: UIScreen.main.bounds.height - 75, alignment: .bottomLeading)` — i.e. the entire screen minus 75pt. This full-screen frame, combined with `.ignoresSafeArea()` on the outer ZStack, pushed every subsequent row (NextUp, Latest-per-library, libraries-shortcut) off-screen even though the data was actually loaded. **Fix:** rewrote `Swiftfin tvOS/Views/HomeView/HomeView.swift` to use a flat stacked layout — `NextUpView → RecentlyAddedView (non-cinematic) → ForEach(libraries) → librariesShortcut` — with `padding(.top, 130)` to clear the top nav. Cinematic hero kept ONLY when Resume items exist. Also added a guaranteed-non-empty `librariesShortcut` fallback row that lists the user's libraries as poster cards. Verified on sim: 9 Next Up items + 50 Recently Added + 50 Movies + 40 TV Shows + 8 Anime + 1 Fast_Anime all render correctly. |
| P5.7 | ✅ done | `1a2ac2a3` | **Multi-pill filter UI polished to match iOS / Settings style.** First pass at P5.1 produced functional but visually-busy pills ("a bit ugly" per user). Rewrote `LibraryHeader.swift` with: capsule shape (matches iOS `NavigationDrawerLabelStyle`), `ultraThinMaterial` background with stroke outline, chevron-down indicator on each pill, accent fill when active, custom `FilterPillButtonStyle` providing subtle focus lift (scale 1.08 + shadow) without the heavy `.card` chrome that wrapped earlier pills. Title moved above the pill row (was crammed inline). |
| P5.8 | ✅ done (verified via NSLog diagnostics 2026-05-27) | `1a2ac2a3` | **Confirmed working.** Diagnostic `NSLog`s added to the `.onChange` write block (`PagingLibraryView.swift:360-380`) and the `init` read (`PagingLibraryViewModel.swift:186-205`); sim run showed Anime library (`parentID=0c41907140d802bb58430fed7e2cd79e`) reading `traits=["IsUnplayed"]` on relaunch — i.e. persisted across full terminate+launch. Full cycle (`onChange FIRED` → `WROTE` → `READBACK` → next-launch `INIT READ`) is clean. The earlier "still fails" report was against a stale install where the uncommitted code wasn't actually on the sim. Diagnostic `NSLog`s were removed before `1a2ac2a3` — grep on `PagingLibraryView.swift` + `PagingLibraryViewModel.swift` confirms clean. Original-issue text below kept for history.<br><br>**Original (now resolved) text:** Defaults gates removed (unconditional read+write of `StoredValues[.User.libraryFilters(parentID:)]`) but live test STILL shows the filter not surviving an app terminate+relaunch. Code changes done: removed `if Defaults[.rememberFiltering]` / `rememberSort` gates in `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift:184-200` (read) and `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` `.onChange` (write). **Next-session hypotheses to investigate:** (a) `User.libraryFilters(parentID:)` is keyed via `CurrentUserKey(..., storage: .sql)` — the CoreStore SQL transaction may not be committing before app terminate, OR `ItemFilterCollection`'s Codable round-trip may be dropping the `traits` field; (b) `.onChange(of: viewModel.filterViewModel?.currentFilters)` may not be firing on the user-action path — try observing `filterViewModel.$currentFilters` Combine publisher with `.sink` directly in the view model so the write isn't view-layer-dependent; (c) verify with a temporary `NSLog` in `StoredValues[...] = newStoredFilters` setter that the write actually happens when the user toggles a trait. **Reinstall does NOT preserve filters by design** — `StoredValues` is app-local (UserDefaults + CoreStore); uninstall wipes the sandbox. Surviving reinstall would need keychain or iCloud-synced storage (out of scope). |
| P5.10 | ✅ done (audit only — no code change) | — | **Filter settings → library-view wiring audited.** All filter-related defaults verified to be honored on tvOS. User report: "Letter Picker disabled in Settings, but Lettre pill still in drawer." → **Not a bug.** `Library.letterPickerOrientation` only controls the side A-Z bar (`LetterPickerBarModifier.swift:21`), while individual filter pills are governed by `Library.enabledDrawerFilters` (default `ItemFilterType.allCases`, iterated at `LibraryHeader.swift:64` and gated whole-header at `PagingLibraryView.swift:262`). These two settings are independent by design — same as iOS and Jellyfin Web. To hide the Lettre pill, the user must uncheck "Letter" under Settings → Filtres → Bibliothèque. Decision (2026-05-27): **document only, no code change.** Per-type honor matrix: `.genres / .letter / .sortBy / .tags / .traits / .years` all correctly route through `OrderedSectionSelectorView` (`NavigationRoute+Settings.swift:158`) → `$libraryEnabledDrawerFilters` → `LibraryHeader` `ForEach`. `Search.enabledDrawerFilters` is iOS-only; not wired on tvOS (no current tvOS filter UI in Search). Other library customizations (`displayType`, `posterType`, `listColumnCount`, `rememberLayout/Sort/Filtering`, `showFavorites`, `randomImage`) all verified to be read on the tvOS code path. |
| P5.9 | ✅ done | `1a2ac2a3` | **Local app icon now visibly green** (P5.5 follow-up — first attempt embedded a "LOCAL" red ribbon, user preferred a clean color shift). Regenerated `App Icon Local.brandassets/**/*.png` from the upstream brandassets with a B↔G channel swap so the cyan jellyfin triangle becomes a green triangle on a dark-green background. Front (216 + 432 + 512 sizes) and Back (400×240 + 1280×768) layers all recolored. Combined with the P5.5 pbxproj patch (`ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon Local"` for tvOS Debug + Release), the home-screen icon is now distinctively green vs the App Store cyan version. Verified visually — see `/tmp/swiftfin-sim/06-green-icon.png` and `/tmp/swiftfin-sim/27-home-bottom.png`. |
| P5.11 | ✅ done | _this commit_ | **Real-hardware first-run fixes.** Three issues surfaced after installing on the paired Apple TV: (a) Settings → Customize → Library showed "Remember filtering" in English between two French strings — `rememberFiltering` / `rememberFilteringFooter` were missing from `fr.lproj/Localizable.strings`; added. (b) Home page had a redundant "Libraries" PosterHStack at the bottom (introduced as a P5.6 fallback) that duplicated the Media tab — removed. (c) Pressing Menu on the player always showed a "Close player?" confirmation popup, lost setting from official 1.0.1. Root cause: `Defaults[.VideoPlayer.confirmClose]` key exists (default `false`) but `VideoPlayerContainerView.swift:840` was unconditionally firing the alert — gate restored. Also added a tvOS-only `Toggle(L10n.confirmClose, …)` to Settings → Video Player → Buttons so the user can re-enable the popup. New strings `confirmClose` + `confirmCloseFooter` added to en/fr/Strings.swift. |
| P6 | ✅ done | — | "## 8. Resolution" section added to `tvos-simulator-login-report.md` — points at `167628b7`, documents the empty-`.xcent` caveat on sim, lists upstream issues likely closed (#163/#776/#809/#930), and warns about the stale-CoreData crash when rolling a pre-`167628b7` install forward. |
| P7.1 | ✅ done | `73f50da8` | **Home hero backdrop fixed** (user photos: official vs local). Root cause: appletv-stack rewrite passes `initialItem: items.first` to `CinematicBackgroundView` but never consumes it; backdrop only rendered on `currentItem` change, and `select()` only fired on focus change behind the `isSectionFocused` guard → permanently blank on first land. Fix: seed `viewModel.select(initialItem)` on appear when nothing selected (goes through debounce + `removeDuplicates`, so no double crossfade). Bug also exists in upstream `main` (verified) → standalone upstream PR candidate. Verified on real Apple TV. |
| P7.2 | ✅ done | `4abe5f15` | **Release build fixed** — `isLiquidGlassEnabled` key is `#if DEBUG`-only (SwiftfinDefaults convention) but `ListRowMenu` + both `SupplementTitleButtonStyle` variants consumed it unguarded; every Release build failed while Debug passed. Guarded usage sites with `#if DEBUG` / `let = false` fallback. Same bug present in upstream #1902 head `d82171f6` — flag in PR feedback. |
| P7.3 | ✅ done | `b75cc27c`→`43f6fcc9` | **Weekly re-sign loop automated.** `Scripts/deploy-appletv.sh`: deletes cached profile (forces fresh 7-day window), Release build with `-allowProvisioningUpdates`, network install via `devicectl` to Sonyapptv (`BB8195CC-…`), single-instance mkdir lock (concurrent runs raced the build DB), stdout = one summary line for the macOS Shortcut **"Swiftfin.local update"** → native "Afficher la notification" action. Deployed 2026-06-06, profile expires 2026-06-13 ~16:42. |
| P7.4 | ✅ done | — | **Fork + remotes restructured**: `origin` = cyrilnaimi/Swiftfin (public fork), `upstream` = jellyfin/Swiftfin; `local/appletv-dev` pushed/tracking. Staging branches (`appletv-stack`, `pr-1770-filters`, `pr-1882-track-fixes`, `pr-1902-tvos-player`) deleted — all fully contained; PR heads re-fetchable via `git fetch upstream pull/<N>/head`. `main` fast-forwarded. `screens/` gitignored (private photos). |
| P8.2 | ✅ done | `be676573` | **Cinematic backdrop never rendered — root cause of every "title on black" hero.** Diagnosed live on sim (server back up): `NSLog` instrumentation showed `cinematicImageSources` returning `[]` for items that *do* have `BackdropImageTags` server-side. Root cause: `newItem?.cinematicImageSources(maxWidth: nil)` (one argument) on `AnyPoster` can't resolve to AnyPoster's two-parameter forwarding method (no default args), so overload resolution statically dispatches to the `[]` default in the `Poster` protocol extension — `BaseItemDto`'s real implementation is never reached. Fix: pass `quality: nil` explicitly. **Bug also present in upstream `main`** → standalone PR candidate (alongside the P7.1 seed fix it makes the hero actually work). Also explains why `73f50da8` "never visually confirmed": the seed worked, the image URL was always nil. |
| P8.3 | ✅ done | `17b94998` | **Hero shows first item before focus enters the row.** `topContent` (logo) was gated on `@FocusedValue(\.focusedPoster)` — nil until focus lands on the strip → blank hero on first display. Falls back to `items.first` now, matching the P7.1 backdrop seeding. |
| P8.4 | ✅ done | `1ebdd1f3` | **Home layout per user spec: Continue Watching → À suivre → per-library rows.** (a) New `CinematicNextUpView` (60-line sibling of `CinematicResumeView`): Next Up is promoted to the hero when nothing is mid-play; 16:9 landscape strip; labels = series title + SxEx only (never episode names). (b) Hero priority Resume → Next Up → Recently Added (last resort so home never lacks a hero); promoted section skipped as a row. (c) **Global "Ajoutés récemment" row deleted** — duplicated the per-library "Latest in" rows. (d) Hero strips capped at 10 items (paging VM pages 50). `ContentView` observes `nextUpViewModel` directly (same late-arrival trap as P8.1 documented for recentlyAdded). Iterated live with user on sim: episode-thumbs version and portrait-posters version both rejected before landing on the official-1.0.1 look. |
| P8.5 | ✅ done | `f8c3b8ff` | **Series-art-first regression fixed for episode landscape cards.** appletv-stack rewrite inverted the fallback order to episode-still-first, surfacing unrecognizable episode thumbnails in every 16:9 strip/row. Restored 1.x order (verified against upstream tag `1.1.1`): series thumb → series backdrop → episode primary, gated on `useSeriesLandscapeBackdrop` (default true). **Regression from upstream #1902 head** → flag in PR feedback. |
| P8.1 | ✅ done | `bf12d2e9` | **Cinematic hero restored when no Resume items.** User report after the P7 deploy: Home opened on "À suivre" (Next Up) with no hero banner at all. Not a regression from `73f50da8` (backdrop seed is additive and only runs when a hero already renders) nor `4abe5f15`: `HomeViewModel` + `CinematicItemSelector` + `CinematicRecentlyAddedView` are byte-identical to `upstream/main`. The hero was missing **by P5.6 design** — `1a2ac2a3` deleted the `CinematicRecentlyAddedView` fallback entirely, so any moment the server has zero resume items (e.g. just-finished episode), Home renders flat rows, diverging from the App Store build which always shows a hero. **Fix:** restore the Recently Added cinematic hero, but gated on `elements.isNotEmpty` — this fixes the original P5.6 blank-home bug at its root (`CinematicItemSelector` renders its full-screen `UIScreen.height - 75` frame even with zero items) instead of amputating the hero. `contentView` extracted into a `ContentView` struct that observes `recentlyAddedViewModel` directly (its items arrive *after* `state` flips to `.content`, and `HomeView` only re-renders on `HomeViewModel` changes — a naive gate would intermittently miss the hero). Recently Added row skipped when it's already the hero (matches upstream). Dead `@Router` removed from `HomeView`. **Release tvOS build ✅.** If the hero is still missing after deploy *while an item is genuinely in progress*, that's a different bug — re-open. |

### Session 2026-06-06 — upstream PR review (decision: fork only, no PRs yet)

All four source PRs still OPEN upstream (#1770 `17b13d7f` ✅ no drift, #1882 `65579dec` ✅ no drift, #1902 → `d82171f6` ⚠️ drifted again, #1752 not integrated). When the user asks to propose upstream:

- **Standalone PRs off `upstream/main`**: (a) tvOS keychain entitlements (`167628b7`, genericized to `org.jellyfin.swiftfin`, no team) — main's tvOS target still has no `CODE_SIGN_ENTITLEMENTS`; (b) hero backdrop seed (`73f50da8`) — bug verified in main.
- **Home rewrite (P5.6/P5.11)**: file an *issue*, do NOT PR — collides with LePips's #1752 HomeView rewrite.
- **#1770 feedback**: multi-pill LibraryHeader, safeAreaInset fix, persistence default flip, mutual exclusion — as PR comments/patches (precedent: PR author merges contributor branches).
- **#1902 feedback**: confirmClose gate, isLiquidGlassEnabled Release guard — re-check against `d82171f6` first.
- **Translations**: Weblate only; en.lproj keys travel with feature PRs.

**Open at session end:** Shortcut notification shows title only — user still needs to (a) allow "Éditeur de script" in Réglages Système → Notifications and/or (b) move the `Résultat du script shell` chip from *Pièce jointe* into the notification *body* field. Filter-persistence-across-reboot (see `tvos-filter-persistence-research.md`) still research-only.

Legend: ✅ done · 🟡 in progress · 🔴 blocked · ⚪ pending

### P5 audit findings (2026-05-26 session — first user sim test)

User signed in to the booted sim against `http://192.168.50.154:8096` (`<user>/<pass>`) and surfaced six issues — five fixed in P5.1–P5.5 above, one (Home empty) still under investigation as P5.6.

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

- **Rotate the leaked API key on the Jellyfin server** ✅ done by user. The key was `<redacted-api-key>`; it appeared in a working-tree patch only and will not enter any commit on this branch.
- **Upstream PR**: if the team wants, the Phase 1 commit (`167628b7`, keychain fix) is a strong candidate for a small focused upstream PR — high value, low risk, likely closes multiple long-standing tvOS issues.
- **Outstanding `Localizable.strings` keys**: ~26 #1770-only keys are not in the merged en.lproj. They have runtime fallbacks via `Strings.swift`, so the UI works in English but other locales show key names. Not blocking; add as a follow-up if you want clean translations.

---

## Next session — pick-up checklist

### State at pause (2026-06-07 evening — P8 complete, deploy to Apple TV pending)

- Branch `local/appletv-dev`, clean tree, HEAD = `f8c3b8ff` (P8.2–P8.5). Debug verified live on sim; Release build re-verified at HEAD.
- **The P8 open questions are all answered:**
  1. "Hero title-on-black" → was the P8.2 dispatch trap; backdrop picture now renders (verified, `/tmp/swiftfin-sim/p8-12-series-art.png`).
  2. "User always has Continue Watching items" → **server says no**: `/Users/{id}/Items/Resume?mediaTypes=Video&limit=20` returns `TotalRecordCount: 0` for `<user>` while Next Up has 11 — the P7-deploy behavior was data-correct. (If the real Apple TV uses a different account, re-check there.) The Next Up hero now covers exactly this case.
  3. Hero fallback + row layout → reworked per user spec in P8.4.
- Sim `68CB155B-…` has the final P8 Debug build installed, signed in to M1Center (`<user>`).
- **NEXT STEP: deploy to the Apple TV** — `Scripts/deploy-appletv.sh` or the "Swiftfin.local update" Shortcut — then verify on hardware: Next Up hero with series backdrop + logo, series 16:9 cards w/ title+SxEx, "Anime récents…" rows below, and (once something is mid-play) Continue Watching hero with À suivre row below it.
- AppleScript key events to the sim are blocked by macOS Accessibility (`osascript … 1002`) — grant Accessibility to the terminal if scripted UI driving is needed next time.

### Previous pause (2026-05-26 late evening, after second pass):

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

### Upstream PR drift snapshot (last checked 2026-05-27)

Audited the three PRs we forked from, plus #1752 which is in the same area.

| PR | Our head | Upstream head | Drift |
|---|---|---|---|
| #1770 Library Filters and Sorting | `17b13d7f` | `17b13d7f` | ✅ none |
| #1882 Index/Track Fixes | `65579dec` | `65579dec` | ✅ none |
| #1902 tvOS Media Player | `fd14fea3` | `6e14bf72` | ⚠️ +2 `wip` commits |
| #1752 Posters, Libraries, Home (LePips) | _not integrated_ | `e7bae1d2` | — see §"#1752 — not integrated, not desirable" below |

`origin/main` since our merge: only Weblate translation updates — nothing actionable.

#### #1902 — what the two `wip` commits actually are

Important context from the PR conversation: JPKribs (original author) handed off and listed three known performance issues with fixes ideas. LePips (project owner) then started his review pass and pushed the two `wip` commits. **These are not new bug fixes for problems we have — they are LePips's final-polish iterations on top of JPKribs's handoff.**

**`1a714fef` (May 25, 12 files, +294 / −124) — "scrub state cleanup + perf"**
- `Shared/Objects/VideoPlayerContainerState.swift`: removes the duplicate `hasEnteredScrubMode` flag (could desync from `isScrubbing` — a real latent bug). Moves `centerOffset` from `@Published var` to a `PublishedBox` wrapper so view re-renders no longer trigger on every offset tick during scrubbing — directly addresses JPKribs's listed item #1 (scrub perf).
- `Swiftfin tvOS/Objects/SupplementTabView.swift` (+177): reworks the tvOS supplement tab logic — addresses JPKribs's item #2 (TabView scrolling hitches).
- `Swiftfin tvOS/Components/VideoPlayerSlider.swift`, `PlaybackProgress.swift`, `PlaybackControls.swift`: slider state-model cleanup.
- `Package.resolved` bump.

**`6e14bf72` (May 26, 25 files, +298 / −124) — "structural reorg + new visual primitives"**
- 11 file renames: `Shared/Views/VideoPlayer/Components/NavigationBar/` → `Toolbar/`. Same code, new folder (94–97% similarity per rename — why the file count looks scary).
- New `Shared/Components/TintedMaterialShapeStyle.swift` (+36) — new visual primitive for player chrome.
- New `Shared/Views/VideoPlayer/ButtonStyle/OverlayButtonStyle.swift` (+55).
- Small tweaks to `MediaInfoSupplement` (+30), `VideoPlayerActionButton` (+30), `MediaChaptersSupplement`.
- Another `Package.resolved` bump.

**Decision: defer both.** The player works in our sim test (verified P5 session). `1a714fef` has a small latent bug fix worth pulling *if* scrub-state weirdness surfaces on the AppleTV hardware, but the rest is forward-looking polish, not bugfixes. Both commits touch `project.pbxproj` + `Package.resolved` — exactly where conflicts with our `e5b869c` CollectionVGrid pin and `App Icon Local` asset name live.

**Re-evaluate when** (a) #1902 is marked ready-for-review / loses `wip`, (b) a scrub or supplement-tab perf issue surfaces on real hardware, or (c) we do a deliberate sync-to-upstream sweep before tagging.

**If we want a partial pull later:** cherry-pick `1a714fef` only (skip `6e14bf72` cosmetic reorg). Tracking branch already fetched at `jpkribs/tvOSPlayer`; commits are: `git cherry-pick 1a714fef`.

#### #1752 — not integrated, not desirable

PR #1752 "Posters, Libraries, Home" (LePips, last updated 2026-05-09) is a foundational refactor — **444 files changed, +11,576 / −16,366 LOC**. It moves `PosterHStack` from per-platform folders to `Shared/Components/`, introduces `LibraryElement` / `LibraryStyle` / `PosterStyleRegistry` / `ContentGroup` / `PosterGroup` abstractions, and **deletes** `Swiftfin tvOS/Views/HomeView/HomeView.swift` entirely (replaces it with a new architecture).

**We did NOT use #1752 for our P5.6 home-page rewrite.** That fix was a 111-line self-contained rewrite of `HomeView.swift` built on top of the existing tvOS components (`NextUpView`, `RecentlyAddedView`, `LatestInLibraryView`, the tvOS-specific `PosterHStack` at `Swiftfin tvOS/Components/PosterHStack.swift`).

**Do not merge #1752 onto this branch.** Three reasons:
1. It would delete the `HomeView.swift` we just polished and force re-doing the P5.6 layout on top of the new `PosterStyleRegistry` / `ContentGroup` abstractions.
2. Scope mismatch — `local/appletv-dev` is a focused local release, #1752 is a 444-file architectural reshuffle.
3. Conflict surface is enormous. Almost every poster / library / indicator file we touched in P5 is also touched by #1752.

Only re-evaluate if rebasing onto an upstream main that has already merged #1752 — at that point we'd have to take it anyway and the work moves to porting P5.6 onto the new architecture (or accepting #1752's home design unchanged).

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

2. **Verify P5.1 (multi-pill filter UI):** Sign in (`<user>`/`<user>` against `http://192.168.50.154:8096`). Open Films or any library. Confirm the header now shows multiple filter pills (Genres, Lettre, Tri, Tags, Filtres, Années) instead of a single "Tout" pill. Each pill should be tappable and open its own selector sheet.

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

---

## Session 2026-07-12 — progress review + unplayed-filter root cause + upstream-sync assessment

Tree clean at `efa959f8`. **Safety tag created before any changes: `local-working-2026-07-12-P8`** (annotated, local-only, not pushed) — restore point for the known-good P8 build.

### P9 — "unread/unplayed filter doesn't work from the main UI bar" (Movies / TV Shows) — ROOT CAUSE FOUND (no fix applied yet)

**Symptom (user):** picking the *unplayed / non lu* filter from the tvOS **top tab bar** Movies or TV Shows tab doesn't stick; doing the same inside a real **Media-tab** library works.

**Root cause (verified in code):** the tvOS top-bar Movies/TV Shows tabs are built by `TabItem.library(...)` (`Shared/Coordinators/Tabs/TabItem.swift:56-73`), which hands the `ItemLibraryViewModel` a **synthetic parent with `id == nil`**: `TitledLibraryParent(displayTitle: title)` (`TitledLibraryParent.swift:13-23`, `id` defaults to nil). The Media tab instead opens the real `collectionFolder` `BaseItemDto` with a real id (`MediaView.swift:41-46`).

Everything downstream keys off `parent.id`:
- **Filter persistence save** is guarded `guard let newValue, let id = viewModel.parent?.id` (`Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift:360-378`) → **skipped** when id is nil.
- **Filter restore on open** is guarded `if let id = parent?.id` (`PagingLibraryViewModel.swift:184-201`) → **skipped**.
- The store key itself is `parentID`-based (`StoredValues+User.swift:142-152`).

So from the main-bar tabs the chosen filter is never saved or restored, while from the Media tab (real id) it is. (The *live in-session* query does still carry `Filters=IsUnplayed` + `IncludeItemTypes=Movie/Series` via the preset at `ItemLibraryViewModel.swift:87,96-98`, so the visible failure is primarily "doesn't persist/stick", not "never filters at all". Note also that with a nil-id parent `isRecursive` falls back to `true` and no `parentID` scoping is sent — an unscoped server-wide query — vs. the scoped Media-tab query.)

**Minimal fix (designed, verified safe, NOT yet applied):** give the two main-bar tabs a **stable non-nil id**, e.g. `TitledLibraryParent(displayTitle: title, id: "tab-movies")` / `"tab-tvshows"` at `TabItem.swift:66-67`. Because `libraryType` stays nil, `setParentParameters` (`LibraryParent.swift:40-61`) passes the `guard let id` but its `switch` default case does **not** set `parentID` — so the server-wide semantics of these aggregate tabs are preserved — while the preset `filters.itemTypes` re-overrides `includeItemTypes` at `ItemLibraryViewModel.swift:96-98`. Net effect: persistence keys now resolve; query unchanged. `isRecursive` also unchanged (parent still isn't a `BaseItemDto`). One-line-per-tab change, low risk.

**Upstream relevance:** this bug is in `Shared/` code and also exists in upstream `main` (pre-#2047), so the fix is upstreamable — but see the sync note below: upstream rewrote this whole area in #2047, so the exact files differ there.

### Upstream-sync assessment (`local/appletv-dev` = 391 ahead / 118 behind `upstream/main`, merge base `d95903d1`)

- Of the 118 upstream commits since our base, ~75 are Weblate/translation-only; ~43 are real code (442 files, +14.3k/−9.6k, epicenter = `Shared/`).
- **Two of our three forked PRs already landed upstream:** #1882 Index/Track Fixes (`74fa43fb`) and #1902 [tvOS] Media Player (`09884e00`). Our imported copies (`f122abb9` merge, etc.) are now **redundant and divergent**.
- **#1770 (library filters) did NOT land**; instead the whole library/poster/home area was **rewritten** by `Generic Paging Libraries (#2047)` `75282082` (+ #2068 poster cleanup, #2066 blurhash) — which supersedes LePips's #1752. `PagingLibraryView.swift`, `PagingLibraryViewModel.swift` etc. that our filter work depends on were **deleted/rewritten upstream**.
- A straight `git merge upstream/main` = **61 conflicting files** (`git merge-tree`, working tree untouched), the hardest being modify/delete collisions on the exact PagingLibrary files #1770 edits, plus the VideoPlayer NavigationBar↔Toolbar directory restructure. **Not advisable as a merge.**
- **Local-distinction layer is conflict-free** (App Icon Local brandassets, Info.plist bundle id, deploy script all untouched upstream).

**Recommended sync path (when we choose to do it — medium/high effort, NOT started):** rebuild on a fresh `upstream/main`, *drop* the now-obsolete #1882/#1902 import commits, cherry-pick the conflict-free local-distinction commits (`b628bfea`, deploy-script chain, `4cd7c1f9`), then **re-author the #1770 filter feature + P8 home/hero polish on top of the new #2047 architecture**. That re-authoring is the real cost.

**Decision for now:** stay pinned on the known-good build (tagged). No merge/rebase performed this session. Re-evaluate a deliberate sync sweep as its own project.

---

# Upstream Re-architecture & Reapply Plan (drafted 2026-07-12)

> Complete review + plan for porting our work onto upstream's rewritten architecture and reapplying all our UI polish for a clean result. **No code written for this plan yet** — it is the map for a future dedicated effort. Tags `local-working-2026-07-12-P8` (pre-P9) and `local-working-2026-07-12-P9` (with the main-bar filter fix) are the restore points. A read-only reference branch **`sync/upstream-base`** tracks `upstream/main` (`1dfbb7a1`).

## A. Home-page comparison finding — ours is still the better UX

Upstream did **not** redesign the tvOS home page. `upstream/main:Swiftfin tvOS/Views/HomeView/HomeView.swift` is essentially the **pre-P8 baseline we started from**, and it still carries the bugs we fixed. What upstream changed is the *plumbing beneath* the home (generic paging VMs, FactoryKit, image API) — not the layout.

| Aspect | Ours (P8, `local/appletv-dev`) | Upstream `main` |
|---|---|---|
| Hero when nothing is mid-play | `CinematicNextUpView` (Next Up promoted to hero) | none — drops straight to a Recently Added hero |
| Blank-home bug (zero-resume / fresh account) | **fixed** — hero gated on `.elements.isNotEmpty` | **still present** — `CinematicItemSelector` renders its full-screen frame even when empty, pushing rows off-screen |
| Duplicate global "Recently Added" row | **removed** (duplicated per-library "Latest in" rows) | still rendered as a row |
| Late-arrival re-render (hero intermittently blank) | **fixed** — `ContentView` observes child VMs directly | latent bug — observes only `HomeViewModel` |
| Hero strip length | capped at 10 | scrubs all 50 paged items |
| Episode landscape art (series-art-first) | ours (P8.5) | **already upstream** — `BaseItemDto+Poster.swift:94-99` does series-thumb→backdrop→episode-primary gated on `environment.useParent` (= our `useSeriesLandscapeBackdrop` default) |

**Verdict:** keep ours for UX. But our home components sit on the **old** data/image stack, so they've drifted — the P8 polish must be **re-ported onto upstream's new stack**, not merged. (Exception: P8.5 series-art ordering is effectively already upstream — verify, likely drop.)

## B. New-architecture reference (where each concept now lives on `upstream/main`)

| Concept | OLD (local/appletv-dev) | NEW (upstream/main) |
|---|---|---|
| Generic paging VM | `Shared/ViewModels/LibraryViewModel/PagingLibraryViewModel.swift` (concrete subclasses) | `Shared/Objects/PagingLibrary/PagingLibraryViewModel.swift` — `PagingLibraryViewModel<Library: PagingLibrary>`, `@Stateful(conformances:[WithRefresh.self])` |
| "Library" abstraction | n/a (baked into VM subclasses) | `Shared/Objects/PagingLibrary/PagingLibrary.swift` protocol + `Shared/Objects/Libraries/*.swift` value types (`ItemLibrary`, `LatestInLibrary`, `NextUpLibrary`, `RecentlyAddedLibrary`) |
| Request building (filters/parentID/itemTypes) | `ItemLibraryViewModel.itemParameters` + `LibraryParent.setParentParameters` | `ItemLibrary.makeBaseItemParameters(environment:)` (`Shared/Objects/Libraries/ItemLibrary.swift:160`) + `attachFilters(to:using:)` (`:206`) |
| Main library view | `Swiftfin tvOS/Views/PagingLibraryView/PagingLibraryView.swift` (tvOS-specific) | `Shared/Objects/PagingLibrary/PagingLibraryView/PagingLibraryView.swift` (shared, generic) → `library.makeLibraryBody(...)` |
| tvOS filter drawer/header | `Swiftfin tvOS/.../Components/LibraryHeader.swift` (our multi-pill UI) | **gone** — no tvOS filter UI upstream. Hook point = `ItemLibrary.swift:297` `#if os(tvOS)` branch (currently only a blurred background) inside `ItemLibraryBody` (`:248`) |
| FilterViewModel / ItemFilterCollection / ItemFilterType | same paths | **same paths, same API** (only DI/`send` cosmetic diffs). `traits` still carries `isUnplayed`; reaches request via `attachFilters` `parameters.filters = filters.traits` |
| Filter persistence key | `StoredValues+User.swift:142` `libraryFilters(parentID:)` (+ our `storage:.keychain`) | `StoredValues+User.swift:126` **identical keying**, default CoreStore backing (no keychain) |
| Movies/TV main-bar tabs | `TabItem.library(…, parentID:)` (our stable-id fix) | `TabItem.swift:57` `library(title:systemName:filters:)` → `ItemLibrary(parent: BaseItemDto(name: title))` → **nil id** |
| Home NextUp hero | `Components/CinematicNextUpView.swift` (ours) | absent — recreate |
| Episode landscape art | `BaseItemDto+Poster.swift` `seriesImageSource(...)` | `BaseItemDto+Poster.swift:89` `@ImageSourceBuilder landscapeImageSources(environment:)`, `environment.useParent` |
| Video-player chrome dir | `Components/NavigationBar/` | `Components/Toolbar/` (renamed) |
| DI | `import Factory` (66 files) | `import FactoryKit` (mechanical rename) |
| VM action dispatch | `viewModel.send(.refresh)` | migrated VMs → `viewModel.refresh()` / `await viewModel.refresh()`; `HomeViewModel` still classic `.send(...)` |

**Key porting facts:**
- The P9 nil-id filter-persistence bug **still exists upstream** (`TabItem.swift:69` builds `BaseItemDto(name: title)`, no id). Our fix re-attaches by giving that parent a stable id (`"tab-movies"`/`"tab-tvshows"`); since `type` stays nil, query semantics are unchanged, only the persistence key resolves.
- Three of our cross-cutting fixes are **now redundant/obsolete upstream** — do NOT re-apply: `confirmClose` gate (upstream `VideoPlayerContainerView.swift:873`), `isLiquidGlassEnabled` guard (upstream has real `#available` guards), `debugBackground` Release fix (no unguarded call sites upstream).

## C. Commit inventory (393 ahead) → disposition

Authorship blocks map onto categories:

- **KEEP-AS-IS (local-distinction, conflict-free cherry-picks) — ~15 commits:** icon/rename `b628bfea`; signing `3b555d81`, `167628b7`; deploy script `b75cc27c`+`b18422bd`+`43f6fcc9` (squash); `4cd7c1f9` gitignore; all working-notes docs (`6a379ad8`, `ccb48b51`, `7fb3b6da`, `b4563b79`, `0676143e`, `47a545e4`, `b9532795`, `3801cae0` — consider squashing). `f5aeb5b6` CollectionVGrid pin = RE-CHECK (take upstream's newer rev if any). `pbxproj` hunks in signing commits need manual re-apply against the new project file.
- **OBSOLETE (already upstream, DROP entirely) — ~214 non-merge + ~109 merges:** the whole imported #1902 tvOS Player + #1882 Index/Track history (Joe/Ethan authored), all "Merge main into tvOSPlayer" noise, `players.md` docs, `#1905` policy, and the integration merges `f122abb9`/`4613281f`/`d7c2fa1e`/`17b13d7f`. Upstream has these at `09884e00`/`74fa43fb`.
- **RE-CHECK then likely DROP — 3–4:** `4abe5f15` isLiquidGlass (**obsolete**), `557523f8` debugBackground (**moot**), close-player half of `c66c7d5b` (**already upstream**), `23252324` nav close button (verify upstream tvOS already has one).
- **RE-AUTHOR (the real work) — ~14 cyril commits + the ~28-commit #1770 block:** everything touching library/paging/filter/home/hero. Target files were moved/deleted by #2047. **Do not replay diffs — re-implement the feature intent once against the new architecture.** Highest-value cluster: `1a2ac2a3` (P5 multi-pill + persistence + green icon + home — split icon out as KEEP), `35321724` (played/unplayed filter cases + mutual exclusion), `efa959f8` (keychain-backed filters), `585927d3` (main-bar stable id / P9), the P8.x home/hero set (`bf12d2e9`, `17b94998`, `be676573`, `73f50da8`, `1ebdd1f3`, `f8c3b8ff`), pill styling (`cd550694`, `4857ef41`, `0851fff3`).

## D. Migration plan — phases (each phase ends BUILD SUCCEEDED + sim smoke test)

> Work on a new branch off `sync/upstream-base`, e.g. `local/appletv-dev-v2`. Keep `local/appletv-dev` untouched as the shipping branch until v2 reaches parity + is deployed & verified on the Apple TV.

- **M0 — Base + local-distinction (low risk).** Branch `local/appletv-dev-v2` from `sync/upstream-base`. Cherry-pick/re-apply the KEEP-AS-IS set: green icon brandassets + display name (`b628bfea`), bundle-id/signing (`3b555d81`, `167628b7`) — re-do `pbxproj`/entitlements hunks by hand against the new project file — deploy script (squashed), `.gitignore`, docs. Confirm the local app builds, installs, shows the green icon, coexists with the App Store app. **Gate:** Release build green, icon distinct, signs with free profile.
- **M1 — Keychain-backed StoredValues (medium).** Re-implement `efa959f8`: add `storage: .keychain` to `StoredValues+User.swift:126` `libraryFilters(parentID:)` and re-create the `KeychainObservable` / `_GenericValueObservation` support against upstream's current `StoredValue` API. **Gate:** a filter set on a real library survives app reinstall on the sim.
- **M2 — Filter feature: played/unplayed + persistence semantics (hard, core).** Ensure `ItemFilterType`/`ItemFilterCollection` expose the played/unplayed traits and the `.isPlayed`/`.isUnplayed` mutual-exclusion (`35321724`). Verify the reactive path `filterViewModel.$currentFilters` → `ItemLibrary.environment.filters` → `attachFilters` already carries `traits`. Flip `rememberFiltering`/`rememberSort` defaults to `true` if desired (our P5.4). **Gate:** on the Média-tab library, unplayed filters apply and persist across navigation + relaunch.
- **M3 — tvOS multi-pill filter UI (hard, biggest single item).** Recreate our `LibraryHeader` multi-pill drawer (one pill per `enabledDrawerFilters` type: Genres/Lettre/Tri/Étiquettes/Filtres/Années; accent tint when active; capsule + material + chevron style; reset pill) and mount it in the tvOS branch of `ItemLibraryBody` (`ItemLibrary.swift:297` `#if os(tvOS)`), reading the `filterViewModel` the library already holds (`:33`). Re-apply the safeAreaInset/header approach (`0851fff3`) — first check whether upstream's shared `PagingLibraryView` already supports a header slot. Fold in pill polish (`cd550694`, `4857ef41`). **Gate:** Films/Séries libraries show the pill row; each opens its selector; single title (no doubled nav title).
- **M4 — Main-bar Movies/TV Shows fix / P9 (medium, depends on M1–M2).** Re-apply the stable-parentID fix at `TabItem.swift:69` — `BaseItemDto(id: "tab-movies"/"tab-tvshows", name: title)`. **Gate:** the unplayed filter now sticks when set from the top-bar Films/Séries tabs (the exact P9 symptom), matching the Média tab.
- **M5 — tvOS Home / cinematic hero polish (hard).** On upstream's `HomeView.swift`: (a) recreate `CinematicNextUpView.swift` and the Resume→NextUp→RecentlyAdded hero fallback chain; (b) add the empty-state guard (`recentlyAddedViewModel.elements.isNotEmpty`); (c) drop the duplicate global Recently Added row + skip the promoted section from the stacked rows; (d) 10-item hero cap; (e) extract the `ContentView` sub-struct that observes child VMs directly (late-arrival fix). Wire against the new image API (`landscapeImageSources(environment:)`, `environment.useParent`). Re-verify P8.2 backdrop dispatch + P8.3 first-item-in-hero still needed (files `CinematicBackgroundView`/`CinematicItemSelector` — check upstream equivalents). **Skip P8.5** (series-art) unless the sim shows episode stills. **Gate:** home matches the P8 layout on a real account with/without Continue Watching, never blank.
- **M6 — Cross-cutting fixes: verify-then-skip.** Confirm upstream already covers `confirmClose`, `isLiquidGlassEnabled`, `debugBackground` (it does) → **do not re-apply**. Check whether upstream tvOS already has a sheet close button before re-adding `23252324`. Take upstream's `CollectionVGrid` pin. **Gate:** Release build green with none of the obsolete patches.
- **M7 — Parity verification + cutover.** Full sim pass, then deploy to the Apple TV via `Scripts/deploy-appletv.sh` and verify on hardware (login persists, pill filters, unplayed sticks from both entry points, home hero, new player). When v2 matches or beats the P9 build, tag `local-working-<date>-v2`, fast-forward/rename `local/appletv-dev` → v2, keep the old tags as fallback.

## E. Effort & sequencing summary

- **Cheap & safe:** M0 (icon/signing/deploy/docs), M6 (mostly deletions/no-ops).
- **The real cost is M2→M5** — re-authoring the library-filter feature and the home polish against `ItemLibrary` / `ItemLibraryBody` / the generic `PagingLibraryView` and the new image API. Budget these as the bulk of the work; they're feature re-implementations, not merges.
- **Dependency order:** M1 → M2 → (M3, M4) ; M5 independent; do M0 first, M6/M7 last.
- **Rollback:** anytime, `git checkout local-working-2026-07-12-P9`. `local/appletv-dev` stays the shipping branch until M7 cutover.
- **Definition of done:** v2 on fresh upstream reaches feature parity with the P9 build (green icon, keychain filter persistence, tvOS multi-pill filters, unplayed sticks from main-bar + Média, P8 home/hero, new player) — verified on the Apple TV — with zero re-applied obsolete patches.

---

# v2 migration progress log (branch `local/appletv-dev-v2`, started 2026-07-12)

Branch `local/appletv-dev-v2` off `sync/upstream-base` (= `upstream/main` `1dfbb7a1`). Every phase gated on a green tvOS build. **Toolchain note: all builds require `-skipMacroValidation`** (upstream's new `StatefulMacros` package fails `ComputeTargetDependencyGraph` in non-interactive xcodebuild otherwise). Baked into `Scripts/deploy-appletv.sh`.

| Phase | Status | Commit | Notes |
|---|---|---|---|
| Baseline | ✅ | — | Fresh `upstream/main` builds in our toolchain (Debug + Release) with `-skipMacroValidation`. |
| M0 base + local-distinction | ✅ | `17b3aabc` | Green `App Icon Local` brandassets, `CFBundleDisplayName`, entitlements wired (Debug/Release), deploy script (+skipMacroValidation), `.gitignore`, docs. **Personal team id / `.cnaimi` bundle kept in gitignored `DevelopmentTeam.xcconfig`, NOT committed** (cleaner than old branch). `Shared.xcconfig` `#include? DevelopmentTeam.xcconfig` gives `.local` bundle id automatically; only app-icon name + entitlements needed pbxproj patches. Builds, launches, green icon compiled. |
| M1 keychain filters | ✅ | `0bd7e7a9` | **Easier than estimated** — upstream had converged on the same `_StoredValueObservable` design. Added `.keychain` `StorageDestination` + `_keychainKey` + get/set + `KeychainObservable`; `libraryFilters(parentID:)` → `storage: .keychain`. |
| M2 filter feature | ✅ | `62a0fd04` | Upstream `ItemLibrary` only persisted sortBy/sortOrder. Restore + persist the FULL set (genres/letter/tags/traits/years too), unconditional (dropped the `rememberSort` gate — same reasoning as old branch); `itemTypes` deliberately not persisted. Re-added `.isPlayed`/`.isUnplayed` mutual exclusion. Live filtering already worked via the reactive `currentFilters→environment` push. |
| M3 tvOS filter UI | ✅ | `30b0b57f` | Upstream ships **no tvOS filter UI**. New `Swiftfin tvOS/Components/LibraryHeader.swift` (multi-pill capsule drawer, accent tint, reset pill, `NavigationRoute.filter`), mounted via `.safeAreaInset(.top)` in `ItemLibraryBody`'s `#if os(tvOS)` branch + `.toolbar(.hidden)` so the header title is canonical (avoids P5.2 double-title), localized to ItemLibrary. Title+pills (count dropped — no server total exposed). |
| M4 main-bar P9 fix | ✅ | `d42ed301` | Stable `parentID` (`tab-tvshows`/`tab-movies`) threaded through `TabItem.library` → `BaseItemDto(id:name:)`. `type==nil` → `makeBaseItemParameters` default case injects no `parentID`, so aggregate query unchanged; only the persistence key resolves. |
| M5 home/hero | ✅ | `18e51003` | New `CinematicNextUpView` on `PagingLibraryViewModel<NextUpLibrary>` + new image API; `HomeView` `ContentView` sub-struct (late-arrival fix), hero fallback Resume→NextUp→RecentlyAdded (each non-empty gated), no duplicate Recently Added row, 10-item cap. P8.5 series-art NOT re-applied (already upstream). |
| M6 verify-then-skip | ✅ | — (no code) | Confirmed upstream already has: `confirmClose` gate, `isLiquidGlassEnabled` `#available` guard, no unguarded `debugBackground` call sites, tvOS `navigationBarCloseButton`. CollectionVGrid pin already `e5b869c`. **Release build green** with none of the obsolete patches. |
| M7 parity + cutover | ⏳ pending user | — | Needs the Jellyfin server + Apple TV remote (tvOS UI driving is blocked here). Checklist below. |

## M7 — on-device verification checklist (user)

Build/run v2: `git checkout local/appletv-dev-v2` then build the `Swiftfin tvOS` scheme (Xcode, or `xcodebuild … -skipMacroValidation`). Sign in to the server, then verify:

1. **Green icon + "Swiftfin Local"** on the tvOS home screen, coexisting with App Store Swiftfin.
2. **Filter pills** appear on Films / Séries TV (top bar) and on Média → any library: Genres, Lettre, Tri, Étiquettes, Filtres, Années. Each opens its selector.
3. **Unplayed sticks from the main bar** (the original P9 bug): on Films, set Filtres → Non lu; leave the tab and come back → still applied; kill + relaunch → still applied. Same on the Média-tab libraries.
4. **Played/unplayed mutual exclusion**: selecting one clears the other.
5. **Filters survive reinstall** (keychain / M1): set a filter, redeploy/reinstall, relaunch → still applied.
6. **Home**: Continue Watching hero when mid-play; else À suivre (Next Up) hero; per-library "récents" rows; no duplicate global Recently Added; never blank.
7. **New player** opens and plays (upstream #1902, now native upstream).

If all pass: tag `local-working-<date>-v2`, then make v2 the shipping branch (e.g. rename `local/appletv-dev` → `local/appletv-dev-legacy`, `local/appletv-dev-v2` → `local/appletv-dev`), keeping the old tags/branch as fallback. Deploy via `Scripts/deploy-appletv.sh`.

## v2 M7 findings — KNOWN REGRESSIONS to fix before cutover (2026-07-12 on-device)

Deployed v2 to the Apple TV (blue-violet icon, `org.jellyfin.swiftfin.local.cnaimi`). Mostly good, but two tvOS UI regressions vs the P9 build — **do NOT cut over until fixed**:

1. **Top bar missing on some screens.** Almost certainly the M3 change `.toolbar(.hidden, for: .navigationBar)` added to `ItemLibraryBody` (`Shared/Objects/Libraries/ItemLibrary.swift` `#if os(tvOS)`) — it hides the nav bar too broadly (e.g. Média→library screens lose their top bar / context). Fix: hide the title more surgically (e.g. only suppress the doubled `navigationTitle`, or hide the bar only for the main-bar aggregate tabs, not every ItemLibrary), rather than hiding the whole nav bar.
2. **Filter pills overlap the poster grid.** The `.safeAreaInset(edge: .top) { LibraryHeader }` mount in `ItemLibraryBody` isn't reserving space against the shared `PagingLibraryView`'s `CollectionVGrid` on tvOS — posters render under the pills. Fix: reserve top space for the header (the shared `PagingLibraryView`/`CollectionVGrid` likely ignores the safe-area inset on tvOS; may need a top content-inset/padding on the grid instead of `safeAreaInset`, mirroring how the old tvOS `PagingLibraryView` did it).

Both are M3 (filter-UI mount) layout issues — exactly the visual-iteration work M3 was flagged to need. The v2 branch is otherwise sound (M0–M6 build green). **Decision (2026-07-12): pause v2, keep `local/appletv-dev` (P9) as the shipping build, carry only the new blue-violet icon back to it.** Resume v2 by fixing #1 and #2 above, then re-run the M7 checklist.

---

# Session 2026-07-31 — v2 synced to upstream/main, M7 blockers fixed, deployed

> v2 is now **11 commits ahead of `upstream/main`, 0 behind**, deployed to the Apple TV. Restore point before this work: tag **`local-v2-pre-sync-2026-07-31`**.

## A. Sync target: `upstream/main`, not tag `1.5`

v2's base `1dfbb7a1` sat **one real commit before `1.5`** — and that commit is `7891e273 Content Groups (#2075)`, which deletes the whole `Swiftfin tvOS/Views/HomeView/` folder plus `PosterButton`/`PosterHStack`/`SearchView`/the ItemView scroll views, moving them into `Shared/` behind a `ContentGroup` abstraction. That is exactly what had invalidated M5.

`git merge-tree` showed **the same 3 conflicts for `1.5` and for `upstream/main`**, so `main` cost nothing extra and additionally brought PR **#2096** (`250166f0`), whose `AlternateLayoutView` + `IsSafeAreaBarApplied` grid-inset machinery is what the tvOS filter drawer needed. Decision: target `main`.

Conflicts resolved in `8a49f330`:

| File | Resolution |
|---|---|
| `Shared/Objects/Libraries/ItemLibrary.swift` | upstream's tvOS branch; M2 full-filter persistence preserved; M3's header mount + broad `toolbar(.hidden)` dropped |
| `Shared/Coordinators/Tabs/MainTabView.swift` | upstream's `defaultTabCoordinator` (`TabItem.contentGroup` replaces `TabItem.home`) + M4 args re-applied |
| `Swiftfin tvOS/Views/HomeView/HomeView.swift` | **accepted upstream's deletion**, folder removed incl. our `CinematicNextUpView.swift` |

M1 (keychain filters) and M2 (played/unplayed exclusion) auto-merged untouched. Local-distinction layer is conflict-free.

**Now redundant — do not re-apply:** the never-blank hero, Recently-Added row de-dup, late-arrival re-render, and series-art-first landscape images are all upstream behavior now (`_shouldBeResolved` / `hasContent`). P8.1/P8.4/P8.5 are obsolete as code; only the hero *ordering* intent survived.

## B. Both M7 blockers fixed — the real root causes

1. **Top bar missing (blocker #1).** The 2026-07-12 diagnosis was right: M3's `.toolbar(.hidden, for: .navigationBar)` on `ItemLibraryBody`. Removed. **Upstream already hides the nav bar surgically per aggregate tab** in `TabItem.library` (`.if(UIDevice.isTV)`), so nothing needed replacing — `LibraryHeader` simply stopped drawing its own title, leaving `PagingLibraryView`'s `navigationTitle` as the single source.
2. **Pills overlapping the grid (blocker #2).** `.safeAreaInset` could *never* have worked: `PagingLibraryView`'s `CollectionVGrid` sets `.ignoresSafeArea(edges: .vertical)`. Two parts:
   - mount via `.safeAreaBar` + publish `IsSafeAreaBarApplied` (upstream's own iOS mechanism), and
   - **`LibraryElement.layout(for:options:insets:)` discarded the insets on tvOS** — `insets: .init(vertical: 0, …)` hardcoded, because #2096 only wired iOS. That was the actual blocker; the preference alone did nothing.

## C. Regression caught during the sync — M4 would have emptied the Movies/TV tabs

M4 gave the synthetic tab parent `BaseItemDto(id: "tab-movies")`, on the premise that a type-less parent hits `setParentParameters`' default case *without* injecting a `parentID` scope. Upstream's replacement `ItemLibrary.makeBaseItemParameters` does the **opposite**: its `switch` default case sets `parameters.parentID = parentID`. Shipping M4 as written would have sent `parentID=tab-movies` and returned nothing.

Fix: the key travels as a dedicated **`ItemLibrary.persistenceID`** (defaults to `parent.id`) that never reaches a request — same separation upstream uses for library style via `LibraryParent.pagingLibraryID`. Kept opt-in rather than globally falling back to `displayTitle`: an unconditional fallback would start restoring stored sort onto preset-sorted libraries such as the iOS Recently Added group, whose `sortBy: [.dateCreated]` would be clobbered by the stored default of `.sortName`.

Also fixed: the **Reset pill was permanently visible and destructive** on the aggregate tabs. Their `currentFilters` always differs from `.default` because it carries the structural `itemTypes: [.movie]` preset, and `reset(filterType: nil)` assigns `.default` wholesale — so tapping Reset dropped the type scoping and turned the Movies tab into an everything-tab. `hasActiveFilters` and `reset()` now both exclude `itemTypes`/`query`. **Upstream's iOS drawer has the same bug** → upstream PR candidate.

## D. Home + drawer per user review (on-device)

- **Hero shows À suivre.** Upstream falls back Continue Watching → Recently Added, so an account with nothing mid-play opens on an untitled unsorted strip. `CinematicSelectionContentGroupViewModel` now owns a `NextUpLibrary` and exposes `heroSource` (`resume`/`nextUp`/`recentlyAdded`/`none`); Recently Added stays the last resort so the hero is never empty. New `CinematicNextUpContentGroup` renders the À suivre *row* only when Next Up isn't in the hero, and `CinematicRecentlyAddedContentGroup` keys off `heroSource` the same way. iOS untouched. This is P8.4's intent in ~40 lines instead of a HomeView rewrite.
- **Filter drawer is one segmented bar** (`b5c6bc64`), aligned to the grid. Alignment needed both `ignoresSafeArea(edges: .horizontal)` and `edgePadding`: as `safeAreaBar` content the drawer inherits the tvOS ~80pt overscan safe area while the grid ignores it and insets a flat 60, so they could not otherwise line up.
- **Hero labels: reverted** (`73bb7cd7`). Dropping the episode name left "Series / SxEx", less informative than the 1.x hero it aimed to match. Upstream's `SxEx • title` (truncated) is what we keep.
- `.category` is a new upstream `ItemFilterType` (Live TV) and the default drawer set is `allCases`, so a "Catégorie" segment shows on every library. Uncheck under Réglages → Filtres → Bibliothèque if unwanted.

## E. KNOWN UNFIXED — upstream tvOS ItemView opens scrolled past its header

**Symptom:** open an item from a poster row; the page appears at the top, then ~0.4 s later scrolls down and focus sits on the Saison row instead of the Lire button. Push Up to recover.

**Not ours** — `git log --name-only` over our whole range touches no `ItemView` / `ContentGroupVStack` / `ContentGroupScrollView` file, and the user confirmed the scroll predates our changes. **Upstream knows:** `Shared/Views/ItemView/Components/Headers/RegularSimpleHeaderContentGroup.swift:12` says `// TODO: Fix the header's initial focus.`

**Instrumented trace** (NSLog on focus transitions, since scripted key events to the Simulator are blocked by macOS Accessibility, `osascript` error 1002):

```
appear:  isEnhanced=false groups=["itemView-header", "<season-uuid>", "cast-and-crew", "about"]
focus:   nil -> <season-uuid>        (+391 ms)
```

`focusedGroupID` **never becomes `itemView-header`** — the outer `defaultFocus` never takes effect; focus just resolves to whatever the engine picks.

**Hypotheses tested and DISPROVEN — all reverted, do not retry:**

1. *Header type swap.* `contentSize` starts `.zero` → `isCompact` true → `CompactSimpleHeader`, then flips to `RegularSimpleHeader` after `defaultFocus` resolved. The swap is **real** (observed: `isCompact: true -> false` firing *after* `appear`), but filling the ZStack before measuring — `.frame(maxWidth: .infinity, maxHeight: .infinity)` ahead of `.trackingSize` — changed nothing user-visible.
2. *Play button not focusable.* `.disabled(provider.mediaPlayerItemProvider == nil)` in `PlayButton` — nil until the playback-info request returns, which matches the 391 ms almost exactly, and disabled views are not focusable on tvOS. Removing it under `#if !os(tvOS)` did not help.
3. *Wrong focus API.* Replaced the cross-platform `defaultFocus` with the tvOS-native pairing: `@Namespace` + `.focusScope(_:)` on the group VStack, namespace published through a new `\.itemViewFocusNamespace` environment value, and `.prefersDefaultFocus(true, in:)` on the header's play button. Builds and runs; **behaviour unchanged.**
4. *AnyView identity erasure.* `ContentGroupVStack` attaches `.focused(binding, equals:)` after `.eraseToAnyView()`, so the theory was that AnyView hides the structural identity `defaultFocus` needs. **Ruled out on compilation grounds:** the group is an opened existential (`some ContentGroup` over `[any ContentGroup]`), so it *must* be erased before any modifier is attached — reordering fails with `type 'any View' cannot conform to 'View'`. Upstream has no choice here.

**Still untested:** the two nested `.userInitiated` `defaultFocus` declarations (outer on the VStack targeting `itemView-header`, inner in the header targeting `isPlayButtonFocused`) cancelling each other out. Worth trying by removing one.

**Decision: not fixed (2026-07-31).** Four hypotheses down, and the remaining honest options are force-asserting focus on a timer inside `Shared/` — a divergence that makes every future sync worse — for a bug upstream has already flagged with a TODO. **Report it to jellyfin/Swiftfin with the trace and the disproven list above**, which is considerably more than their TODO has today.

## F. Deploy + tooling notes

- **`Scripts/deploy-appletv.sh` is unaffected** — it already passes `-skipMacroValidation` and uses its own `SwiftfinDeploy` DerivedData. The weekly Shortcut keeps working. Deployed 2026-07-31; profile valid until **vendredi 07 août 20:44**.
- **CLI builds now need `-skipMacroValidation`.** Xcode 26.3 requires re-approval of the `swift-case-paths` and `StatefulMacro` macro packages; without the flag `xcodebuild` fails at `ComputeTargetDependencyGraph`, which looks like a code error but is not.
- **Simulator gotcha that cost real time:** the build's bundle id is **`org.jellyfin.swiftfin.local.cnaimi`** (from the gitignored `DevelopmentTeam.xcconfig`), not `org.jellyfin.swiftfin.local`. Installing the new build while launching the *old* id silently ran a months-old app — both commands report success. **Always resolve the id from the built `Info.plist` and md5-compare installed vs built binary before trusting a visual test.**

## G. Verified on the simulator / device

✅ pills above the grid on main-bar tabs and Média→library · ✅ top bar retained · ✅ glass row-title buttons focus + route · ✅ tvOS 26 sidebar · ✅ hero = À suivre, "Ajoutés récemment" below · ✅ unplayed filter applies, Reset appears only when active · ✅ Release build green · ✅ deployed to Apple TV

⚠️ **Still unverified:** filter persistence across app relaunch, and the cinematic focused-poster blur (suspect the new `.tabViewStyle(.sidebarAdaptable)` from #2107 paints over `MainTabView`'s `.background`).

## H. Next iteration — pick-up checklist

**State at pause (2026-07-31 evening).** Branch `local/appletv-dev-v2`, tree clean, **11 ahead / 0 behind `upstream/main`**, everything pushed to `origin`. Deployed to the Apple TV; free-provisioning profile expires **vendredi 07 août ~21:22** — re-run `Scripts/deploy-appletv.sh` (or the "Swiftfin.local update" Shortcut) before then or the app dies.

Restore points: tag `local-v2-pre-sync-2026-07-31` (v2 before this sync), plus the older `local-working-2026-07-12-P8/-P9/-P9-icon`. `local/appletv-dev` (P9) is still the untouched legacy shipping branch.

Commits this session:

```
ff2d6a74 docs: two more disproven hypotheses for the ItemView focus bug
00e46f24 docs: record the sync, M7 fixes, unfixed focus bug
73bb7cd7 Revert "drop episode names from cinematic hero labels"
b5c6bc64 feat(tvOS): filter drawer as one segmented bar, aligned to the grid
e8f9fcd7 feat(tvOS): drop episode names from cinematic hero labels
2c06b922 fix(tvOS): reserve grid space for the drawer; promote Next Up to hero
78105d26 fix(tvOS): remount drawer as safeAreaBar; persistenceID
8a49f330 Merge upstream/main into local/appletv-dev-v2
```

### 1. Verify on hardware (was not reachable from the sim)

- [ ] **Filter persistence across a full app relaunch.** Set *Non lu* on Séries TV, quit, relaunch. Two independent paths must both hold: the main-bar tabs (keyed by `ItemLibrary.persistenceID` = `"tab-tvshows"`/`"tab-movies"`) and a real Média→library (keyed by `parent.id`). M1's keychain backing means it should even survive a reinstall.
- [ ] **Cinematic focused-poster blur.** Confirm `Réglages → Personnaliser → "Arrière-plan cinématographique"` is on, then focus posters on Accueil and inside a library. Leading suspect if still dead: `.tabViewStyle(.sidebarAdaptable)` (new in `main` via #2107) painting over `MainTabView`'s `.background { FocusedPosterCinematicBackgroundView() }`. If confirmed, move that background inside the tab content instead of behind the TabView.
- [ ] New player, sign-in persistence, no crashes.

### 2. Then cut v2 over to be the shipping branch

Once the above pass: tag `local-working-<date>-v2`, rename `local/appletv-dev` → `local/appletv-dev-legacy`, rename v2 → `local/appletv-dev`, keep old tags as fallback. Update `Scripts/deploy-appletv.sh` only if the branch name is referenced (it is not today).

### 3. Upstream PR candidates — genuinely ours, genuinely upstream bugs

- **tvOS grid insets ignored.** `LibraryElement.layout(for:options:insets:)` hardcodes `insets: .init(vertical: 0, …)` on tvOS, silently discarding the caller's insets that #2096 threaded through for iOS. Any tvOS `safeAreaBar` over a `PagingLibraryView` is unusable without this.
- **Reset wipes structural `itemTypes`.** `NavigationBarFilterDrawer` calls `reset(filterType: nil)`, which assigns `.default` wholesale — on an aggregate tab carrying `itemTypes: [.movie]` that turns it into an everything-tab, and the Reset button is permanently visible there because `currentFilters != .default` always holds. Fix as done in `LibraryHeader`: exclude `itemTypes`/`query` from both the visibility test and the reset.
- **`ItemView` initial focus** — report with the trace and the four disproven hypotheses in §E rather than a patch.
- **`makeBaseItemParameters` sends a synthetic `parentID`** — arguably intended, but worth raising: its `switch` default case forwards any non-nil `parent.id`, so a parent that exists only client-side cannot carry an id. `persistenceID` is our workaround.

### 4. Still ours, still divergent — re-check on every sync

`ItemLibrary.persistenceID` · full-filter persistence + keychain `StoredValues` (M1/M2) · played/unplayed mutual exclusion · `LibraryHeader` segmented drawer + its mount in `ItemLibraryBody` · tvOS grid insets · `heroSource` / `CinematicNextUpContentGroup` · local-distinction layer (icon, display name, entitlements, deploy script).

# Session 2026-08-01 — hardware review: playback start, gray play button, focus bug (2 more disproven), filter bar rejected

> Review-only session on the deployed v2 build. **No code committed.** Two focus-bug fixes were written, built, tested and reverted; the working tree is clean at `3fcbf7cf`. Decision at the end of the session: **rebuild a clean branch carrying only the filter pills + the home rework** (see §E).

## A. Playback start is genuinely slow on hardware — root cause found, not ours

Symptom (user, on the Apple TV): several seconds of black screen and no audio after pressing **Lire**. Not an impression.

Pressing Lire runs four things **strictly serially** before a single video byte is requested:

| Step | Where | Cost on device |
|---|---|---|
| `GET /Items/{id}` full item refetch | `BaseItemDto.swift:613` via `MediaPlayerItem+Build.swift:44` | 1 RTT, and redundant — the item page just fetched it |
| **Bitrate test: 5 MB download** | `MediaPlayerManager.swift:452`, `PlaybackBitrateTestSize.regular = 5_000_000` | ~1–4 s over Wi-Fi |
| `POST /Items/{id}/PlaybackInfo` | `MediaPlayerItem+Build.swift:92` | 1 RTT + server probe |
| VLC opens the URL and buffers | — | plus ffmpeg startup **if transcoding** |

The bitrate test only runs when max bitrate is `.auto`, which **is the default** (`SwiftfinDefaults.swift:345`). Its second-order cost is worse than the download: the measured value is written into the device profile as `maxStaticBitrate`/`maxStreamingBitrate` (`DeviceProfile.swift:70-73`) and sent as `playbackInfo.maxStreamingBitrate`. **A mediocre Wi-Fi measurement can flip a high-bitrate file from DirectPlay to transcode** — which is where the multi-second delay and the missing audio actually come from.

Why the simulator never showed it: the Mac's link to M1Center swallows 5 MB in ~50 ms and measures high, so it direct-plays.

Also: **there is no loading indicator for `.loadingItem`.** Nothing in `VideoPlayerContainerView` renders for that state — only `PlaybackProgress` greys out. The user stares at pure black. Cheap local improvement if wanted.

**Levers, no code:** Réglages → *Qualité de lecture* → *Débit maximum*: **Automatique → Maximum** skips the test entirely (guard at `MediaPlayerManager.swift:445`) and stops advertising a low ceiling. Or keep Auto and set *Test de bitrate → Taille du test* to smallest (1 MB). Then check the player's playback-information supplement for DirectPlay vs Transcode.

**Latent wart worth noting:** `VideoPlayer.appMaximumBitrate` (`:240`, default `.max`) and `VideoPlayer.Playback.appMaximumBitrate` (`:344`, default `.auto`) declare the **same** `UserKey` string `"appMaximumBitrate"` with **different defaults**. Same for `appMaximumBitrateTest`. `getMaxBitrate`'s default argument reads the former, everything else the latter. Benign today (same stored key) but a trap.

## B. Gray play button on hardware — narrowed to the glass tint, `disabled` ruled out

`PlayButton.swift:146-151` is the **only** surface on tvOS that pushes `accentColor` through `glassEffect(tint:)`. Every purple thing still visible (unplayed corner triangles, checkboxes, poster indicators, active filter segment) is a plain `.fill(accentColor)`. Other glass tints in the app are white or `.gray.opacity(0.3)`. So "purple everywhere except Lire" is precisely the signature of the glass-tint path failing — the accent color itself is fine (confirmed on the simulator screenshot: purple unplayed triangles).

Two mechanisms can grey that button:

1. **Disabled → `subduedColor` = `.gray.opacity(0.3)`** (`GlassEffect.swift:77,116`) via `.disabled(provider.mediaPlayerItemProvider == nil)` (`PlayButton.swift:167`).
2. **Device glass rendering** differing from the simulator.

**(1) is ruled out, and this corrects §E hypothesis 2.** `ItemContentGroupProvider.makeGroups` assigns `mediaPlayerItemProvider` at `:54` — *before* returning groups — and `ContentGroupViewModel.fullRefresh` only publishes `groups` and flips state to `.content` after `makeGroups` returns. So the header never renders with a nil provider on a playable item. There is **no pending playback-info request at item-page load**; `getPlaybackItemProvider` is synchronous. §E H2's premise ("nil until the playback-info request returns, which matches the 391 ms almost exactly") was factually wrong — that 391 ms was never the play button resolving.

**Still to check on the device (not reachable from the sim, where it renders purple):**
- [ ] **Réglages → Général → Accessibilité → Augmenter le contraste / Réduire la transparence.** Either flattens tvOS glass to an opaque material and would kill a glass tint while leaving plain accent fills purple — matches the symptom exactly. Leading suspect.
- [ ] Can the button be focused and pressed, and is it purple **when focused**? If it focuses and plays, it is not disabled → rendering, and the fix is a real `Capsule().fill(accentColor)` behind the glass (small `Shared/` divergence) + an upstream report.

## C. ItemView focus bug — two more hypotheses DISPROVEN (5 and 6), plus the key discriminating observation

**The observation that reframes everything (user, this session): the bug is series-only. Movies focus Lire correctly; TV shows focus the Saison row.**

Movies do not get a `SeriesEpisodeContentGroup`; series and seasons do. So the cause lives in that group, **not** in the header — which retires the *rationale* behind H1–H4, all of which worked on the header or the play button. It also matches the §E trace: `focusedGroupID` resolved to `<season-uuid>`, i.e. the `SeriesEpisodeContentGroup`, never to `itemView-header`.

On a series page there are **four** `.userInitiated` default-focus claims below the header's one, and `DefaultFocusEvaluationPriority` has only `.automatic` and `.userInitiated` — so the header (already `.userInitiated`) **cannot outrank them**:

| File | Claim |
|---|---|
| `SeriesEpisodeContentGroup+SeasonSelector.swift:66` | `$focusedSeason → preferredSelection` |
| `SeriesEpisodeContentGroup+EpisodeCollection.swift:194` | `$focusedElement → preferredElementID` |
| `SeriesEpisodeContentGroup+EpisodeCollection.swift:206` | `$focusedSection → .episodes` |
| `SeriesEpisodeContentGroup+EpisodeCard.swift:201` | `$focusedElement → .artwork` |

**5. *First-pass compact header remount.* DISPROVEN — reverted.** `ItemView.contentSize` starts `.zero`, so `isCompact = contentSize.width < 600` is true on the first layout pass: a Compact header is built, then swapped for the Regular one once measured. All four headers share `id: "itemView-header"` and `ContentGroupVStack` erases to `AnyView`, so the swap tears down the header subtree with its `@FocusState` and its `defaultFocus` after focus has already resolved — and `defaultFocus` is never re-evaluated. For *enhanced* items it looked even better: the first scroll view mounted is `BlurredNavigationBarScrollView`, which passes no `focusedGroupID` and declares **no `defaultFocus` at all** (`:35`). Tried `isCompact` returning `false` under `#if os(tvOS)` (the window is always full-screen there; matches upstream's own `// TODO: isCompact determination by available width`). Built, installed md5-verified, tested: **movies fine, series unchanged.** Killed by the series/movie split — movies go through the identical header swap and were already correct.

**6. *Demote the episode group's competing claims.* DISPROVEN — reverted.** Lowered `SeasonSelector:66`, `EpisodeCollection:194` and `EpisodeCollection:206` from `.userInitiated` to `.automatic`, on the theory that `.automatic` still decides focus *within* its own scope once entered but stops competing in the page-level initial resolution. Left `EpisodeCard:201` alone (per-cell, cannot compete at page level). Built, installed md5-verified, tested: **series unchanged.** So priority is **not** the lever — the sibling group wins regardless of tier, presumably by scope/geometry order rather than by `DefaultFocusEvaluationPriority`.

**Where this leaves it.** The *mechanism* (a sibling content group taking the initial focus that the header claims) is now strongly indicated by the series/movie split, but neither available lever moves it. Six hypotheses down. Remaining untried options are all worse than the bug: removing those declarations outright (breaks season/episode landing behavior when focus legitimately enters the row), or force-asserting `focusedGroupID = "itemView-header"` on first appear — divergence inside `Shared/` that makes every future sync worse, for a bug upstream has flagged with `// TODO: Fix the header's initial focus.`

**Decision unchanged: do not fix locally. Report upstream** with the trace, the series/movie split, the four competing claims, and all six disproven hypotheses. That is a far better report than upstream's TODO, and the split is the part they most likely don't know.

## D. Filter bar — segmented design rejected, plus a reactivity bug

User verdict on hardware: the single-glass-capsule segmented bar (`b5c6bc64`) is **not good**, and **choosing a filter does not visibly change the bar**.

The reactivity complaint is not explained by the code as read: `FilterViewModel.currentFilters` is `@Published` (`FilterViewModel.swift:41`), `LibraryHeader` holds the view model as `@ObservedObject`, `router.route(to: .filter(type:viewModel:))` hands the selector **the same instance**, and both `isActive:` (`isFilterSelected(type:)`) and `pillTitle(for:)` read `currentFilters`. So this needs a **repro before a fix** — and note that reverting the visual design does **not** necessarily fix it, since the pill version read exactly the same state the same way. One structural suspect to check first: the drawer is `safeAreaBar` content, so if `ItemLibrary` (a struct owning `filterViewModel`) is recreated on filter change, the bar could end up observing a different instance than the one being mutated.

## E. Decision — rebuild a clean branch: filter pills + home rework only

The user's call at the end of this session: drop the segmented bar, keep the multi-pill drawer, and reduce the branch to **only the filter pills addition and the homepage rework**. Plan to be validated before execution — see the next session's section.

# Session 2026-08-01 (part 2) — clean rebuild as `local/appletv-dev-v3`

Per the user's decision in §E above: drop the segmented filter bar, keep the pills, and reduce the branch to the filter feature + the home rework. Rebuilt from scratch on `upstream/main` so the history is eight focused, reviewable commits instead of a merge plus fix-ups.

**Restore points:** tag `local-v2-2026-08-01` (v2 as deployed + the review docs). Branches `local/appletv-dev-v2` and `local/appletv-dev` (P9 legacy) untouched.

## Why a v3 branch at all (asked 2026-08-01)

The change the user actually asked for was one file — revert the segmented drawer, keep its alignment fix. A new branch was **not** required for that; the same result was reachable on v2 with two commits. v3 exists because "a clean version with only the pills and the home rework" was read as a clean *history*: 9 focused commits off `upstream/main` instead of v2's 20, which carry the upstream merge, the hero-labels experiment and its revert, and the paused-M7 notes. The real payoff is extracting the three upstream PR candidates later.

**`local/appletv-dev-v2` is NOT dead.** It is intact, tagged `local-v2-2026-08-01`, and is the build currently running on the Apple TV until v3 is deployed. Options B (collapse onto v2) and C (move the v2 pointer to v3's commit) were offered; the user chose **A — keep v3 as the working branch, v2 retained as the fallback**. So three branches are in play on purpose:

| Branch | Role |
|---|---|
| `local/appletv-dev-v3` | **working / shipping candidate** |
| `local/appletv-dev-v2` | fallback; what is deployed today |
| `local/appletv-dev` | P9 legacy fallback, untouched since 2026-07-12 |

## Branch contents (8 commits off `upstream/main`)

| Commit | What |
|---|---|
| `chore(local)` | Distinction layer: display name, blue-violet icon, keychain entitlements for **Debug and Release**, deploy script, gitignore |
| `fix(tvOS)` grid insets | `LibraryElement` honors the caller's insets — prerequisite for the drawer. **Upstream PR candidate** |
| `feat(tvOS)` pill drawer | `LibraryHeader` pills + `safeAreaBar` mount + `IsSafeAreaBarApplied`; Reset/`itemTypes` fixes are **upstream PR candidates** |
| `feat(tvOS)` persistence | Keychain `StoredValues` destination, full filter set, `ItemLibrary.persistenceID` |
| `feat` played/unplayed | Mutually exclusive traits |
| `feat(tvOS)` home hero | `heroSource` + `CinematicNextUpContentGroup` |
| `docs` | Tracking docs carried forward |
| `style` | SwiftFormat `redundantSendable` — see below |

**Verification that the rebuild lost nothing:** `git diff local-v2-2026-08-01 HEAD` touches **exactly one file**, `LibraryHeader.swift` (pill vs segmented). Everything else is byte-identical to the deployed v2. Debug and Release both build green.

## The filter bar design decision

The segmented single-glass-capsule bar (`b5c6bc64`) is dropped; the multi-pill drawer is restored. **The alignment fix from that same commit is kept** — the user called it mandatory. Reverting `b5c6bc64` wholesale would have re-broken alignment, since it bundled both changes. The pill version keeps `.padding(.vertical, 20)` rather than the segmented bar's 16: pills scale to 1.08 on focus and need the extra room, whereas segments filled in place.

## KNOWN ISSUE, deliberately not fixed — the drawer does not visibly update when a filter is chosen

Reported on hardware. **Left as-is by decision**, recorded here rather than chased. The code as read does not explain it: `FilterViewModel.currentFilters` is `@Published`, `LibraryHeader` observes the view model, `router.route(to: .filter(type:viewModel:))` hands the selector the same instance, and both `isActive:` and `pillTitle(for:)` read `currentFilters`.

Important: **this is not a property of the segmented design.** The pill version reads the same state the same way, so restoring the pills will not fix it. First suspect to check when it is picked up: the drawer is `safeAreaBar` content, and `ItemLibrary` is a struct that *owns* its `filterViewModel` — if the library value is recreated on a filter change, the drawer may end up observing a different instance than the sheet mutates. Needs a live repro before any fix.

## SwiftFormat version drift — worth deciding on

`ScrollEdgeEffectStyle.swift` losing its explicit `Sendable` was **not** a hand edit or a merge artifact (an earlier note in this doc called it one — corrected here). The project's `Run SwiftFormat` build phase runs `swiftformat .` over the entire repo on every build, and the installed SwiftFormat is **0.61.1** while `.swiftformat` declares **0.59.1**. The `redundantSendable` rule is new in 0.61, so the file is rewritten on every build regardless of what anyone touches — which is how it silently entered v2.

Currently 1 file of 733. It will recur after every upstream sync on any file upstream writes with an explicit `Sendable` on a non-public type. **Pinning SwiftFormat to 0.59.1 would remove the drift and match upstream CI** — recommended eventually, not done here to avoid changing the toolchain as a side effect of a feature branch.

## Release-mode deployment (confirmed)

`Scripts/deploy-appletv.sh:25` sets `CONFIG="Release"` and installs from `Release-appletvos`, so **the Apple TV has always received a Release build** — no change needed. The Debug builds in this session only ever went to the simulator. The Release configuration is also why the distinction layer must carry `Swiftfin tvOSRelease.entitlements`: without that keychain group the filter persistence would fail at runtime on the deployed build specifically.

## Still open

- [ ] Deploy v3 to the Apple TV (Release) and verify: pills render + align, filter persistence across relaunch, home hero, no crashes.
- [ ] Gray play button — the two device checks in §B above (accessibility contrast/transparency settings; whether the button focuses and plays).
- [ ] Playback start — try *Débit maximum: Maximum* and compare.
- [ ] Cutover: tag `local-working-<date>-v3`, then make v3 the shipping branch.
- [ ] Report the `ItemView` focus bug upstream (series-only, four competing claims, six disproven hypotheses).
- [ ] Nothing pushed to `origin` yet — v3 and the new tag are local-only.

# Session 2026-08-02 — v3 wiped; v4 = tag `1.5` + only the three wanted changes

## Why v3 died

User verdict on v3: the show page opens with a different layout (Play/Like buttons top-left instead of 1.5's big hero with a large play button at the bottom), the play button loses its accent color, the Settings comboboxes render differently, and initial focus does not land on the play button. **None of that was our code.** v3 was rebuilt on `upstream/main`, which since `1.5` redesigned the tvOS ItemView (ContentGroups header + `SeriesEpisodeContentGroup` focus claims), pushed `accentColor` through `glassEffect(tint:)` on the play button, and introduced the sidebar/new settings chrome. The App Store 1.5 build shows the correct behavior — so the base, not the branch, was the problem. Decision: **start from tag `1.5` and apply only the wanted features.**

- v3 archived as tag **`local-v3-archive-2026-08-02`**, branch deleted (was never pushed).
- `local/appletv-dev-v2` (deployed on the TV) and `local/appletv-dev` (P9) untouched as fallbacks.

## `local/appletv-dev-v4` contents (7 commits on tag `1.5`)

| Commit | What | Origin |
|---|---|---|
| `chore(local)` distinction layer | Name, blue-violet icon, Debug+Release keychain entitlements, deploy script, gitignore | cherry-pick `9addc390` |
| `fix(local)` Debug access group | Keychain access group = bundle id | cherry-pick `0400265a` |
| `feat` #2096 inset slice | Backport of upstream's `IsSafeAreaBarApplied`/insets threading (post-1.5), **plus** our tvOS honor-the-insets fix. 1.5's CollectionVGrid pin already has the `insets:` overloads | hand-port + `d0e6cd93` |
| `feat(tvOS)` pill drawer | `LibraryHeader` pills, `safeAreaBar` mount — all APIs it uses (`isFilterSelected`, `NavigationRoute.filter`) already exist at 1.5 | cherry-pick `ec0d6d14` |
| `feat(tvOS)` keychain persistence | `KeychainObservable`, full filter set, `persistenceID`, stable `tab-movies`/`tab-tvshows` ids | cherry-pick `dee5ebb2` |
| `feat` played/unplayed exclusion | Mutually exclusive traits | cherry-pick `999c051e` |
| `feat(tvOS)` home row removal | Global "Ajoutés récemment" row dropped on tvOS; home = hero → À suivre → per-library rows | new, minimal |

**Hero rework ported after all (9th commit).** It was first left out to keep the change minimal, but on the sim the user immediately flagged "the first row is still recently added" — that was 1.5's stock hero showing the Recently Added strip because nothing was mid-play. With the user's OK, `86b92495` (hero prefers À suivre, `CinematicNextUpContentGroup` row skipped when promoted) was cherry-picked; git followed the file's post-1.5 folder move on its own and the unrelated `parentLogoImageTag` drift (#2104) stayed out. Verified on the sim: hero = Only Murders backdrop + logo, strip = Next Up with series art + SxEx, next titled row = per-library.

Since v4's base predates upstream's ItemView/play-button/settings redesigns, the show page layout, play-button color, and initial focus are 1.5-stock by construction — the exact properties the user wanted back.

## Carried-over known issues that still apply on v4

- The drawer-doesn't-visibly-update issue (see 2026-08-01 §D) — the pill code reads the same `@Published` state, so if it reproduced on v3 it can reproduce here. Needs a live repro.
- SwiftFormat 0.61.1 vs declared 0.59.1 (`redundantSendable`) — check what the build phase rewrites on the 1.5 tree; absorb as a `style:` commit or pin 0.59.1.
- Playback-start slowness + no `.loadingItem` indicator: that analysis was against post-1.5 player code; 1.5's player differs. Re-evaluate only if the symptom is seen on v4.

## "Only Murders in the Building" missing poster in the À suivre row — root cause (2026-08-02)

Not our bug, and mostly a server data gap. The À suivre **row** is `PosterGroup(library: NextUpLibrary())` whose default is `posterDisplayType: .portrait`, and at 1.5 `BaseItemDto.portraitImageSources` for an **episode** requests exactly one image: the **season's primary poster** (`imageSource(itemID: seasonID, .primary)`) — no fallback whatsoever (`BaseItemDto+Poster.swift:91`). So the card is empty iff that season has no poster in Jellyfin — typical for a freshly-added currently-airing season (here: S5), while older seasons in the row all have one. The cinematic hero/strip is unaffected because the landscape/cinematic chain falls back series-thumb → series-backdrop → episode-still, which is why the same show renders fine as the hero.

Fix on the server: series → Season 5 → Images → add/download a primary image (or metadata-refresh that season with image download on). Optional local one-liner (upstream candidate): append `imageSource(itemID: seriesID, .primary, …)` as a fallback in the episode branch of `portraitImageSources`. Not applied — awaiting user's call.

---

# Session 2026-08-08 — the drawer leaves the safe area bar and becomes scrolling content

**User report (on the TV):** (1) the pills *float* — scrolling down slides posters across them up to the top of the screen; the ask, clarified in the second round, is that they "stay on top of the 1st row so if you scroll down the pills disappear as the main menu bar"; (2) Up from the poster grid never gets back to the pills — it lands on the main menu bar instead.

## Why a mounted bar could not deliver either

The drawer was `safeAreaBar` content, i.e. a sibling of the grid, and the grid is a `CollectionVGrid` (UIKit collection view) with `.ignoresSafeArea(edges: .vertical)`. Two consequences:

- **It cannot scroll away.** The bar is outside the scroll view by construction. Reserved space was a flow-layout `sectionInset.top`, and collapsing that on scroll is not an option either: `UICollectionVGrid.update` calls `snapshotReload()` on *any* layout change, so every collapse would crossfade the whole grid.
- **It cannot win the Up press.** Leaving the collection upwards is a focus-*group* exit, and UIKit tab bars are a prioritized focus group — they take those exits. A sibling drawer with its own `.focusSection()` is never preferred over the tab bar.

A first attempt (pin the grid below the bar by honoring the top safe area, `local` commit not kept) fixed the overlap and nothing else — the user confirmed Up still went to the menu bar. That is the observation that ruled out geometry and pointed at group priority.

## What shipped — tvOS browses with a native `ScrollView`

`PagingLibraryView` now has two element paths. iOS keeps upstream's `CollectionVGrid` verbatim (`collectionElementsView`, insets and all). tvOS uses `scrollingElementsView`: a `ScrollView` over a `VStack` of **drawer + `LazyVGrid`**, so the pills are the first row of the scrolling content. They scroll away with the posters like the menu bar, and Up from the first poster row is now movement *inside one scroll view*, which never reaches the tab-bar hand-off.

Details worth keeping:

- **Columns mirror the old layout exactly** — `gridColumnCount` reproduces the tvOS branch of `LibraryElement.layout`: 4 landscape, 7 otherwise, `listColumnCount` for list style, `edgePadding` for item and line spacing. Verified on the sim: pill leading edge and first poster leading edge both land on x=120px @2x = 60pt.
- **Paging replaces `onReachedBottomEdge`** with `elementDidAppear`, which fires two rows out and is guarded on `background.is(.gettingNextPage)`.
- **`VStack`, not `LazyVStack`**, around the grid: the grid stays lazy, but the drawer is always materialized, so it is always focusable.
- **The drawer is a view, not a property** (`LibraryFilterDrawer` in `LibraryHeader.swift`). It reads `\.libraryFilterViewModel`, injected by `ItemLibraryBody`. Declaring that `@Environment` on `PagingLibraryView` itself silently yields nil — the injection sits *between* `PagingLibraryView` and its content, so the property wrapper resolves against the parent environment. That bug shipped in the first build of this rewrite and was caught by a screenshot: grid correct, pills gone.
- **The drawer survives the non-grid states.** `stateView` (extracted from `body`) replaces the grid on loading / empty / error, and the drawer goes back to being pinned above it via `isShowingElements`. Otherwise a filter returning zero items takes the pills off screen with it and there is no way to undo the filter.
- `safeAreaBar` + `IsSafeAreaBarApplied` are gone from the tvOS path; `LibraryHeader` no longer needs `ignoresSafeArea(edges: .horizontal)` because `LetterPickerBarModifier` already applies it to the whole library body. The preference and the tvOS branch of `LibraryElement.layout` now only matter to iOS / the unused collection path.

## Follow-up in the same session — the navigation title floated too

Same complaint one layer up: on every library that carries a title (Média→library, a home row's title button, "Films récents" and friends) tvOS kept the **navigation bar title** pinned over the posters scrolling under it. The main-bar tabs were unaffected only because `TabItem` already hides their navigation bar.

Fix: `.toolbar(.hidden, for: .navigationBar)` on tvOS for every `PagingLibraryView`, and the title redrawn as `inlineTitleView` — first row of the same scrolling stack, above the drawer, `largeTitle`/bold at `edgePadding`.

**`router.isRootOfPath` is not the "am I pushed" signal.** The obvious gate — draw the title only when not at the root — renders nothing: a diagnostic build printing `root=\(router.isRootOfPath)` on a *pushed* library showed **`root=true`**, because a pushed route gets its own coordinator whose `path` is empty. (Which also means `ItemLibraryBody`'s `if !router.isRootOfPath { FocusedPosterCinematicBackgroundView() }` never fires on pushed libraries — harmless, since `MainTabView` draws that background unconditionally on tvOS, but it is not doing what it reads like.) The title is gated on an explicit `showsInlineTitle` init parameter instead, which the two main-bar tab roots (`TabItem.library`, `TabItem.media`) pass as `false`.

## Verification status

- **BUILD SUCCEEDED** on the tvOS scheme; installed on sim `68CB155B` (md5 of installed binary == built), launched clean.
- **Layout verified by the agent** via temporary launch-argument hooks in `MainTabView` (`-openLibraryTab` to select the Films tab, `-pushLibrary` to push a titled library; both reverted before the final build): pills above the first row, 7 columns, spacing and edges identical to the collection layout, and the title rendering above the pills with no navigation bar.
- **User-confirmed working** after the rewrite: pills scroll away, Up returns to them.
- **Not verified by the agent:** focus and scrolling. Scripted input to the Simulator is still blocked (`osascript` → System Events 1002, no `idb`, `simctl` has no key injection). Needs a user pass: scroll down (pills should scroll away), come back up to row 1, press Up (should land on the pills, not the menu bar).
- iOS could not be compiled on this machine at all — only the tvOS 26.2 runtime is installed. The iOS path is unchanged code.

## Still open

_(Status as of the end of this session; superseded by the 2026-08-15 list at the bottom of the file.)_

- [x] Committed as `d1286344` and deployed to the Apple TV on 2026-08-15.
- [ ] **User verification of the rewrite** — focus Up into the pills, pills scrolling away, paging past the first 50 items, back-to-top on repeated tab selection, and the list display style.
- [ ] Verified on sim 2026-08-02 by user: pills aligned ✓, home rows correct ✓ (hero À suivre after the 9th commit). **Filter keychain retention still unverified** — needs two user clicks; protocol: set Non lu on Films → agent runs `simctl uninstall` + reinstall + relaunch → user re-opens Films (uninstall wipes UserDefaults, so survival proves the keychain path).
- [ ] Show-page layout/focus/play-button color on v4: 1.5-stock by construction, user spot-check recommended.

---

# Session 2026-08-15 — upstream `1.6` review + the home hero "empty white line"

## The bug: the hero logo was stretched across the whole screen

**Reported:** a large clear/empty line just above the À suivre strip on the home page, gone once you move down.

**Root cause — upstream's, not ours.** `CinematicSelectionContentGroup.SelectionView.topContent`
builds the hero logo as `ImageView(...)` with **no width constraint**. `ImageView`'s default
`image` closure is `Image(uiImage:).resizable()`, which has no ideal size, so the trailing
`.aspectRatio(contentMode: .fit)` has nothing to preserve and the logo is stretched to the full
container width inside a 100pt-tall frame. A wordmark logo at ~18:1 smears into a flat
translucent band — which is exactly what the user saw. The requested image was already only
`parentFrame.width * 0.4` (768pt) wide, so it was being blown up ~2.4× as well.

**Fix — backport of upstream `17323162` / PR #2192 "Cap tvOS Home Logo Width" (1.6).** Request a
fixed `maxWidth: 450` and add `.frame(maxWidth: 450, alignment: .leading)` after the height frame.
(Upstream omits the `alignment:`, which centres the logo in the 450pt box; `.leading` keeps our
left edge flush with `edgePadding`. `parentFrame` is now unused in `SelectionView`, same as
upstream.) `parentLogoImageTag` from #2104 deliberately still left out.

**Verified on sim `68CB155B`:** BUILD SUCCEEDED, installed, launched. Before = full-width
translucent band above the strip; after = the "Golfeur prodige" logo renders at its proper size on
the left. Screenshots `/tmp/sf-home2.png` (before) and `/tmp/sf-fixed.png` (after).

Present at 1.5 too, so the App Store 1.5 build has it as well. Not committed yet.

## `1.6` review — it is very much a tvOS release, and it re-introduces the v3 regressions

129 commits, 327 files, 1.5 → 1.6 (2026-07-14 → 2026-08-11).

**The blocker is not the merge, it is the design switch.** Two one-line changes flip the whole
tvOS look:

| Change | 1.5 | 1.6 |
|---|---|---|
| `UIDesignRequiresCompatibility` in `Swiftfin tvOS/Resources/Info.plist` | `true` — legacy look | **removed** — full tvOS 26 Liquid Glass |
| `Defaults[.isLiquidGlassEnabled]` (`experimentalLiquidGlass`) | exists, `DEBUG`-gated, default **false** | **deleted** — glass is unconditional |
| `MainTabView` | top tab bar | `+ .tabViewStyle(.sidebarAdaptable)` (`bbda0c63`, PR #2107) — *the sidebar the user rejected* |
| tvOS `ItemView` | own folder, 5 files | **folder deleted**, consolidated into `Shared/Views/ItemView/` (PR #2112) |
| `PlayButton` | `.foregroundStyle(accentColor.overlayColor, accentColor)` + `.buttonStyle(.primary)` | `.glassEffect(.regular.selection(tint: accentColor, …), in: .capsule)` — *the "play button lost its accent colour" complaint* |
| `ListRowMenu` (settings comboboxes) | glass branch + legacy branch | legacy branch **deleted** — *the "comboboxes render differently" complaint* |

So a wholesale rebase onto 1.6 reproduces, by construction, every reason v3 was wiped on
2026-08-02. **Recommendation: stay on the 1.5 base and cherry-pick.**

Good news for our own work: `ContentGroupView` and `ContentGroupVStack` are almost unchanged
1.5 → 1.6 (`focusedGroupID` binding → `.coordinatedFocus`), so the home rework is not threatened
by upstream drift. And tvOS still has **no filter UI at all** upstream at 1.6 — the drawer is
still iOS-only (`Swiftfin/Components/NavigationBarFilterDrawer/`), so the pill drawer stays a
purely local feature.

## Cherry-pick shortlist (onto the 1.5 base)

| Tier | Commit / PR | Size | Note |
|---|---|---|---|
| **1 — done** | `17323162` #2192 Cap tvOS Home Logo Width | 1 file | the bug above ✅ |
| 1 | `1a5ef884` #2170 Don't use `runtime` if it doesn't exist | 1 line | |
| 1 | `3c2287b8` #2197 Accent colour for landscape poster progress | 1 line | |
| 1 | `c7c387d3` #2118 Fix poster preview progress | 1 line | |
| 1 | `631ca53e` #2120 Fix menu symbol styling | 3 lines | |
| 2 | `36a3eb56` #2109 MP4 HEVC `hev1`/`dvhe` device profile | 14 lines | playback correctness |
| 2 | `18b8ae4a` + `0ab58a13` DV P7 DirectPlay | 1 line each | |
| 2 | `4a649ece` VC1 transcoding profile | 26 lines | |
| 2 | `0f1ab257` drop AVC/H264 interlaced restriction | 6 lines | |
| 2 | `85a4d52e` #2161 Force Subtitle Burn-In, `7afca11e` #2121 Non-Romantic Subtitle Fix, `b94574f4` Fix Text Subtitle Conversion | 31 / 171 / — | subtitle correctness |
| 3 | `c81e33e3` #2160 Focus Play Button on Episode Details (tvOS) | 11 files | **introduces `Shared/Objects/FocusCoordinator.swift` (130 lines, self-contained) + `.coordinatedFocus(id)`** — this is the real fix for the series-`ItemView` initial-focus bug documented on 2026-08-01 §C (six disproven hypotheses). Needs hand-porting: at 1.5 the headers live in `Swiftfin tvOS/Views/ItemView/Components/`. |
| 3 | `cf71ab0d` #2176 tvOS Poster Preview | 1 file | |
| 3 | `02d65aaa` #2106 Fix library style sourcing | 5 files | |
| **skip** | #2103 / #2147 / #2097 glass, #2107 sidebar, #2112 ItemView consolidation, #2077 Season ItemView | — | these *are* the regressions |
| **skip** | `ffd850a6` #2172 `jellyfin-sdk-swift` 2.1.0 → **3.0.0** (server 12.0) | huge | whole API surface; only needed for the 1.6 features we are not taking |
| **skip** | Live TV (#2114/#2140/#2139/#2152), Server Backups (#2182), Recently Played (#2167), Filter by Language & `officialRatings` (#2190) | — | not needed; #2190 would collide with our filter branch |
| **skip** | iOS-only: #2089 letter picker, #2148/#2171 orientation, #2195 long-press unlock | — | |

## If a 1.6 rebase is ever wanted anyway

Only **12 files** overlap between `1.5..HEAD` and `1.5..1.6`:

- `AlternateLayoutView` / `LibraryElement` / `EdgeInsets` / `IsSafeAreaBarApplied` — our `fb5cd7e8`
  #2096 backport becomes **redundant**; take upstream's and drop the commit.
- `PagingLibraryView.swift` — the one real conflict (our 335-line tvOS `ScrollView` path vs
  upstream's inset threading). Our tvOS branch replaces the collection path wholesale, so it is a
  re-apply rather than a merge.
- `ItemFilterType` (upstream adds language/`officialRatings`), `ItemLibrary`, `StoredValues+User`,
  `DefaultContentGroupProvider` (upstream adds Recently Played + Recommended Programs),
  `MainTabView`, tvOS `Info.plist`, `project.pbxproj` — all small.
- `CinematicSelectionContentGroup.swift` moves `Objects/ContentGroup/` → `Objects/`; upstream's
  delta on it is only #2192 + `parentLogoImageTag`.

## 1.6 integration — 15 commits cherry-picked onto the 1.5 base (2026-08-15)

Applied in upstream chronological order with `git cherry-pick -x`, so every commit records its
origin hash. **No rebase — the 1.5 base is untouched**, and the design invariants were re-checked
after the batch (see below).

| # | Commit (ours) | Upstream | What |
|---|---|---|---|
| 1 | `5fb36514` | `02d65aaa` #2106 | Fix library style sourcing — `BindingBox` → `@StateOrBinding`; **deletes `Shared/Objects/BindingBox.swift`**, verified no remaining references |
| 2 | `942c79ee` | `36a3eb56` #2109 | MP4 HEVC `hev1`/`dvhe` device profile — adds `videoCodecTag` in `hvc1`/`dvh1` + ≤60fps conditions |
| 3 | `5d0312a7` | `c7c387d3` #2118 | Fix poster preview progress |
| 4 | `9cca9263` | `631ca53e` #2120 | Menu symbol styling — **partial**, see conflicts |
| 5 | `19dfff97` | `4a649ece` | Separate VC1 transcoding profile for the Swiftfin player |
| 6 | `3af8fdc4` | `8e9ae684` | Linting (needed by the codec chain) |
| 7 | `f345aa20` | `0f1ab257` | Drop the shared AVC/H264 interlaced restriction |
| 8 | `04b33c69` | `0ab58a13` | Allow DV P7 DirectPlay in the Swiftfin player |
| 9 | `999a683a` | `18b8ae4a` | Allow DV P7 DirectPlay on Native |
| 10 | `89966b69` | `7afca11e` #2121 | Non-Romantic Subtitle Fix — bundles `NotoSansCJK-Regular.ttc` (19 MB) + `UIAppFonts` |
| 11 | `456252bf` | `85a4d52e` #2161 | Force Subtitle Burn-In — **partial**, see conflicts |
| 12 | `a721c152` | `b94a574f` #2162 | Fix Text Subtitle Conversion |
| 13 | `969cde8d` | `1a5ef884` #2170 | Don't use `runtime` if it doesn't exist |
| 14 | `f333b127` | `cf71ab0d` #2176 | tvOS Poster Preview |
| 15 | `13c6faa6` | `3c2287b8` #2197 | Accent colour for landscape poster progress |

### The three conflicts and how they were resolved

1. **#2120 → `ServerMenu.swift`.** At 1.5 the file lives in `BottomBar/Components/`, not
   `Toolbar/Components/`, and lacks the `.foregroundStyle` + `.glassEffect(in: .capsule)` lines —
   those come from `a032bde2` (#2097), a glass PR we are deliberately **not** taking. Took only the
   actual fix, `.symbolRenderingMode(.monochrome)`. The commit's second file followed the rename on
   its own and applied clean.
2. **#2121 → `Swiftfin tvOS/Resources/Info.plist`.** Purely positional: git aligned upstream's new
   `UIAppFonts` array against our `UIDesignRequiresCompatibility`. #2121 does **not** remove that
   key (verified against the upstream diff) — kept both.
3. **#2161 → `Package.resolved` + `en.lproj/Localizable.strings`.** The `Package.resolved` hunk is
   an incidental SPM refresh (`swift-system` 1.7.4 → 1.7.5) unrelated to the feature — **kept ours**
   rather than importing a dependency bump. For the strings file (UTF-16 LE), inserted only the two
   keys the commit needs, `forceSubtitleBurnIn` / `forceSubtitleBurnInMessage`, in alphabetical
   position, rather than taking upstream's whole 1.6-era file.

### Post-batch verification

- `xcodebuild` **BUILD SUCCEEDED** (tvOS Debug), installed and launched on sim `68CB155B`, no crash.
- Home page screenshot identical to the post-`#2192` build: hero logo correct, no band, top tab bar
  unchanged.
- Design invariants re-checked: `UIDesignRequiresCompatibility` still `true` in the **built**
  `Info.plist`, `isLiquidGlassEnabled` still present and default-false, no `sidebarAdaptable` in
  `MainTabView`, tvOS `ItemView/` folder intact.
- `UIAppFonts` present in the built bundle and `NotoSansCJK-Regular.ttc` (19 MB) actually copied —
  the project uses file-system-synchronized groups, so no `pbxproj` edit was needed.
- Every L10n key added by the batch resolves in `en.lproj` (checked programmatically).

### Deliberately NOT taken

`c81e33e3` #2160 "Focus Play Button on Episode Details on tvOS" — the one remaining Tier-3 item, and
the real fix for the series-`ItemView` initial-focus bug from 2026-08-01 §C. It is **portable**:
`Shared/Objects/FocusCoordinator.swift` is self-contained, and the rest is mechanical
(`ContentGroupVStack` `focusedGroupID` → `.coordinatedFocus`, `ContentGroupView` gains a
`@StateObject FocusCoordinator`, the tvOS header drops its `@FocusState` + `defaultFocus` block, the
play button takes `.coordinatedFocus(ItemView.Component.play)`).

**Not done because it cannot be verified here.** Scripted input to the Simulator is still blocked
(no `idb`, `simctl` has no key injection), so a focus change to the show page — the exact screen
that got v3 rejected — would ship untested. Needs a hardware pass with the remote. Left as an
opt-in follow-up.

Also still skipped, unchanged from the review above: all glass/sidebar/`ItemView`-consolidation PRs,
the `jellyfin-sdk-swift` 3.0.0 bump, Live TV, Server Backups, Recently Played, Filter by Language,
and the iOS-only fixes.

### Not verifiable on the simulator

The codec and subtitle picks (#2109, VC1, DV P7 ×2, interlaced, #2121, #2161, #2162) are all
playback-path changes. They compile and the app runs, but they need real playback on the Apple TV
against the M1Center server to be confirmed.

## Deployment record + open items (2026-08-15, end of session)

**Two deploys to the Apple TV today**, both Release, both via `Scripts/deploy-appletv.sh`:

1. `fa89102f` (tag `local-v4-hero-logo-fix-2026-08-15`) — profile to 2026-08-22 17:40.
2. `8b1bccc2` (tag `local-v4-1.6-cherrypicks-2026-08-15`) — **current**, profile to 2026-08-22 18:06.

The second deploy is what is on the TV now. It is also the **first time the 2026-08-08 drawer/title
scrolling rewrite (`d1286344`) has ever reached the device** — that commit had only ever been
sim-tested. Anything odd about the library screens is more likely that commit than the 1.6 batch.

### Open — verification owed by the user

- [ ] **Playback on the TV** — the whole point of the codec batch and the only thing the simulator
      cannot prove. HEVC file (#2109 now requires `hvc1`/`dvh1` codec tags + ≤60fps, so
      direct-play/transcode decisions may flip either way), Dolby Vision P7 if available, an
      interlaced source, a VC1 source.
- [ ] **Subtitles** — a title with non-Latin (CJK) subtitles now that Noto CJK is bundled, plus the
      new **Réglages → Lecteur vidéo → Force subtitle burn-in** toggle.
- [ ] **Library screens on the device** — pills scroll away, Up from row 1 returns to the pills,
      paging past the first 50, back-to-top on repeated tab selection, list vs grid display style
      (#2106 rewired the binding underneath the layout picker).
- [ ] **Filter keychain retention** — still never verified, on sim or device. Protocol unchanged:
      set *Non lu* on Films → uninstall + reinstall + relaunch → re-open Films.
- [ ] Show page / settings comboboxes still 1.5-stock — spot-check.

### Open — work not done, with reasons

- [ ] **Push.** `origin/local/appletv-dev-v4` is at `fa89102f`; 16 commits and the tag
      `local-v4-1.6-cherrypicks-2026-08-15` are local-only. Not pushed because it was not asked for.
- [ ] **`c81e33e3` #2160 play-button focus / `FocusCoordinator`.** Portable, mapped out, not done —
      it changes initial focus on the show page and scripted sim input is still blocked, so it
      cannot be verified here. Now that the batch is on hardware this is the natural next step,
      as its own commit so it can be reverted alone.
- [ ] **Drawer doesn't visibly update on filter change** — carried since 2026-08-01 §D, still needs
      a live repro.
- [ ] **`local/appletv-dev-v2` is no longer the deployed build.** It stays as a fallback branch but
      the TV has not run it since 2026-08-15.
