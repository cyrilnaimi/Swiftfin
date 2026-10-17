# Plan: `1.6.1_sidebar_filter_sdk3.3.0` — Jellyfin 12 readiness

> **Tracking doc.** Tick boxes as steps land; add the commit hash next to each.
> Created 2026-10-17. Starting point: `1.6_sidebar_filter` @ `25f05579` (pushed, clean).

## Goal

Make the Swiftfin Local tvOS build work on a Jellyfin **12.0** server with the
default `EnableLegacyAuthorization=false`, **without** taking upstream's 1.6 UI
(Liquid Glass, upstream sidebar, consolidated `ItemView`). Validate everything on
the current **10.11** server first; upgrade the server only at the end.

## Why (findings from 2026-10-17 analysis)

| Risk on 12.0 | Today (SDK 2.1.0) | Fixed by |
|---|---|---|
| Websocket sends `api_key=` → refused (legacy) | ❌ | SDK **3.2.0** (jellyfin-sdk-swift #62, `ApiKey`) |
| New enum values `Narrator`, `VideoRotationNotSupported`, `VideoRotation` → decode failure | ❌ | SDK **3.0.0** + Swiftfin #2172 |
| Sign-in / REST auth | ✅ `Authorization: MediaBrowser` | — |
| `/emby/`, `/mediabrowser/`, removed endpoints | ✅ unused | — |
| Direct-play `/Videos/{id}/stream` | ✅ server does not require auth | — |
| `GetItems` recursion semantics changed | ⚠️ unknown | test filters on 12.0 |

Official releases 1.6 / 1.6.1 ship SDK 3.0.0, so they **still** send `api_key` on the
socket. Only upstream `main` (SDK 3.3.0, generated for 12.1) has the fix.

SDK 3.0.0 → 3.3.0 is **additive** (no deleted/renamed files or enum cases); the only
hand-written changes are `JellyfinClient.swift` (`api_key`→`ApiKey`) and `QuickConnect.swift`
(transient poll tolerance). So the risky step is 2.1.0 → 3.0.0, i.e. Swiftfin #2172.

## Dry-run results (cherry-picked onto `1.6_sidebar_filter` in a throwaway worktree)

| Commit | Upstream | Result | Resolution |
|---|---|---|---|
| `ffd850a6` | #2172 SDK 3.0.0 (12.0) | conflict | `UserSessionManager+SocketCommands.swift` doesn't exist on our branch (came with #2150, not taken) → drop that hunk. `PosterSection.swift` differs → hand-apply `UserItemDataDto(key: "")`. `Package.resolved` / `en.lproj/Localizable.strings` → regenerate / re-add the strings (UTF-16!) |
| `e19b524b` `0a95bfe0` `88cbbbdf` | #2267 #2296 #2352 SDK 3.1→3.3 | conflict (lockfile only) | **Don't cherry-pick.** One commit setting the SDK to `3.3.0` in `project.pbxproj` + re-resolving packages |
| `5b794d2b` | #2236 ProgressView top-leading | clean | take |
| `5e59e245` | #2238 pause video when app backgrounds | clean | take |
| `6ac865ba` | #2203 tvOS target 26.1 | clean | optional (TV runs 26.6) |
| `759b4ced` | #2230 Update Version Warning | conflict (strings only) | take — the warning wording matters once the server is 12.0 |
| `0adebd32` | #2232 Use `Thumb` if available | conflict `BaseItemDto+Poster.swift` | evaluate (touches our landscape-art logic) |
| `961f1325` | #2225 Fix search overlap | conflict `SearchView.swift` | evaluate |
| `d5be7a05` | #2173 tvOS deep links | conflict `NavigationInjectionView.swift` | evaluate |
| `43bcfaba` | #2228 Toggle to hide recommendations | conflict (strings only) | optional feature |
| `d67fbdad` `545aaa28` `67d5fbdf` | #2205 #2204 program dates, extras runtime | conflict `BaseItemDto+Poster.swift` | optional |
| `96afb777` `8e11b0aa` | #2233 #2214 | clean | **skip** — iOS-only files |
| `27468c72` | #2224 LiquidGlass on unsupported Apple TV | conflict, 10 files | **skip** — we have our own gate (`57fa8f96`) |
| `0ec38cfe` | #2226 Empty/errored library fixes | conflict | **skip** — deletes `HomeViewModel.swift`, collides with our home hero |
| `f5a8804f` | #2208 Replace tvOS `_Alert` | conflict, 10 files | skip for now (sign-in views; low value) |

## Tripwires — check after EVERY import (from the 1.6 verdict)

- [ ] `Swiftfin tvOS/Resources/Info.plist` → `UIDesignRequiresCompatibility` still `true`
- [ ] `Defaults[.isLiquidGlassEnabled]` still exists, default `false`
- [ ] `MainTabView` has no `.tabViewStyle(.sidebarAdaptable)` (our own sidebar stays)
- [ ] `Swiftfin tvOS/Views/ItemView/` folder still present

## ⚠️ Deploy automation caveat

`Scripts/deploy-appletv.sh` (run weekly by the "Swiftfin.local update" Shortcut) builds
**whatever is checked out**. While this work is in progress, either:
- do the work in a separate worktree and keep the main checkout on `1.6_sidebar_filter`, **or**
- remember the TV will get the work-in-progress build on the next Shortcut run.

Recommended: separate worktree (`git worktree add ../Swiftfin-sdk3 1.6.1_sidebar_filter_sdk3.3.0`).

---

## Phase 0 — Safety net
- [ ] Tag `local-1.6-sidebar-pre-sdk3-2026-10-17` on `25f05579` and push it
- [ ] Confirm the TV build matches `1.6_sidebar_filter` (deployed 2026-10-17 16:51, profile until 2026-10-24)

## Phase 1 — Branch
- [ ] `git branch 1.6.1_sidebar_filter_sdk3.3.0 1.6_sidebar_filter`, work in a separate worktree
- [ ] Push the empty branch to `origin`

## Phase 2 — SDK 3.0.0 (#2172)
- [ ] `git cherry-pick -x ffd850a6`, resolve as in the dry-run table
- [ ] Re-add the new strings (`narrator`, `videoRotationNotSupported`) to `en.lproj/Localizable.strings` with Python `encoding="utf-16"`
- [ ] Re-resolve packages (`xcodebuild -resolvePackageDependencies`)
- [ ] Build tvOS Release (`-skipMacroValidation`, **check the exit code, don't pipe into `tail`**)
- [ ] Fix any compile errors in our local code (only known call site, `MediaPlayerManager.swift:425 UserItemDataDto()`, is covered by #2172)
- [ ] Tripwires ✓
- [ ] Commit, push

## Phase 3 — SDK 3.3.0
- [ ] Set `jellyfin-sdk-swift` to `3.3.0` (pbxproj minimum version + `Package.resolved`), re-resolve
- [ ] Build tvOS Release ✓
- [ ] Verify in the checkout: `JellyfinClient.swift` uses `ApiKey` (not `api_key`) in `socketURL`
- [ ] Commit `chore: jellyfin-sdk-swift 3.3.0 (upstream #2267 #2296 #2352)`, push

## Phase 4 — 1.6.1 fixes (one commit each, `-x`, build after each batch)
- [ ] #2236 `5b794d2b`
- [ ] #2238 `5e59e245`
- [ ] #2230 `759b4ced` (strings in UTF-16)
- [ ] Evaluate, take or skip: #2232 `0adebd32` · #2225 `961f1325` · #2173 `d5be7a05`
- [ ] Optional: #2203 `6ac865ba` · #2228 `43bcfaba` · #2205/#2204
- [ ] Tripwires ✓, build ✓, push

## Phase 5 — Test on the current 10.11 server (simulator first, then TV)
Simulator: resolve the bundle id from the built `Info.plist` and md5-compare the installed
binary before trusting anything (stale-app trap). Scripted input is blocked, so navigation
checks need the user.

- [ ] Existing signed-in user survives the update (no forced re-login)
- [ ] Sign out → sign in with password
- [ ] Quick Connect sign-in
- [ ] Home: Next Up hero, À suivre first row, hero logo width
- [ ] Leading sidebar navigation (Movies, TV Shows, libraries)
- [ ] Filter menu: every filter, **unplayed / played mutually exclusive**, counts look right
- [ ] Filters persist after relaunch, and after reinstall (keychain)
- [ ] Direct play (H.264 / HEVC / DV P7 file)
- [ ] Transcoded playback (force a low bitrate)
- [ ] Subtitles: embedded, external, burn-in
- [ ] Resume position reported back to the server / Continue Watching updates
- [ ] Playback overlay session info (websocket) shows data
- [ ] Admin → Active Sessions (websocket) lists sessions
- [ ] Search
- [ ] Item with a Narrator credit opens (if any in the library)

## Phase 6 — Cut over on the TV
- [ ] Deploy `1.6.1_sidebar_filter_sdk3.3.0` with `Scripts/deploy-appletv.sh`, verify the installed binary
- [ ] Use it for a few days on 10.11
- [ ] Tag `local-1.6.1-sdk3.3.0-<date>`, push
- [ ] Switch the main checkout to the new branch (the weekly Shortcut now deploys it)
- [ ] Update `docs/local-dev-plan.md` restore-points table + memory

## Phase 7 — Upgrade the server to Jellyfin 12.0 (only when Phase 6 is solid)
Pre-flight:
- [ ] Full server backup (config + database); upgrade path requires 10.10.7 or any 10.11.x
- [ ] Remove third-party plugins (10.11 builds won't load on 12.0); official plugins are fine
- [ ] Check for usernames that differ only by case (migration fails on them)
- [ ] Note other clients in the house (App Store Swiftfin, web, etc.) — very old ones will stop working

Upgrade:
- [ ] Upgrade to 12.0, run a full library scan
- [ ] Leave `EnableLegacyAuthorization` at its default **`false`**

Re-test the full Phase 5 checklist on 12.0, with extra attention to:
- [ ] Websocket features (overlay session info, Active Sessions) — the reason for SDK 3.2+
- [ ] Filter results/counts (12.0 `GetItems` recursion change)
- [ ] Version warning text in Settings

Rollback:
- App: redeploy `1.6_sidebar_filter` (tag `local-1.6-sidebar-pre-sdk3-2026-10-17`) — on 12.0 it needs `EnableLegacyAuthorization=true` in `system.xml` for the websocket features
- Server: restore the pre-upgrade backup

## Optional follow-ups
- [ ] Move the deploy lock out of `/tmp` (a sandboxed run and the Shortcut couldn't see each other's lock on 2026-10-17)
- [ ] Pin the deploy script to a branch instead of "whatever is checked out"
- [ ] `c81e33e3` #2160 FocusCoordinator (series ItemView initial-focus fix) — still portable

## Progress log
- 2026-10-17 — Analysis + dry-run done, plan written. No code changed yet.
