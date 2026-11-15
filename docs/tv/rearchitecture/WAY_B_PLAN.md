# Way B: A Native TV App From the Ground Up

> **Status** (2026-11-14): an outline. The user chose [Way A](./WAY_A_PLAN.md) for now; this way is planned in detail after Way A's planning is done. Nothing here is built.
> **Beside this file**: [`REARCHITECTURE.md`](./REARCHITECTURE.md) has the review, the requirements and the comparison. [`WAY_C_PLAN.md`](./WAY_C_PLAN.md) is the third way.
> **One user today** (2026-11-14): the repository's owner is the app's only user. So this way needs no staged rollout and no migration for anyone else: the new app replaces the old one on the user's TV when the user says so. What that postpones is in §10.
> **A note on size**: the session counts below are milestone-level guesses. Way A's count rose from 57 to 81 when it was planned task by task, and this one should be expected to rise the same way.

---

## 1. Shape

A new repository. Kotlin, one activity, Media3 on a `SurfaceView`, GPL-3.0 (it ports code from PiliPlus, which is GPL-3.0). No native libraries of its own, so one small APK covers every ABI, the 32-bit `<physical-tv>` included.

```
:app              the activity, navigation, wiring, update check
:core:model       plain data types
:core:net         HTTP client, app signing, WBI, cookies and tokens, device ids, error mapping
:core:api         one file per domain: feed, search, video, pgc, live, dynamics, user,
                  favourites, history, comments, messages
:core:proto       generated: danmaku segments, live packets, whatever has no JSON form
:core:store       settings, the account store (encrypted), small caches
:btr              the thread ripper: pure Kotlin, no Android
:btr-media3       the ripper as a Media3 DataSource
:player           the engine wrapper, the session state machine, stream and track rules,
                  heartbeat, SponsorBlock, subtitles
:danmaku          parsing, filters, the layout engine (pure Kotlin), the view
:ui:kit           theme, focus primitives, cards, rows, grids, dialogs, key handling
:feature:*        home, search, detail, playerui, live, dynamics, library, member,
                  comments, messages, settings, login
tools/            device scripts, api-watch
```

Rules the build enforces: a feature depends on `:ui:kit`, `:player`, `:core:*` and nothing else; nothing depends on a feature; `:btr`, the danmaku layout engine and the player's state machine have no Android imports. Those three are where the hard logic is, and an executor can test them fully without a device.

State is a `ViewModel` exposing a `StateFlow`, one direction only. Dependencies are passed by constructor from one container, with no injection framework.

## 2. The Player

```
playurl ─► StreamCatalog          every quality and codec the account and the device can play
        ─► one DASH manifest      built in memory from the stream list
        ─► DashMediaSource ─► BtrDataSource ─► OkHttp (always Range, 206 only)
                                         └─► direct fallback, same rules
        ─► ExoPlayer ─► SurfaceView (video plane)
PlaybackSession (state machine) ─► StateFlow ─► HUD, danmaku clock, heartbeat
```

* **One manifest holds every quality**, so a quality switch is a track selection, not a reopen. The reopen on every switch (2.9 s at 1080p and 5.2 s into 4K in `M17.4`) goes away.
* **The session is a state machine with one owner**: resolving, preparing, playing, paused, buffering, ended, failed with a reason. The HUD and danmaku only observe it. It has its own bounded retry and failure screen, which `M17.4` found missing.
* **Capability rules in one place**: the display's HDR types, the decoder list, the account's entitlements. A quality that can't play correctly isn't offered, or is refused with the reason. Dolby Vision Profile 5 only through a Dolby Vision decoder; Profile 8.4 through one, or as HLG and labelled so.
* **Carried over from M17**: Media3 1.11.1 (re-checked at the start), the default codec selector, no decoder fallback, the decoder released with the surface, a byte-sized buffer with no back buffer, tunneling off, audio focus and the route handled natively, a silent track reported.
* **Live uses the same engine.** On the video plane the "live above 1080p" hazard has no GPU path to reach.
* **Kept from today's HUD**: the M14 and M15 layout and action table, the virtual seek accumulator, Hold-Select for 3×, idempotent media keys.

## 3. Danmaku

Parsing, filtering and layout run off the UI thread, in a pure Kotlin engine: given a time and a viewport it returns what's on screen and where. The view only draws that. Golden tests pin the layout rules (lanes, collisions, top and bottom, density, merged duplicates) against recorded segments.

How the view draws is G2's question: a custom `View` with cached text, or a second surface drawn from its own thread. The first is simpler and is tried first.

Danmaku over HDR video is an SDR layer over an HDR plane, as in every TV app. The app can offer an HDR style preset (full opacity, heavier stroke). It can't draw danmaku in HDR.

## 4. The Thread Ripper

A Kotlin port of the Dart ripper (1,524 lines), checked against the existing parity fixtures, shaped as a Media3 `DataSource` instead of a loopback proxy. Its connections run on OkHttp's own threads, so P3 can't recur. The design notes written for the MyTVB + BTR plan describe this shape and are reused. No code comes from MyTVB or from Speed Boost, which have no licence.

Rules carried over: every request has `Range`; only 206 is success; hosts cool down after refusals; the "caught up" signal comes from the player's buffer.

## 5. The Interface

* **Focus is declared.** Each screen states its groups (rail, tabs, content, HUD rows) and what each remembers. M13's column memory is a per-list focus restorer. Dialogs and sheets trap focus by construction, which replaces the whole focus-layer stack.
* **M13's 25 recorded paths and 10 bugs become UI tests** for the new screens, so the behaviour you agreed to is kept.
* **Cheap by design**: cover images requested at the size they're shown, focus drawn as a layer effect with no relayout, stable keys, a baseline profile.
* **The toolkit** is Compose unless G1 says otherwise. The state layer doesn't know which toolkit draws it, so a grid can be a `RecyclerView` without changing a `ViewModel`.

## 6. Bilibili's API Without an Upstream to Merge

This is the cost Way B takes on, so it gets a design.

* **A thin layer, ported from PiliPlus.** Upstream's `lib/http/` is about 10,000 lines with 324 endpoints. The scope in [`REARCHITECTURE.md`](./REARCHITECTURE.md) §3 needs perhaps 70 to 90. Each Kotlin function names the Dart function it was ported from.
* **JSON first.** gRPC code, almost all generated, is 54 % of upstream's Dart. Where an endpoint has a JSON form it's used, and protobuf is kept for what has none (danmaku segments, live packets, and whatever `B1`'s study finds for comments and dynamics).
* **Contract tests** from recorded responses with accounts and ids removed, replayed by a mock server. A drift shows up as a failing test.
* **`tools/api-watch`**: a script that diffs upstream's API code (`lib/http/`, the signing helpers, the hand-written gRPC callers) between the last tag looked at and the newest, and writes a report. The planner turns each relevant change into a port task. Upstream stays the early warning without being merged.
* **Risk control**: device ids, tickets and WBI keys are ported as upstream has them. A captcha can't be solved with a remote, so the app says so and offers the QR login again.

## 7. Milestones

Sizes are executor sessions, estimated before any code exists. They'll be corrected after `B2`.

| Milestone | Content | Ends with | Size |
| :--- | :--- | :--- | :--- |
| **B1: Network and account** | Signing, TV QR login, the account store, the endpoints for home, search, video, playurl and danmaku, fixtures, `api-watch` | Contract tests green; a QR login on `<vm-tv>` | 8 |
| **B2: Interface kit and shell** | Theme, focus primitives, cards, grid, rail, tabs, dialogs; login screen; home (推荐, 热门); M13's paths as tests | G1's bar again, on the real home screen | 8 |
| **B3: Player v1** | Session, stream catalog, manifest, capability rules, fail closed, HUD v1, resume and heartbeat, danmaku v1, subtitles, speed, seek | 1080p and 4K60 on `<physical-tv>` through the LAN proxy; G2's bar | 12 |
| **B4: Thread ripper** | The port, parity tests, the `DataSource`, automatic concurrency, settings | A 4K60 soak with the proxy off | 8 |
| | **Usable every day from here.** It installs beside today's app under its own package id, so the user can move over when it suits and go back if something is missing | | |
| **B5: Video pages** | UGC and 番剧 pages, actions, comments, SponsorBlock, chapters, related, auto-next | Device pass | 10 |
| **B6: Library and following** | History, favourites, 稍后再看, dynamics feed and detail, member pages, search by type | Device pass | 10 |
| **B7: Live** | Lists, a room, the live source, live danmaku, SuperChat, the live HUD | Device pass, including 原画 | 8 |
| **B8: Player v2 and settings** | HDR and Dolby Vision polish, audio choices, editable HUD groups, 播放信息, every settings page, update check | HDR and audio pass, with you at the panel | 8 |
| **B9: The rest, and the switch** | Messages and articles if BD3 says so, what daily use has turned up, the old app retired | The new app is the only one on the TV | 5 |

**Total**: about 83 sessions with B0, and about 11 device sessions. At the pace of M13–M15 (roughly three tasks a day) that's five to seven weeks, set by device sessions and review more than by writing code. `:btr`, `:danmaku` and `:core:api` don't depend on each other and can run in parallel sessions.

## 8. Risks

| Risk | Answer |
| :--- | :--- |
| Compose is slow on this SoC | G1 in B0, before anything else. `RecyclerView` grids as the fallback, at no cost to the layers above |
| The API drifts and there's no upstream to merge | §6: a thin layer, contract tests, `api-watch` |
| The danmaku engine misbehaves under load | A pure engine with golden tests; G2 measures it before `B3` builds on it |
| The ripper port regresses | The existing parity fixtures; a soak in `B4` |
| Other TVs differ from `<physical-tv>` | Not a question while there's one user. Before the app is offered to others (§10): Media3's own device handling, SmartTube's list of workarounds, a device matrix |
| An executor drifts from the design over 80 sessions | Module rules the build enforces, small tasks, interfaces fixed in each brief, planner review of every pull request |

---

## 9. B0: Two Probes Before Anything Else

Two small native test apps, in the manner of M12's `probe_app.sh`. They're throwaway code that answers questions; nothing from them ships.

| Gate | Question | How | Bar |
| :--- | :--- | :--- | :--- |
| **G1: UI** | Is a native UI on `<physical-tv>` clearly better under a remote than Flutter is today? | A home screen with a side rail, tabs and a 4-column grid of real cover images from a public feed, a second screen with a long list, and a text field with the TV's keyboard. Built in Compose. If it misses the bar, the grid is rebuilt on `RecyclerView` and measured again before anything is concluded | A plain D-pad step, key press to frame, at or under 33 ms at p90 on the grid (today: 44 ms). At least 90 % of frames within 16.7 ms while a key is held (today on home: about 40 %). The keyboard takes D-pad keys with no proxy view |
| **G2: Player** | Does native Media3 on a `SurfaceView` do everything `M17.4` did, and what `M17.5` still asks? | Real streams fetched through the existing LAN proxy on the development machine, so no ripper port is needed yet (how the probe reaches it is `B0.4`'s first step; local files are the fallback). One DASH manifest built from a real stream list. A prototype danmaku view over the video. `M17.5`'s list, unless Way A has answered it by then: HDR 真彩, 杜比视界, HDR Vivid, 杜比全景声, subtitles | 4K60 AVC and AV1 for 10+ minutes each, at most 0.3 % dropped, the layer `DEVICE`, no freeze or shutdown. With heavy danmaku at 1080p, a UI frame at or under 10.3 ms at p50. A quality switch inside one manifest with no reload. By your eyes: the panel's HDR and Dolby Vision badges, sync, and whether danmaku is readable over HDR |

What B0 settles:

* **Both gates pass**: Way B can go ahead.
* **G2 passes and G1 fails on both toolkits**: a native interface isn't clearly better on this TV, and Way B loses its main reason.
* **G2 fails**: stop and look at why. `M17.4` passed on the same hardware, so a failure would mean something specific.

**Tasks** (outlined in §11): `B0.1` repository, skeleton and CI · `B0.2` device tools · `B0.3` UI probe · `B0.4` player probe · `B0.5` two device sessions · `B0.6` the gate, with you.
**Size**: 6 executor sessions and 2 device sessions.

---

## 10. The Switch, and What Waits for Other Users

**The switch.** From `B4` the new app is installed beside today's under its own package id. The user moves over when it's good enough for daily use, and the old app is retired in `B9`. Signing in again by QR is all the move takes. Nobody else has to be carried over.

**Postponed until the app is offered to others**, as a milestone of its own:

* Whether the new app takes over today's package id and signing key, so it would arrive as an update.
* A device matrix beyond `<physical-tv>` and `<vm-tv>`, and failure messages that make sense to a stranger.
* Checks required before a release, and release notes written for users.

**Decisions this way needs** (none is needed now)

| # | Decision | My default |
| :--- | :--- | :--- |
| BD1 | The new app's identity: repository name, app name, package id | The user's to choose |
| BD2 | The oldest Android to support | Android 6 (API 23) |
| BD3 | Messages and articles, view only: before the switch or after | After |
| BD4 | GPL-3.0 for the new repository, as porting from PiliPlus requires | Yes |

---

## 11. B0's Tasks, in Outline

| Task | Goal | Checks | Device |
| :--- | :--- | :--- | :--- |
| `B0.1` | A new repository with the module skeleton of §1, CI that builds and tests, and the dependency rules enforced | A clean build; a deliberate rule break fails CI | None |
| `B0.2` | The device guard, the step probe and the frame-time sampler, ported to work on a native app | Each runs against a stub app on `<vm-tv>` | `<vm-tv>` |
| `B0.3` | The UI probe of G1, with per-step timing in its log | Builds; D-pad paths pass on `<vm-tv>` | `<vm-tv>` |
| `B0.4` | The player probe of G2: a manifest from a real stream list, the `Range` rule, the prototype danmaku view, capability logging | Unit tests for the manifest builder and the capability rules; plays on `<vm-tv>` | `<vm-tv>` |
| `B0.5` | Two sessions on `<physical-tv>`: G1, then G2 with 1080p first | The bars in §9 | `<physical-tv>`, with the user |
| `B0.6` | The numbers against the bars, and the go or no-go | | |

---

## 12. Sources That May Be Read or Used

| Source | Licence | Use |
| :--- | :--- | :--- |
| PiliPlus (upstream and this fork) | GPL-3.0 | Way B ports its API layer and ripper, with credit |
| Bilibili-thread-ripper | MIT | The ripper's original logic |
| `androidx/media` | Apache-2.0 | The player; its `surface` demo |
| `aaa1115910/bv` | MIT | A Bilibili TV client on Media3: stream handling, codec choice |
| `moneytoo/Player` (Just Player) | Unlicense | The settings known to play 4K60 on `<physical-tv>` |
| `yuliskov/SmartTube` | MIT | Per-device workarounds, as a list |
| `jellyfin/jellyfin-androidtv` | GPL-2.0 | Ideas only; its licence doesn't mix with GPL-3.0 |
| MyTVB, MyTVB-Speed-Boost | None | Behaviour only; no code |
| The official TV app | Proprietary | Observed behaviour only; never modified |
