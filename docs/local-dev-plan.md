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

| Phase | Status | Commit (if applicable) | Notes |
|---|---|---|---|
| P0 | 🟡 in progress | — | Backed up 8 patches, ready to reset working tree |
| P1 | ⚪ pending | — | — |
| P2 | ⚪ pending | — | — |
| P3 | ⚪ pending | — | — |
| P4 | ⚪ pending | — | — |
| P5 | ⚪ pending | — | — |
| P6 | ⚪ pending | — | — |

Legend: ✅ done · 🟡 in progress · 🔴 blocked · ⚪ pending

---

## Out of scope / out of band

- **Rotate the leaked API key on the Jellyfin server** ✅ done by user. The key was `b127840f…`; it appeared in a working-tree patch only and will not enter any commit on this branch.
- **Upstream PR**: if the team wants, the Phase 1 commit (keychain fix) is a strong candidate for a small focused upstream PR — high value, low risk, likely closes multiple long-standing tvOS issues.
