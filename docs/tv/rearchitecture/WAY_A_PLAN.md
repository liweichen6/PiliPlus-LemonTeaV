# Way A: A New TV Architecture on Upstream PiliPlus

> **Status** (2026-11-14): chosen by the user "for now", and its decisions are settled (§9). This file is the plan; nothing in it is built and no task has started.
> **Roles**: Claude Fable plans, reviews and runs the gates. Claude Opus executes, one task per session (§10).
> **Beside this file**: [`REARCHITECTURE.md`](./REARCHITECTURE.md) has the review and the comparison of the three ways. [`WAY_B_PLAN.md`](./WAY_B_PLAN.md) and [`WAY_C_PLAN.md`](./WAY_C_PLAN.md) hold the other two, as outlines.
> **Rules**: the Execution Rules of [`PLAN.md`](../PLAN.md) hold, privacy included, except where §9 changes one.

---

## 1. What Way A Is

The app stays a fork of `lemonteaau/PiliPlus`. What changes is how the TV part is built:

| Today | Way A |
| :--- | :--- |
| Upstream's touch pages, made to obey a remote by a focus engine that guesses | **A TV shell**: the fork's own screens for a TV, on upstream's data layer and controllers |
| mpv into a Flutter texture; 4K only on a variant branch; no HDR | **Media3 on the video plane** as the TV's player, for video and then for live |
| The thread ripper on the UI thread | Measured, and moved to its own isolate if it costs frames |
| Every merge to `main` releases, with upstream's newest code inside | Upstream merged by pull request; a release is cut on purpose |
| Under 30 hook lines, whatever indirection that costs | A budget of 100 hook lines, spent where a hook removes a workaround |
| `main`, `variant/4k-passthrough` and a spike | One line |

What stays: upstream's network code, models, accounts and storage; its list controllers; its player controller and player view; the HUD from M14 and M15; `TvPlatform` and `TvBridge`; the test harness; the device tools.

What goes, in the end: the focus engine as the way screens are navigated, its adapters, the four TV patch files, the variant branch, and mpv as the TV's default player.

**Nothing is staged.** The repository's owner is the app's only user today (2026-11-14). So a new screen, or the new player, becomes the default as soon as it passes its gate, and what it replaces is removed in the same milestone. There are no opt-in switches and no release to wait out. What this postpones until the app has other users is in §8.

---

## 2. The Target Architecture

```
┌─ upstream, used as is ──────────────────────────────────────────────────┐
│ lib/http, lib/grpc, models, accounts, storage, utils                    │
│ list controllers (推荐, 热门, dynamics, history, favourites, search …)  │
│ VideoDetailController, intro and reply controllers, PlPlayerController  │
│ the player view (PLVideoPlayer), danmaku, subtitles                     │
└──────────────────────────────────────────────────────────────────────────┘
        ▲ imports only; what the shell imports is listed by a script (A0.2)
┌─ lib/tv ────────────────────────────────────────────────────────────────┐
│ shell/    the route registry and its flags, the main page (rail, tabs), │
│           one file per TV screen                                         │
│ kit/      focus: TvShellScope, TvFocusGroup, TvFocusable, the shell's    │
│           traversal policy · components: card, grid, row, rail, tabs,    │
│           dialog, option list, text field                                │
│ player/   TvExoPlayer (the M17 adapter), the transparent video view,     │
│           the HUD (M14, M15)                                             │
│ ripper/   the isolate host for the thread ripper (only if A2 says so)    │
│ legacy    today's focus engine and adapters: frozen, reached only by     │
│           routes the shell hasn't replaced                               │
└──────────────────────────────────────────────────────────────────────────┘
android/   TvBridge.kt, TvExoPlayer.kt, two overrides in MainActivity
```

New code goes into the new folders. Existing files move only when a task has to touch them anyway.

### 2.1 The Shell and the Route Registry

Upstream navigates by route name in 186 places and has 70 named routes. So one hook is enough to swap screens:

```dart
getPages: TvShell.pages(Routes.getPages),   // lib/main.dart, one line changed
```

`TvShell.pages` returns upstream's list with the TV's screens put in by name. The registry is a plain map from route name to TV screen:

* A screen is registered as soon as it's built, on `main`. That's safe because a merge no longer publishes (AD1): `main` may hold a screen that hasn't passed its gate, and a release is cut only after one has.
* When a screen passes its gate, upstream's page for that route is no longer reachable on a TV, and the adapters and tests that existed only for it are deleted in the same milestone.
* One build-time define brings an old page back by name, in dev builds only, so a gate can measure old against new on the same day.

Upstream also pushes 44 pages directly, without a name. `A3.0` lists them and decides each: wrap it, leave it on the legacy lane, or make it unreachable on a TV.

### 2.2 Focus Inside the Shell

A shell screen declares its focus structure. Nothing is inferred.

* **`TvShellScope`** wraps every shell route. Under it the legacy engine stands down: no ring, no recovery, no layer detection. It also sets the navigation mode back to traditional, so the four TV patch files stop adding focus nodes to gesture widgets. (`A3.1` proves both by test before anything is built on them.)
* **`TvFocusGroup`** is a rail, a tab bar, a grid, a row or a button bar. It declares its axis, what it remembers (the item focus left from: M13's column memory), and what lies beyond each edge.
* **`TvFocusable`** is one target. It draws its own focus state in a paint-only layer, in the legacy ring's colour and shape, so nothing is laid out again when focus moves.
* **The shell's policy** picks the next target from the declared structure: inside a group by index, between groups by the declared edges, with geometry only to line up a row with the one beside it. Its cost doesn't grow with the page.
* **Grids and lists have fixed extents**, so a step can scroll and move focus in the same frame, without waiting for layout.
* **Dialogs and sheets** opened by shell screens are the shell's own, and they trap focus by construction.

### 2.3 The Player

M17's design, with its framing changed from "a second player behind a setting" to "the TV's player":

* `TvExoPlayer extends PlatformPlayer implements NativePlayer`, over a Kotlin Media3 player. Upstream's controller keeps talking to a `Player`. Proven in `M17.4` with 21 lines added and 2 changed in upstream's Dart files.
* **The transparent view only.** `M17.4` measured it at 10.3 ms a frame with heavy danmaku, against 18.7 ms for the platform view. The platform view's code isn't carried into the build.
* **A setting, 播放器内核**: Media3 or mpv, TV only. Media3 is the default from the day `M17.12` passes its bar. mpv stays as a choice, held to 1080P60 and below on a TV.
* **Fail closed, with a way back.** A failure on Media3 ends on a failure screen. Its actions are retry, and "play with mpv at 1080P60 or below". Nothing ever sends a stream above 1080P60 to mpv.
* **Live moves to Media3 too** (`A1.L1`–`A1.L3`), if its spike passes. Then one controller always holds one kind of player, and `M17.3`'s rule about a live room opened over a video goes away.
* **Not on this path**, as in M17: mpv's shaders (超分辨率), `af` (音量均衡, volume above 100 %), rotate, flip and zoom, screenshots, picture-in-picture. Their HUD entries hide while Media3 plays.

### 2.4 Hooks

| File | Hook | Lines | From |
| :--- | :--- | :--- | :--- |
| `lib/main.dart` | Init, observer, wrapper (there today) and the route registry | about 11 | M2, `A3.4` |
| `lib/pages/video/widgets/player_focus.dart` | The HUD | 4 | M4 |
| `lib/utils/connectivity_utils.dart`, `lib/common/constants.dart`, `lib/http/api.dart` | Ethernet, the fork's URLs | 3 | M1 |
| `lib/plugin/pl_player/controller.dart` | The player and its controller | 12 added, 2 changed | `M17.9` |
| `lib/plugin/pl_player/view/view.dart` | The video view | 9 | `M17.9` |
| `lib/pages/setting/models/video_settings.dart` | The setting | 1 | `M17.9` |
| `lib/plugin/pl_player/controller.dart` | The ripper's host | about 2 | `A2.2`, if it runs |
| `MainActivity.kt`, `TvBridge.kt`, the manifest, `build.gradle.kts` | The transparent view, the bridge, cleartext to loopback, Media3 | about 20 | `M17.7` |

About 45 lines of Dart in upstream's files, against a budget of 100. `A0.2` counts them in CI.

---

## 3. Order and Gates

```
A0 Decouple ──┬── A1 Media3 as the TV's player ───────────────► A2 Ripper (if measured)
              └── A3 Shell foundation and home ══ GATE ══► A4 Lists ─► A5 Video pages ─► A6 The rest ─► A7 Remove
```

* **A1 and A3 run side by side.** They touch different files, as M13 and M14 did.
* **A3's gate is Way A's answer on D-pad feel.** It measures a home screen built for this purpose, on `<physical-tv>`, against today's. If a purpose-built Flutter screen can't meet the bar, more screens won't either, and the plan stops there for a decision instead of building A4 to A6 on hope. That's also where the Way B question would get its data.
* **A1 delivers first**: 4K, HDR and Dolby Vision in the normal app, whatever happens to the shell.

| Gate | Where | Bar, on `<physical-tv>` | Today |
| :--- | :--- | :--- | :--- |
| **GA1** | End of `M17.12` | M17's own bar (`PLAN.md`): 4K60 AVC and AV1 for 10+ minutes on the video plane, each kept HDR quality in its real mode, every failure on the failure screen | 4K only on the variant |
| **GA3** | End of A3 | Home: a plain D-pad step at or under 33 ms at p90 | 43.6 ms |
| | | Home: raster at or under 8 ms at p50 | 15.1 ms |
| | | Home: choosing the target at or under 1 ms at p90 | 4.1 ms |
| | | Home: at least 85 % of frames within 16.7 ms while a key is held | about 40 % |
| | | Every M13 path that applies to home passes on the shell | |
| **GA4–GA6** | End of each | The same step and frame bars on each new screen. A step that scrolls a long list at or under 45 ms at p90 | 53–85 ms on comments |

Measured with M13's probe and protocol, which work unchanged because it's the same app.

---

## 4. Milestones and Tasks

Sizes are executor sessions. A "device" mark is a session on `<physical-tv>` with the user.

### A0: Decouple (3 sessions)

* **`A0.1` — Releases and syncs.** In `tv-sync-build.yml`: a merge to `main` builds and checks but doesn't publish; a release is a manual run of the workflow. The scheduled job opens a pull request from `sync/upstream-<date>` instead of merging into `main`. The version scheme stays. **Done when**: a test merge publishes nothing, a manual run publishes, and the scheduled run opens a pull request.
* **`A0.2` — Hook budget and upstream dependencies.** `tool/tv_hooks.sh` counts the lines the fork adds or changes in upstream's Dart files and fails over the budget. `tool/tv_upstream_deps.sh` lists every upstream file that `lib/tv` imports; on a sync pull request CI prints which of them changed. `docs/tv/HOOKS.md` is the table in §2.4, kept current. **Done when**: both run in `tv-checks.yml`.
* **`A0.3` — Docs.** `PLAN.md` and `PROGRESS.md` get Way A's rows and a pointer to this file; M18 is closed and the variant marked for retirement at `M17.12`; the READMEs say TV only. Markdown only.

### A1: Media3 as the TV's Player (about 18 sessions, 4 device)

M17's remaining tasks keep their ids and their text in `PLAN.md`. What this plan changes in them is listed here.

* **`M17.5` — Spike B: HDR, Dolby Vision and audio.** As prepared in `PLAN.md` ("Prepared for the start"), on the stashed build. One addition: the ripper-off frame times of item 10 are A2's input. *Device, with the user at the panel. 2 sessions: the rebuild with `<vm-tv>`, then the TV.*
* **`M17.6` — The gate.** Shorter than planned, because this plan settles three of its questions: the adapter, the transparent view, and landing on `main`. Left for it: which HDR qualities are offered and which brightness step is taken, the final "not on this path" list, and what a direct fetch does with the ripper off.
* **`M17.7` — Kotlin Media3 bridge.** As planned, with the transparent view only. *2 sessions.*
* **`M17.8` — Dart player and view.** As planned, plus what `M17.4` found: the adapter's own bounded retry, a failure screen that upstream's loading spinner can't cover, and a message when a room or video is refused. *2 sessions.*
* **`M17.9` — Hooks, setting and rules.** As planned, with four changes. The setting is 播放器内核 with two values, and Media3 is the default on a TV. The failure screen has the "play with mpv at 1080P60 or below" action. "Each hook inert off a TV" is one smoke test, not a test per hook, since phones are out of scope. And the TV's default quality is no longer held at 1080P60 (AD11): the seed from M12's option A is removed, so the default is the best quality the TV and the account can play, and mpv on a TV stays capped at 1080P60. The seed is already stored on the user's TV, where it can't be told from a choice, so 默认画质 is set there once by hand. *2 sessions.*
* **`M17.10` — HUD capabilities and 播放信息.** As planned. *1 session.*
* **`M17.11` — Tests and CI.** As planned. *2 sessions.*
* **`M17.12` — Device pass and docs.** As planned, except that nothing waits on a soak. It ends at GA1 and lands with Media3 as the TV's default. `variant/4k-passthrough` is retired and its workflow removed in the same task. The user's normal viewing afterwards is the soak, and what it finds comes back as fixes. *Device. 2 sessions.*
* **`A1.L1` — Study: live on Media3.** Which stream formats upstream asks for in a live room and which Media3 plays; what the live page asks of the player that video doesn't (`stream.size`, the quality switch, reconnects); what the forks and `bv` do. Markdown only. **Done when**: a go or no-go for the spike, with the list of what it must show.
* **`A1.L2` — Spike: a live room on Media3.** On a dev build: 1080p first, the layer `DEVICE`, live danmaku and SuperChat over it, a quality switch, a dropped connection. Above 1080p only with the user's go-ahead: a 2K room appeared to shut the TV down on the GPU path on 2026-10-31, and this is the first run of one on the plane. *Device.*
* **`A1.L3` — Build: live on Media3.** The adapter's live source, the HUD's live entries on this path, tests. Then the "kind is fixed" rule and its refusals are removed. *2 sessions.*

### A2: The Thread Ripper Off the UI Thread (up to 4 sessions, 1 device; conditional)

* **`A2.1` — Measure and study.** From `M17.5`'s numbers and one more run at the highest bitrate the TV plays: what the ripper costs the UI thread per frame. And from the code: what `PlPlayerController` asks of `RipperRangeProxy`, and what would have to cross an isolate boundary. **The rule**: if the ripper costs under 1 ms a frame at p50 with a 4K HDR stream, A2 ends here with the number written down.
* **`A2.2` — The isolate host.** Upstream's `RipperRangeProxy`, unchanged, running in a background isolate, behind a class in `lib/tv/ripper/` that the controller holds in its place. The same containment as the player adapter. *2 sessions.*
* **`A2.3` — Tests and device pass.** The ripper's own tests through the host; the frame times again. Offering the change to the ripper's upstream needs the user's approval first.

### A3: Shell Foundation and Home (about 11 sessions, 1 device)

* **`A3.0` — Inventory.** Every named route and every direct push: what opens it on a TV, how often it matters, and its target (shell screen, legacy lane, unreachable). What upstream's code expects to find registered (`MainController`, `HomeController` and others looked up by `Get.find`), so the shell's main page provides it. Markdown only.
* **`A3.1` — The focus kit.** `TvShellScope`, `TvFocusGroup`, `TvFocusable` and the policy of §2.2, with tests first for the two claims everything rests on: the legacy engine is silent under a scope, and the TV patches add no focus node there. Then unit tests for memory, edges, and scroll-with-focus on fixed extents. *2 sessions.*
* **`A3.2` — Layout agreement** (planner and user, as `M14.1` was): the main page (the rail's entries, the tabs), the card, the grid's columns, what Back does at each level. Mock-ups, then a written list. No executor session.
* **`A3.3` — Components.** Card, grid, row, rail, tabs, dialog, option list (from the HUD's), text field (on `TvPlatform`'s keyboard gate). Built to the raster bar: covers requested at the size shown, no shadow or opacity layers, a repaint boundary per card. *3 sessions.*
* **`A3.4` — The route registry.** `TvShell.pages`, the build-time define that brings an old page back, the hook in `lib/main.dart`. **Done when**: with nothing registered, a test shows the app is route-for-route what it is today.
* **`A3.5` — The main page and home.** The rail and tabs, 推荐 and 热门 on upstream's controllers, pull-to-refresh replaced by a key, load-more at the end. Registered at once. *2 sessions.*
* **`A3.6` — Shell path tests.** The harness of `test/tv_path_harness.dart` extended to shell screens; M13's home paths re-recorded against the shell (bugs 8, 9 and 10 among them).
* **`A3.7` — GA3.** A dev build on `<physical-tv>`, M13's probe, the home runs, old against new through the define. *Device.* **On a pass**: upstream's main page and home leave the TV's route table, and what existed only for them is deleted. **If the bar is missed**: the plan stops for a decision.

### A4: List Screens (about 14 sessions, 1 device)

Each is its controller from upstream, shell components and a recorded path, registered as it lands.

* **`A4.1`** Home's other tabs: 番剧 and 影视, the live list. *2 sessions.*
* **`A4.2`** The dynamics feed, as the place for updates from followed accounts: all and video, by account. *2 sessions.*
* **`A4.3`** A dynamic's detail, view only: text, pictures, the video card.
* **`A4.4`** History, favourites with a folder's contents, 稍后再看. *3 sessions.* Removal there is a real action on the user's account: it's two steps, never one key.
* **`A4.5`** Search: entry with the TV's keyboard, suggestions, results by type. *3 sessions.*
* **`A4.6`** Member pages: videos, collections, follow. *2 sessions.*
* **`A4.7`** GA4. Then the old pages for these routes leave the TV, with what existed only for them. *Device.*

### A5: Video Pages (about 15 sessions, 2 device)

* **`A5.0` — Study.** How far `VideoDetailController` and the intro, reply and media-list controllers run without upstream's video page around them: which of their fields belong to that page's view (tabs, scroll keys, the animation controller) and whether leaving them unused is safe; what the player view and the HUD expect from the page. **Out**: the host design, or the parts that need a wrapper. Markdown only.
* **`A5.1` — Layout agreement** (planner and user): the page around the player, where intro, actions, parts, related and comments sit, what fullscreen and Back do.
* **`A5.2`** The video page for UGC: the host, the player in place, intro. *3 sessions.*
* **`A5.3`** 番剧 and 影视: seasons and episodes. *2 sessions.*
* **`A5.4`** Comments, read only, with replies: the TV's own rows on upstream's reply controllers and its text rendering. *3 sessions.*
* **`A5.5`** Actions: like, coin, favourite with a folder choice, triple-like, follow, 稍后再看. *2 sessions.*
* **`A5.6`** Parts, related, the play list, auto-next. *2 sessions.*
* **`A5.7`** Tests and GA5, with the transparent view under the new page in every state: split, fullscreen, a dialog over it, a route over it. *Device, twice.*

### A6: Live, Messages, Settings (about 12 sessions, 1 device)

* **`A6.1`** The live room's page around the player. The live HUD exists. *2 sessions.*
* **`A6.2`** Messages, view only: replies, mentions, likes, system notices. *2 sessions.*
* **`A6.3`** Articles, view only. *2 sessions.*
* **`A6.4`** TV settings: the settings a TV needs, in the shell's own controls, writing the same keys as upstream's. Upstream's full settings stay reachable from an "advanced" entry, on the legacy lane (AD10). *3 sessions.*
* **`A6.5`** Login (QR only), about, the update check. *2 sessions.*
* **`A6.6`** GA6. *Device.*

### A7: Remove (about 4 sessions)

* **`A7.1` — Audit.** A3 to A6 each deleted what they replaced. What's left is the engine itself and whatever still needs it: which routes still land on the legacy lane, and for each, rebuild it, block it on a TV, or keep it.
* **`A7.2` — Delete.** The focus engine, the adapters and tests still standing, and the four TV patch files, as far as the audit allows. If advanced settings stay on the legacy lane, the engine stays for them, frozen, and this task says so plainly. *2 sessions.*
* **`A7.3` — Docs.** `ARCHITECTURE.md` and `REVIEW.md` rewritten for what the app now is.

**Total**: about 81 executor sessions and about 10 device sessions. This is a task-by-task count; the 57 in the first comparison was a milestone-level guess and was too low. At the pace of M13–M15, about three tasks a day, that's five to seven weeks, set by device sessions and review more than by code.

---

## 5. What Changes on the TV, and When

| After | On the TV |
| :--- | :--- |
| A0 | Nothing visible. `main` stops publishing by itself, so it can hold work in progress |
| `M17.12` | Media3 is the player: 4K, HDR and Dolby Vision in the normal app. The variant ends |
| `A1.L3` | Live on Media3 too, if its spike passed |
| `A3.7` | The new main page and home replace the old ones |
| A4, A5, A6 | Each group of screens replaces the old ones when it passes its gate |
| A7 | The retrofit is gone, as far as the audit allows |

A release is cut after a gate, not after a merge. Between gates the user's TV runs dev builds beside the normal app, as it has since M12.

---

## 6. Risks

| Risk | Answer |
| :--- | :--- |
| A purpose-built Flutter screen still isn't fast enough on this TV | GA3, after 11 sessions and before the other 45 of the shell. A miss stops the plan for a decision |
| Upstream changes a controller the shell uses | A compile error on the sync pull request, not on a TV. `A0.2` shows which imported files changed |
| Upstream's video controllers don't run outside their page | `A5.0` finds out on paper. The fallback is a wrapper around them, which reopens A5's size |
| The transparent view under routes and dialogs it hasn't met | `A5.7` checks every state. `M17.4` covered the HUD, its menu, a sheet and a dialog |
| Media3 as the default meets a stream it can't play | The failure screen offers mpv at 1080P60 or below, and 播放器内核 can be set back. Other people's TVs are §8's question |
| Live on Media3 doesn't pass | Live stays on mpv at 1080p and below, and `M17.3`'s rule stays. Nothing else depends on it |
| A new screen turns out worse than the one it replaced, after the old one is deleted | The gate comes before the deletion, and the old page is one `git revert` away |
| A Flutter bump breaks the transparent view or a patch | It fails in the TV checks on the sync pull request |
| The legacy lane never fully goes | `A7.1` decides per route, in the open. Advanced settings are the likely remainder |

---

## 7. What Way A Doesn't Fix

Stated so nobody expects it:

* The fork still carries the phone app's code, upstream's own 34 SDK patches and every Flutter bump.
* A D-pad step still pays Flutter's input handling (about 5 ms) and the wait for the next frame, and danmaku still shares the UI thread.
* mpv stays in the APK, for the fallback and, if `A1.L2` fails, for live.

---

## 8. Before Others Use It

Postponed, because there's one user today. None of it is in A0 to A7. It becomes a milestone of its own when the app is offered to anyone else:

* **Staging.** New screens and player changes offered as a choice first, with a way back for a release. The registry's define becomes a setting.
* **Other TVs.** Media3 as the default was proven on one MediaTek TV and one emulator. Other SoCs need a compatibility pass, and the failure screen's wording has to make sense to someone who hasn't read these docs.
* **Releases.** The update prompt reaches everyone who installed the app, so a release needs its checks required on `main` (branch protection is still not set) and release notes written for users.
* **The READMEs**: what the TV app is now, what it doesn't do, which TVs it was tested on.

---

## 9. Decisions and Inputs

**Decisions**, settled by the user on 2026-11-14

| # | Decision | Outcome | Affects |
| :--- | :--- | :--- | :--- |
| AD1 | A merge to `main` no longer publishes; a release is cut on purpose. This changes Execution Rule 5 | Yes | `A0.1` |
| AD2 | The scheduled upstream sync opens a pull request instead of merging | Yes | `A0.1` |
| AD3 | How new screens roll out | **No staging**: a screen is the default once it passes its gate, and the old one goes in the same milestone | §2.1, A3 to A6 |
| AD4 | When Media3 becomes the default | **At `M17.12`**, with no release to wait out | `M17.9`, `M17.12` |
| AD5 | Try live on Media3 | Yes | `A1.L1`–`A1.L3` |
| AD6 | Close M18 now; retire `variant/4k-passthrough` | Yes; the variant goes at `M17.12` | `A0.3`, `M17.12` |
| AD7 | Run A1 and A3 side by side | Yes | The order |
| AD8 | Messages and articles, view only | In A6 | `A6.2`, `A6.3` |
| AD9 | The hook budget: 100 lines in upstream's Dart files | Yes | `A0.2` |
| AD10 | A TV settings screen for what a TV needs, with upstream's full settings behind an "advanced" entry | Yes | `A6.4`, `A7.2` |
| AD11 | With Media3 the default, stop holding the TV's default quality at 1080P60 (M12's option A). The best quality the TV and the account can play becomes the default; mpv on a TV stays capped at 1080P60 | Yes (added after AD4, settled the same day) | `M17.9` |

**Inputs**

* For `M17.5`, as listed in `PLAN.md`: a session on `<physical-tv>`; videos that offer HDR 真彩, 杜比视界 and HDR Vivid to the test account, one with 杜比全景声 or Hi-Res audio, one with subtitles; the go-ahead for runs above 1080p; you at the panel.
* Two layout agreements: `A3.2` and `A5.1`.
* About ten device sessions in all.
* Approval before anything is reported or offered to an upstream project.

---

## 10. How Execution Works

**Roles.** The planner owns this plan, writes each task's brief and each gate's bar, reviews every pull request against its brief, and runs the device gates with the user. An executor takes one brief in a fresh session and delivers one pull request.

**A brief has**

| Field | Content |
| :--- | :--- |
| Goal | One or two sentences |
| Read first | The files and the sections of these docs that hold the context |
| Scope | What to build, and what to leave alone |
| Fixed interfaces | The signatures and types the planner has decided |
| Checks | The exact commands that must pass |
| Device | "None", or the steps, each waiting for its go-ahead |
| Stop and report when | A new dependency; an interface that has to change; a hook outside §2.4; a check that can't be made to pass honestly; anything on a device that the brief didn't name |
| Deliverable | A branch, a pull request, a `PROGRESS.md` entry with the status tables updated |

**Rules for every task**

* `./tool/tv_patch.sh apply` before analyze, test or build, and `revert` before committing.
* The checks are those of `tv-checks.yml`, plus the task's own tests.
* Device builds are `-Pdev` release builds, 32-bit for `<physical-tv>`. Never a debug build for a measurement.
* The device rules hold: 1080p first, the guard on, a go-ahead before the first run above 1080p in a session, `无痕模式` while signed in, arrow keys only near account actions, everything put back at the end.
* One branch per task, merged by hand after a green check. Nothing is pushed to `main`.
* `main` may hold a screen that hasn't passed its gate. A release is cut only after a gate.
* A task that replaces something deletes it once the gate has passed: the old route, and the adapters and tests that existed only for it.
* An executor verifies what it can without the TV: unit and widget tests, recorded paths, `<vm-tv>`. `<physical-tv>` is the planner's and the user's.

**First tasks, in outline** (the decisions are in; the briefs are written in full when the user says to start)

| Task | Goal | Checks | Device |
| :--- | :--- | :--- | :--- |
| `A0.1` | Merges build without publishing; syncs arrive as pull requests | The three cases in the task | None |
| `A0.2` | The hook count and the dependency list run in CI | A deliberate extra hook line fails the check | None |
| `A0.3` | The docs point at this plan | Markdown only | None |
| `M17.5` (part 1) | The seven additions to the spike, one rebuild, item 10 on `<vm-tv>` | The spike's own log lines for each addition | `<vm-tv>` |
| `A3.0` | The route and dependency inventory | Every named route and direct push has a row | None |
| `A3.1` | The focus kit, with its two founding tests first | The new tests; all existing TV tests still green | None |
