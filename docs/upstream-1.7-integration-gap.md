# Upstream 1.7 — integration gap & starting point

> Snapshot taken **2026-10-31** against `upstream/main` @ `436ddb06` (not a tag — 1.7 is
> not released yet). Our side: branch `1.6.1_sidebar_filter_sdk3.3.0` @ `cf123d7b`
> (on the TV, tag `local-1.6.1-sdk3.3.0-2026-10-18`).
> Merge base with upstream: `7891e273` "Content Groups (#2075)", 2026-07-14.
> **Re-run the commands in §7 before starting — upstream will have moved.**

## 1. TL;DR

- Upstream 1.7 milestone: 61 closed / 3 open, one being **#2280 "TestFlight: 1.7 not on tvOS"**.
  Last release is still 1.6.1 (2026-08-23). ~396 commits since our merge base.
- **Filtering:** upstream now has a tvOS filter UI (#2321) and `staticFilters`, which covers
  our UI and our Reset/`itemTypes` bug. It does **not** cover: full filter persistence,
  persistence on the Movies/TV Shows tabs, surviving reinstall, Played/Unplayed exclusivity.
- **Home:** upstream has the better plumbing (shared item store, focus restore, optional
  rows); ours has the better hero (Resume → Next Up → Recently Added). Hero is ~90 lines to
  re-author.
- **Cost of moving to 1.7:** unconditional Liquid Glass, tvOS 26.1 target, tvOS ItemView
  consolidated into `Shared/`, new players (mpv / SwiftVLC / `AVMediaPlayerProxy`).
- **Recommended strategy:** when 1.7 ships on tvOS, start a fresh branch **on the 1.7 tag**
  and re-author our layer (§4) — do not rebase/replay our commits. Same rule as the 1.5 → v4
  rebuild.

## 2. What upstream changed that matters to us

### Filters / libraries
| PR | What | Impact on us |
|---|---|---|
| #2321 `898af8f4` tvOS Filters | `FilterBarModifier` (tvOS) + `FilterTrack` (shared): vertical rail of compact icon capsules, opposite the `LetterPickerBar`; title shows on focus; each button routes to `.filter(type:viewModel:)` (full-screen `FilterView`); Reset button when active. Horizontal under the search bar in `SearchView`. Adds `FocusCoordinator` scopes. | Replaces our `LibraryHeader` / `LibraryFilterMenu` need. Decide: keep theirs (cheapest) or port our stacked panel on top of `FilterTrack`. |
| `staticFilters` (in #2321 / #2047 line) | `FilterViewModel.staticFilters` = fixed filters (tab item types, query), excluded from selection state and Reset; `hasActiveFilters = staticFilters ∪ current != static`. | **Fixes** our `hasActiveFilters` / `reset()` deviation (3149ecc7). Drop ours. |
| #2190 Filter by Language & officialRatings | audio/subtitle language, official rating, category filter types | New types appear in the rail; nothing to port. |
| #2327 Shared item store | `ItemStore`, `ItemPatch`, libraries return `[ItemPatch]`, `@SharedBaseItem` | `ItemLibrary.retrievePage` signature changed — our `persistenceID` patch must be re-authored against it. |
| #2256 Tab bar placement | `Defaults[.Customization.tabBarPlacement]` = `.sidebar` / `.tabBar` | **Covers** our sidebar backport (46f54208). Drop ours, set default/sidebar. |
| Open **#2360** Storable Filters (JPKribs, unreviewed, conflicting, no milestone) | `rememberSort` → `rememberFilters` (default **off**), stores full `currentFilters` minus `query`; named saved filters. **Skips libraries with itemTypes** → Movies/TV Shows tabs still not persisted. | If merged, rebase our persistence on it and only add: tab key + default on + (keychain). |

Still true upstream (verified in code):
- `ItemLibrary.init` restores only `sortBy`/`sortOrder`, gated by `rememberSort` (default false).
- `StoredValues+User.libraryFilters` carries the 2024 TODO: *"only used for sortBy and sortOrder.
  Need rules for libraries that init with non-default filters (ex: favorites)"*.
- `TabItem.library(...)` builds `ItemLibrary(parent: BaseItemDto(name: title), staticFilters:)`
  → **no parent id → nothing ever stored** for Movies/TV Shows (our P9 bug).
- `ItemFilterType.traits` setter: `$1.currentFilters.traits = $0.map(ItemTrait.init)` — no
  Played/Unplayed exclusivity.

### Home
| PR | What |
|---|---|
| `DefaultContentGroupProvider` (upstream) | tvOS: `CinematicSelectionContentGroup(resume, recentlyAdded)` → `PosterGroup(NextUpLibrary)` → `CinematicRecentlyAddedContentGroup` (only when resume exists, gated by `showRecentlyAdded`) → Recently Played (`showRecentlyPlayed`, default off) → `programs-recommended` (Live TV) → Latest-in per library. |
| `Swiftfin tvOS/Objects/CinematicSelectionContentGroup.swift` | **moved** (was `Objects/ContentGroup/`). Hero still Resume → Recently Added, no Next Up. Logo cap 450 is in. |
| #2335 Content group focus, #2160 FocusCoordinator | focus restore on Home; episode-page initial focus fix (our open bug). |
| #2228 hide recommendations, #2249 hide poster labels, #2334 indicator styling, #2316 Favorites background | nice-to-haves, free with the base. |

### Platform / risk
- `TVOS_DEPLOYMENT_TARGET` 26.0 (ours) → **26.1** (#2203).
- `UIDesignRequiresCompatibility` gone, `isLiquidGlassEnabled` gone → glass everywhere except
  `UIDevice.supportsLiquidGlass == false` (#2224). Our TV = AppleTV6,2 → excluded → flat
  fallback. **Must be checked visually on the TV** (play button, ListRowMenu, comboboxes).
- `Swiftfin tvOS/Views/ItemView/` removed → `Shared/Views/ItemView` (#2202 etc.).
- Players: mpv (#2274), VLCKit → SwiftVLC (#2273), `NativePlayer` → `AVMediaPlayerProxy` (#2046).
  Our cherry-picked codec/subtitle commits are upstream already — drop them.
- App icon selection (#2340): `Shared/Objects/AppIcons.swift`, `Resources/AppIcons/` — check it
  does not fight our "App Icon Local" brandassets / xcconfig bundle id.
- SDK: upstream on a newer jellyfin-sdk-swift than our 3.3.0 pin (#2352) — take theirs.

## 3. Our features vs 1.7

| Our commit(s) | Feature | 1.7 status | Action on 1.7 base |
|---|---|---|---|
| ec26ccdf, d21de4d0 | Local distinction layer (bundle id via xcconfig, icon, name, entitlements, deploy script) | n/a | **Re-apply** (chore(local)). Check vs #2340 icons. |
| 57fa8f96 | Glass hardware gate + opt-out flag | partial (#2224 gate only) | Decide: accept glass-on-capable-HW (TV is excluded anyway) or re-add flag + `UIDesignRequiresCompatibility`. Test on TV first. |
| 46f54208 | Leading sidebar | **covered** (#2256) | Drop. |
| 3149ecc7, d1286344, 3169c284 | tvOS filter drawer → scrolling header → stacked panel | **covered differently** (#2321 rail) | Drop by default; port panel only if the rail is not good enough on the TV. |
| 3149ecc7 (part) | `hasActiveFilters` / `reset()` keep `itemTypes` | **covered** (`staticFilters`) | Drop. |
| 18dcaa4c | Persist full filter set; `ItemLibrary.persistenceID` for tabs; keychain `StoredValues` destination + `KeychainObservable` | **not covered** (#2360 partial, excludes tabs) | **Re-author**: store `currentFilters` (never `staticFilters`), key = `persistenceID ?? parent.id` (`"tab-movies"`/`"tab-tvshows"` from `TabItem.library`), remember on by default, keychain destination kept for weekly reinstall. Keep Release keychain entitlements wired. |
| 01b18f5a | Played/Unplayed mutually exclusive | **not covered** | Re-apply (~15 lines in `ItemFilterType.traits` setter). Upstream candidate. |
| 7aa847f7 | Hero prefers Next Up (`heroSource`, `CinematicNextUpContentGroup`) | **not covered** | Re-author on moved `CinematicSelectionContentGroup.swift` + item-store APIs (`ItemPatch`, `.snapshot`). |
| 3319d939 | No global Recently Added row on tvOS | **covered** by `showRecentlyAdded` toggle | Drop; set toggle off. |
| 8bb64222 | Hero logo width cap | **covered** (#2192) | Drop. |
| fb5cd7e8 | tvOS grid insets (#2096 slice) | likely superseded by #2321 insets rework | Verify, probably drop. |
| 3169c284 (part) | fr `likedItems` "Favoris" duplicate | check upstream fr strings | Re-apply if still duplicated (UTF-16 file — edit with Python). |
| cherry-picks (#2106 #2109 #2118 #2120 #2121 #2161 #2162 #2170 #2176 #2197 #2230 #2232 #2236 #2238, codec, SDK) | | **all upstream** | Drop. |

## 4. Integration plan (draft)

0. Wait for the 1.7 tag **and** #2280 (tvOS TestFlight) — confirms tvOS builds clean.
   Check #2360 state.
1. Tag current TV build as restore point (already: `local-1.6.1-sdk3.3.0-2026-10-18`).
2. New branch `1.7_local` from the `1.7` tag. Build stock for tvOS sim + TV, look at glass
   fallback, filter rail, Home on real hardware **before** adding anything.
3. Re-apply local distinction layer (`chore(local)`), deploy-script check.
4. Played/Unplayed exclusivity (small, separate commit; upstream candidate).
5. Filter persistence: `persistenceID` + full `currentFilters` + keychain destination.
   If #2360 merged → build on `rememberFilters` instead of `rememberSort`.
6. Hero Next Up (`heroSource`). Set `showRecentlyAdded` off.
7. Optional: glass opt-out flag, stacked filter panel — only if step 2 showed a need.
8. Full TV pass (filters both entry points + relaunch + reinstall, Home, playback, subtitles),
   then switch main checkout so the weekly Shortcut deploys it.

## 5. Conflict map (our files changed since tag 1.5 vs upstream)

Upstream **deleted/moved**: `JellyfinSocket.swift`, `BindingBox.swift`, `MediaPlayerProxy*.swift`,
`MediaProgressObserver.swift`, `PosterSection.swift`, `Swiftfin/Extensions/LogFile.swift`,
`Swiftfin tvOS/Objects/ContentGroup/CinematicSelectionContentGroup.swift` (→ `Swiftfin tvOS/Objects/`),
`Swiftfin tvOS/Views/ItemView/` (→ `Shared/Views/ItemView`).

Upstream **modified** and touched by our own (non-cherry-pick) work — the real re-author list:
`MainTabView.swift`, `TabItem.swift`, `ItemLibrary.swift`, `ItemFilterType.swift`,
`PagingLibraryView.swift`, `StoredValues+User.swift`, `_GenericValueObservation.swift`,
`DefaultContentGroupProvider.swift`, `ContentGroupView.swift`, `UIDevice.swift`, `GlassEffect.swift`,
`ListRowMenu.swift`, `SwiftfinApp+configure.swift`, `IsSafeAreaBarApplied.swift`, `EdgeInsets.swift`,
`LibraryElement.swift`, `SwiftfinDefaults.swift`, tvOS `Info.plist`, `project.pbxproj`, `Package.resolved`.

Ours only (carry over as-is or drop): `KeychainObservable.swift`, `StoredValue.swift` (keychain
destination), `LibraryFilterMenu.swift`, `LibraryHeader.swift`, `deploy-appletv.sh`,
`App Icon Local.brandassets`, tvOS entitlements.

## 6. Tripwires — status on upstream 1.7

| Tripwire (from local-dev-plan) | On 1.7 |
|---|---|
| `UIDesignRequiresCompatibility = true` | **gone** |
| `Defaults[.isLiquidGlassEnabled]` | **gone** |
| `MainTabView` = our `46f54208` | replaced by `tabBarPlacement` (fine) |
| `Swiftfin tvOS/Views/ItemView/` | **gone** |

The 1.7 move means accepting all four, or re-adding the glass opt-out on purpose.

## 7. Refresh commands

```sh
git fetch upstream --tags
git log --no-merges --oneline 7891e273..upstream/main | grep -vi weblate
gh api repos/jellyfin/Swiftfin/milestones --jq '.[]|"\(.title) open=\(.open_issues) closed=\(.closed_issues)"'
gh pr view 2360 -R jellyfin/Swiftfin --json state,reviewDecision,mergeable
git show upstream/main:Shared/Objects/Libraries/ItemLibrary.swift | grep -n -A6 "rememberSort\|rememberFilters"
git show upstream/main:Shared/Objects/ItemFilter/ItemFilterType.swift | grep -n -A4 "case .traits:"
git show upstream/main:Shared/ViewModels/ContentGroupViewModel/DefaultContentGroupProvider.swift
```

## 8. Upstream references

- #333 tvOS Search/Sort/Filter (2022 → closed by #2321) — includes "filter by watched" for kids.
- #1770 community tvOS filter PR (closed for #2321) — maintainer's reasoning on tvOS filter placement.
- #585 (2022) saved all filters; #1045 (2024) narrowed to sort + the TODO.
- #1470 / #1495 Played/Unplayed wrong on Shows/Collections (iOS, `recursive=false` fix).
- #2360 Storable Filters (open). #2280 1.7 not on tvOS TestFlight.
- Draft upstream issue (not posted): see Appendix A.

## Appendix A — draft upstream issue (not posted)

**Title:** tvOS: remember the Played/Unplayed filter on the Movies / TV Shows tabs, and make Played/Unplayed mutually exclusive

Hi, and first of all thank you for Swiftfin — I use it daily on an Apple TV and the progress over the
last months has been great to watch. The tvOS filter bar in #2321 especially closes a long-awaited
issue (#333). Thank you to everyone involved.

I'd like to suggest a small follow-up, based on a personal fork I've been running on my Apple TV
since the summer.

**Use case.** Most of my tvOS browsing starts the same way: open Movies or TV Shows from the tab bar
and filter to Unplayed (also the filter that makes the app usable for kids — see the 2023 comment in
#333). On `main` today:

1. Only `sortBy`/`sortOrder` are remembered (behind `rememberSort`, off by default), so Unplayed must
   be re-selected every time. The TODO in `StoredValues+User.swift` explains why.
2. The Movies / TV Shows tabs can't store anything: their `ItemLibrary` parent has no `id`, so
   `libraryFilters(parentID:)` is never written. #2360 broadens remembering (thank you!) but skips
   libraries with item types, so these two tabs stay excluded.
3. Played and Unplayed can both be selected; the server then returns an empty library — easy to hit
   with a remote and confusing.

**What I did in my fork** (for reference):
- Stable storage key for the tabs: optional `ItemLibrary.persistenceID`, defaulting to `parent.id`;
  the tabs pass `"tab-movies"` / `"tab-tvshows"`. Kept separate from `parent.id` because a synthetic id
  there is sent as a `parentID` scope and the tab renders empty (same separation as `pagingLibraryID`).
- Remember user choices, not structural ones: genres, letter, tags, traits, years and sort are stored;
  `itemTypes` and `query` are not. With `staticFilters` on `main`, storing `currentFilters` and never
  `staticFilters` may be enough to resolve that TODO.
- Played/Unplayed mutually exclusive in the `ItemFilterType.traits` setter: the newly tapped one wins.
  ~15 lines, platform-agnostic.
- (Fork-specific: filters stored in the keychain to survive the weekly free-Apple-ID reinstall — not
  needed for App Store users.)

**Suggestion.** Let the Movies / TV Shows tabs take part in filter remembering (in #2360 or a
follow-up) with a stable non-server key, and make Played/Unplayed mutually exclusive on both
platforms. Happy to open a PR for either, rebased on `main` and aligned with #2360 — or leave this as
a suggestion. Thanks again for all the work!

---

## Update 2026-11-08 — upstream filter tracking

- 1.7 is on iOS/macOS and on tvOS TestFlight (2026-11-06, #2280 closed). Milestone 1.7: 76 closed / 1 open. No git tag yet; latest GitHub release is 1.6.1.
- Still NOT in `main`: Played/Unplayed exclusivity (`traits` is still a `.multi` selector), filter remembering beyond sort (`libraryFilters(parentID:)` TODO unchanged), remembering on the Movies / TV Shows tabs.
- **#2360 Storable Filters**: open, `CONFLICTING`, no milestone. LePips left the first review comment on 2026-11-08: "good to get in prior to #2416". Still skips libraries with `itemTypes`, so the tabs would not persist.
- **#2416 View and tab customization** (LePips): open since 2026-11-08. May restructure tabs; re-check our `persistenceID` tab key after it lands.
- **#2343** Home shelves by genre: open; #2360 is meant to hook into it.
- No upstream issue or PR exists for Played/Unplayed exclusivity; the draft above is still unfiled.
- Decision: wait for #2360 / #2416 before aligning; keep the tab persistence and exclusivity as local changes.
