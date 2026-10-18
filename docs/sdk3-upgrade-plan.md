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

## Review 2026-10-17 — will SDK 3.3.0 still work against the 10.11 server?

**Yes.** Verified against the sources (not from memory):

| Check | Result |
|---|---|
| 10.11 accepts the `ApiKey` query parameter? | ✅ `release-10.11.z` `AuthorizationContext.cs`: token sources are `Authorization` header → `X-Emby-Token` → `X-MediaBrowser-Token` → **`ApiKey` (always)** → `api_key` (legacy only). Same code in 12.0, so one socket URL works on both. |
| SDK 3.x `Package.swift` platforms | ✅ unchanged 2.1.0 → 3.3.0 (only the generator plugin bumps 0.7.1 → 0.8.0) |
| Endpoints deleted in SDK 3.0.0 (25 files: `OnPlayback*`, `*Hls*`, `StopEncodingProcess`, `GetMusicGenres`, `GetCriticReviews`, …) | ✅ our code calls only `Paths.stopEncodingProcess` (`MediaProgressObserver.swift:165`), which #2172 removes. Transcoding is driven by `TranscodingUrl` from `PlaybackInfo`, not the SDK HLS paths. |
| Entities deleted (`ConfigImageTypes`, `SubtitleOptions`) | ✅ unused |
| Fields 12.x made **required** (decode would throw on a 10.11 reply that omits them) | ✅ only `UserItemDataDto.key` and `LogFile.name` matter to us; 10.11 always sends both. The rest are Backup / Storage / Database / Lyrics DTOs (12-only features we never request). |
| `JellyfinSocket` public API 2.1.0 → 3.3.0 | additive: `SocketError`, `SubscriptionToken.cancel()`. #2172 brings the matching `ServerSocketManager` rewrite. |
| Files #2172 touches vs our branch | identical to upstream except `MediaPlayerManager.swift` (small drift, applies), `ServerSocketManager.swift` (we removed the playback-command surface from #2150; hunks still apply), `PosterSection.swift` (hand-apply), `UserSessionManager+SocketCommands.swift` (absent → drop hunk) |

Side effects to **expect** on 10.11 (not bugs):

- **Version-warning banner appears in Settings and in the server edit page.** `isVersionCompatible`
  compares the server version to the SDK's `client.version`, which jumps `10.11.8` → `12.1.0`
  with SDK 3.3.0. Nothing gates on it (two label sites only). #2230 only softens the wording to
  "Update to Jellyfin 12.1 for the best experience". It disappears once the server is 12.x.
- **No explicit kill of transcodes on stop** (`stopEncodingProcess` gone). The server's own idle
  timeout cleans them up; same behaviour as upstream 1.6.
- **Admin → Devices batch delete** sends `?id=a&id=b`; a 10.11 server binds only the first value,
  so deleting several devices at once removes one. Admin-only, rare, fixed by the server upgrade.
- `deleteDevice`, `getItemCollections` and other 12-only paths are not used on our tvOS screens.

Corrections to the original plan:

- Tripwire "no `.sidebarAdaptable`" was wrong: **our own** sidebar (`46f54208`) uses
  `.tabViewStyle(.sidebarAdaptable)` at `MainTabView.swift:137`. The real tripwire is that our
  `MainTabView` backport (comment block at lines 96–100) is untouched by any import.
- The dry run was a cherry-pick only, **never a build**. Compile errors in local-only code (filter
  menu, sidebar, home hero) against SDK 3 types are found in Phase 2, not before.
- Restore tag goes on `d80f7ec8` (= `25f05579` + the plan doc; identical binary). The TV was
  built from `25f05579`: reflog shows the checkout at 16:50:48, deploy logs at 16:50:51/16:51:06.
- The M1Center Jellyfin service was **down** during the review (host pings, 8096/8920/80 refuse).
  Phase 5 needs it back; this is a user action.

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
- [ ] `MainTabView.swift` still carries our sidebar backport (`git diff 46f54208 -- Shared/Coordinators/Tabs/MainTabView.swift` is empty, or only our own edits)
- [ ] `Swiftfin tvOS/Views/ItemView/` folder still present

## ⚠️ Deploy automation caveat

`Scripts/deploy-appletv.sh` (run weekly by the "Swiftfin.local update" Shortcut) builds
**whatever is checked out**. While this work is in progress, either:
- do the work in a separate worktree and keep the main checkout on `1.6_sidebar_filter`, **or**
- remember the TV will get the work-in-progress build on the next Shortcut run.

Recommended: separate worktree (`git worktree add ../Swiftfin-sdk3 1.6.1_sidebar_filter_sdk3.3.0`).

---

## Phase 0 — Safety net
- [x] Tag `local-1.6-sidebar-pre-sdk3-2026-10-17` on `d80f7ec8` and push it — done 2026-10-17
- [x] Confirm the TV build matches `1.6_sidebar_filter` — built from `25f05579` at 16:50 (reflog + deploy logs), profile until 2026-10-24

## Phase 1 — Branch
- [x] `git branch 1.6.1_sidebar_filter_sdk3.3.0 d80f7ec8`, worktree at `../Swiftfin-sdk3` — done 2026-10-17
- [x] Pushed the branch to `origin` (tracking set)

## Phase 2 — SDK 3.0.0 (#2172) — `70e957a3`
- [x] `git cherry-pick -x ffd850a6`, resolved as in the dry-run table (`UserSessionManager+SocketCommands.swift` → `git rm`; `PosterSection.swift` → `key: ""` only, we never had `unplayedItemCount`)
- [x] Re-added `narrator` / `videoRotationNotSupported` to `en.lproj/Localizable.strings` (UTF-16, `///` comment style like the neighbours, `plutil -lint` OK)
- [x] Re-resolved packages — **note:** the pin is up-to-next-major, so raising the floor to 3.0.0 resolved straight to **3.3.0**. Phase 2 and 3 therefore built against the same SDK.
- [x] Build tvOS Release — exit 0, no compile errors in local code. The worktree needs `Carthage -> ../Swiftfin/Carthage` (symlink, ignored) or the build stops on the missing `TVVLCKit.xcframework` before compiling anything.
- [x] Tripwires ✓

## Phase 3 — SDK 3.3.0 — `fad74f51`
- [x] pbxproj minimum `3.0.0` → `3.3.0` for the jellyfin block **only** (SVGKit and Factory are also pinned at 3.0.0 — a blanket replace breaks the resolve)
- [x] `JellyfinClient.swift` in the checkout uses `ApiKey` at both sites (`url(with:queryAPIKey:)` and `socketURL`); `git describe` says `3.3.0`

## Phase 4 — 1.6.1 fixes (one commit each, `-x`)
- [x] #2236 `5b794d2b` → `a887b2cd` (clean)
- [x] #2238 `5e59e245` → `92fa8e2d` (clean; `pauseOnBackground` default and `onSceneDidEnterBackground` already exist on our branch)
- [x] #2230 `759b4ced` → `04324d93` (strings conflict; `serverVersionWarning` re-applied in UTF-16)
- [x] #2232 `0adebd32` → `0cc41184`, hand-applied in `landscapeImageSources` (our case list includes `liveTvProgram`/`program`); same thumb-first pattern the `default:` branch already had
- [ ] #2225 `961f1325` **on hold** — our tvOS `SearchView` has none of the 1.6 focus-coordinator structure the overlap came from. Apply (`.edgePadding(.top)` after `.searchable`) only if Phase 5 shows the search field overlapping results.
- [x] #2173 `d5be7a05` **skipped** — needs the `PresentedRoute.coordinator` refactor of `NavigationCoordinator`; our `NavigationInjectionView` diverged (older `.presentation` API). Deep links are not a local-build feature.
- [x] Optional #2203 / #2228 / #2205 / #2204 **skipped** (not needed; #2203 changes the deployment target for no benefit)
- [x] Tripwires ✓ (compat flag `true`, glass default `false`, `MainTabView` byte-identical to `46f54208`, `ItemView/` present), tvOS Release build exit 0, pushed

## Phase 5 — Test on the current 10.11 server (simulator first, then TV)
Simulator: resolve the bundle id from the built `Info.plist` and md5-compare the installed
binary before trusting anything (stale-app trap). Scripted input is blocked, so navigation
checks need the user.

Prerequisite: Jellyfin on M1Center (`http://192.168.50.154:8096`) must be up — it was down on
2026-10-17 afternoon, back at 18:00 (10.11.11). Expected and **not** a bug: the orange
"Update to Jellyfin 12.1" banner in Settings.

**Worktree trap (hit 2026-10-17):** the gitignored `XcodeConfig/DevelopmentTeam.xcconfig` carries
the `.local.cnaimi` bundle id, the signing team, the "Swiftfin Local" name and the badged icon.
Without it the worktree builds a stock `org.jellyfin.swiftfin` app — on the simulator it installs
*beside* the local app instead of over it, and on the TV it would collide with the App Store app
and fail signing. The worktree now has symlinks for `Carthage`, `Cartfile.resolved` and
`XcodeConfig/DevelopmentTeam.xcconfig` pointing at the main checkout. Check the bundle id in the
built `Info.plist` before every install.

Simulator run 2026-10-17 18:14 (Apple TV 4K 3rd gen, tvOS 26.2, Release build `a29cf3e4…` installed
over the August build, md5 verified, bundle `org.jellyfin.swiftfin.local.cnaimi`). Evidence read from
the app's Pulse store (`Library/Caches/Logs/com.github.kean.logger/current.pulse/logs.sqlite`,
copied to `screens/pulse.sqlite`) and `lsof`:
- ✅ Launched straight into Home with the stored session; CoreData + prefs migrated to the new container.
- ✅ Websocket: server→client `outboundKeepAliveMessage` every 20 s on an established TCP connection
  to `192.168.50.154:8096` — the 10.11 server accepted the `ApiKey` socket URL. (The "Socket
  connected" line itself was swept from the store with the first 20 s of the session; Pulse trims on open.)
- ✅ No non-2xx API responses, no decode errors, no warnings above debug except image 404s
  (missing artwork, same as before).
- ⚠️ First `/Items` + `/Items/Latest` took 18.9 s — server cold start after being down, not the app;
  subsequent calls 0.01–0.7 s.
- Screenshots: `screens/01-launch.png` (spinner), `02-home.png` (resume hero + À suivre),
  `03-now.png` (Latest rows, landscape cards with thumbs).

- [x] Existing signed-in user survives the update (no forced re-login) — simulator ✅
- [ ] Sign out → sign in with password
- [ ] Quick Connect sign-in
- [x] Home: resume hero, À suivre first row, Latest rows — simulator ✅ (`02-home.png`, `03-now.png`)
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
- [x] Deploy `1.6.1_sidebar_filter_sdk3.3.0` with `Scripts/deploy-appletv.sh`, verify the installed binary
  (2026-10-18 16:31, run from the worktree; profile until 2026-10-25 16:31)
- [~] Use it for a few days on 10.11 — skipped: the server went to 12.2.0 the same day
- [x] Tag `local-1.6.1-sdk3.3.0-2026-10-18` (local; push pending)
- [x] Switch the main checkout to the new branch (the weekly Shortcut now deploys it).
  The worktree `../Swiftfin-sdk3` is now on a detached HEAD, because git allows a branch in only one checkout.
- [x] Update memory (`docs/local-dev-plan.md` restore-points table still to do)

Result on Jellyfin **12.2.0** (TV Pulse log, user session 2026-10-18 16:34–16:36): no 401s, websocket
connected and streaming, Home / Next Up / Resume / Latest / show pages OK, playback
start/progress/stop accepted (204). Only failures: 404 on artwork the server doesn't have
(Thumb, Logo, Chapter) — same as the pre-upgrade session. Filters, unread filter and search not yet exercised.

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
- 2026-10-17 — Plan reviewed against the server / SDK sources (section above). Phase 0 + 1 done:
  tag `local-1.6-sidebar-pre-sdk3-2026-10-17`, branch `1.6.1_sidebar_filter_sdk3.3.0` in
  worktree `../Swiftfin-sdk3`, both pushed. Main checkout stays on `1.6_sidebar_filter`.
- 2026-10-17 — Phases 2–4 done in one sitting: `70e957a3` (#2172), `fad74f51` (SDK 3.3.0 pin),
  `a887b2cd` `92fa8e2d` `04324d93` `0cc41184` (#2236 #2238 #2230 #2232). Three tvOS Release builds,
  all exit 0, zero local compile errors. #2225 on hold, #2173 skipped. **Next: Phase 5** — needs the
  M1Center Jellyfin service back up (it was down all afternoon) and the user at the remote.
  Build products for the simulator: `xcodebuild … -destination 'generic/platform=tvOS Simulator'`
  with `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/SwiftfinSdk3`.
- 2026-10-17 18:30 — Simulator smoke test on 10.11.11 passed (session kept, Home renders, `ApiKey`
  websocket alive, no API/decode errors). **User's call: the remaining Phase 5 items (filters,
  playback, overlay/Active Sessions, search) are deferred and will be run after the server upgrade,
  together with the Phase 7 re-test.** Branch pushed at this point; worktree clean.
