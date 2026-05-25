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
| P5 | 🟡 paused | — | Last verified state: `xcodebuild ... Debug build` at HEAD `23252324` → BUILD SUCCEEDED. `.app` installed on sim `68CB155B-71F7-4326-8131-B3621A95BFCF` (Apple TV 4K 3rd gen, tvOS 26.2) at the prior `50971ebb` build via `xcrun simctl install`. **Not yet reinstalled at `23252324` and not launched.** Pending: see "Next session" below. |
| P6 | ⚪ pending | — | After P5 passes: add "Resolution" section to `tvos-simulator-login-report.md` pointing at `167628b7`; note upstream issues #163/#776/#809/#930 likely closed. |

Legend: ✅ done · 🟡 in progress · 🔴 blocked · ⚪ pending

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

State at pause (2026-05-25 evening):

- Current branch: `local/appletv-dev`, clean working tree (no uncommitted changes)
- Last commit: `23252324 fix(tvOS): restore navigationBarCloseButton + L10n.by (second audit)`
- Last build: ✅ `xcodebuild -scheme "Swiftfin tvOS" -destination "platform=tvOS Simulator,id=68CB155B-71F7-4326-8131-B3621A95BFCF" -configuration Debug build` → **BUILD SUCCEEDED**
- Sim has a stale install from commit `50971ebb` — reinstall before launching.

Commit graph since `pr-1770-filters`:

```
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

### To resume P5 (build + sign-in verification on sim)

1. Reinstall the freshly-built `.app` on the booted Apple TV sim:
   ```bash
   APP="/Users/cyrilnaimi/Library/Developer/Xcode/DerivedData/Swiftfin-gimasjlzhpdqaxaswqzmhlnmznuj/Build/Products/Debug-appletvsimulator/Swiftfin tvOS.app"
   xcrun simctl install 68CB155B-71F7-4326-8131-B3621A95BFCF "$APP"
   xcrun simctl launch 68CB155B-71F7-4326-8131-B3621A95BFCF org.jellyfin.swiftfin.local
   ```
   (Bundle id is `.local` per `XcodeConfig/DevelopmentTeam.xcconfig`.)
2. Sign in with `lgtv` / `lgtv`. Confirm token persists across a kill+relaunch (validates the Phase 1 entitlements fix).
3. Open a library → exercise the filter pills:
   - Tap a Filter pill, set a Genre. Confirm the pill turns accent-purple (P4.2).
   - Tap Reset. Confirm pill goes back to grey.
   - Set a filter, enable **Settings → Customize → Library → "Remember filtering"** (P4.1 added this toggle).
   - Kill the app and relaunch. Confirm the filter survived.
4. Verify `.isPlayed` + `.isUnplayed` mutual exclusion: open the Traits filter, tap both — only the most recent should remain selected (P4.1).
5. Open an episode → confirm the new tvOS player from #1902 launches (don't need to play to completion).
6. Open Settings → confirm the Close button works (validates the P4.4 BLOCKER fix).

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
