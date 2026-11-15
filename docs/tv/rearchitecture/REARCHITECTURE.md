# PiliPlus TV: Architecture Review and the Three Ways Forward

> **Status** (2026-11-14): the review is done, and the user chose **Way A for now**, with its decisions settled. Ways B and C are planned further once Way A's planning is done. Nothing is built.
> **Parked** (2026-11-15): the user moved this folder aside; it's for much later. [`PLAN.md`](../PLAN.md) works on M17 now, and nothing here starts until the user brings it back.
> **Privacy**: the rules of [`PLAN.md`](../PLAN.md) hold here too. No addresses, serials, local paths or account details; devices are `<physical-tv>` and `<vm-tv>`.

| File | What it holds |
| :--- | :--- |
| This file | What the review found, the requirements, the principles, and the comparison |
| [`WAY_A_PLAN.md`](./WAY_A_PLAN.md) | **Way A**, a new TV architecture on upstream PiliPlus. Planned task by task |
| [`WAY_B_PLAN.md`](./WAY_B_PLAN.md) | **Way B**, a native TV app from the ground up. An outline |
| [`WAY_C_PLAN.md`](./WAY_C_PLAN.md) | **Way C**, a private fork of MyTVB. A comparison entry |

---

## 1. The Short Version

* **What's wrong is structural.** The TV interface is inferred from a touch app instead of designed; the player draws through the one path this TV can't take above 1080p; everything shares the UI thread; and the fork carries a phone app it no longer needs. §2.2 has each with its evidence.
* **Three ways were compared** (§6). The review's own recommendation was Way B behind two device gates, with Way A as the fallback.
* **The user's choice on 2026-11-14 is Way A for now.** Its plan has a gate early on (`GA3` in [`WAY_A_PLAN.md`](./WAY_A_PLAN.md)) that measures a purpose-built screen on `<physical-tv>`. That number is also the best evidence for or against Way B, so the question is settled by measurement either way.

---

## 2. What the Review Found

Read for this review: everything in `docs/tv/`, `lib/tv/`, the Kotlin bridge, the uncommitted `M17.4` spike, upstream's player, router and controllers, the notes from the official TV app's analysis, the LAN proxy experiment, and the private MyTVB + BTR fork plan.

### 2.1 What Works and Carries Over to Any Way

| Asset | Where it is | Use in a rebuild |
| :--- | :--- | :--- |
| What `<physical-tv>` needs from a player: video plane only above 1080p, at most 2 held frames, GPU-drawn 4K60 panics it | `M12_CRASH_DEBUG.md`, `PLAN.md` M12 | Product rules, not history |
| Media3 settings proven on this TV: 1.11.1, no decoder fallback, decoder released with the surface, a byte-sized buffer, tunneling off, the Dolby Vision decoder rule, fail closed | `M17_MEDIA3_STUDY.md`, `PROGRESS.md` `M17.4` | The player's starting configuration |
| The HUD's design: layout, editable groups, the action table, live entries | `lib/tv/tv_hud_*.dart`, `PLAN.md` M14–M15 | A: the code. B: the specification |
| How D-pad focus should behave: 25 recorded paths, column memory, the bug inventory | `test/tv_paths_test.dart`, `M13_BASELINE.md` | Acceptance tests for any new UI |
| The thread ripper's logic, with parity fixtures | `lib/services/thread_ripper/`, `tool/generate_ripper_resolver_fixture.cjs` | A: moved off the UI thread. B: ported to Kotlin against the fixtures |
| CDN behaviour: 567 without `Range`, 403 without a Referer, about 0.3–0.55 MB/s per connection | `PROGRESS.md` `M17.4` | Rules for every HTTP client that fetches media |
| How to measure: the D-pad step probe, the frame-time protocol, the device guard | `tool/tv_m13/`, `PLAYBACK_PARAMETERS.md`, `tool/tv_m16/` on the variant | Ported once, used at every gate |
| Process: one branch per task, release on merge, checks that block a release, the device rules | `PLAN.md` Execution Rules | Unchanged |

### 2.2 The Structural Problems

These are causes, not bugs. Each one has been worked around at least once, and each workaround is now code to maintain.

**P1. The TV interface is inferred, not designed.** Upstream's pages are built for touch. The focus engine (about 5,100 lines in `tv_navigation.dart`, `tv_focus_layers.dart`, `tv_focus_scorer.dart` and the adapters), four TV patch files for the Flutter SDK and 14,100 lines of TV tests exist to guess, from widget types and rectangles, what a remote should do on a page nobody designed for one. M6, M7, M9, M10 and M13 each fixed a new upstream layout. After M13's rebuild a D-pad step on `<physical-tv>` still takes 37 ms at the median on home and 67 ms on comments during playback, and most of that isn't the engine's: home's raster alone is 15 ms, in upstream widgets the TV layer has promised not to touch.

**P2. The player path works against the platform.** mpv draws into a Flutter texture, which the GPU composites. On this TV that path deadlocks at 4K, can shut the TV down, and is SDR by construction. The fix is Media3 on the video plane, and `M17.4` proved it, but inside this app it takes a class that implements mpv's player interface, a transparent Flutter surface with a hole painted in it, a rule that a player's kind is fixed when it's made, and mpv kept for live rooms. Two players and two view paths, for as long as the app lives.

**P3. Everything shares one thread.** Dart's UI isolate is Android's main thread. Danmaku layout, every chunk the thread ripper forwards (up to 64 connections) and mpv's synchronous calls all run where key presses are handled. `input` reaches 17–19 ms at p90 while a video plays, and a blocked mpv call is an ANR.

**P4. The fork's economics.** Of 465,744 lines of Dart, 249,217 are gRPC code, almost all of it generated, and about 100,000 are pages, most of which a TV never opens. Thirty-eight SDK patches are re-checked on every Flutter bump. Every release also ships upstream's newest code, which nobody tested on a TV. The rule that kept merges clean (under 30 lines in upstream's Dart files) is also what forces the indirection in P1 and P2. There are three lines of code to keep alive: `main`, `variant/4k-passthrough` and the spike.

**P5. A goal that no longer applies.** "One APK for TVs and phones" shaped every decision above. Your answer on 2026-11-14 is TV only.

### 2.3 Why Now

* M12 showed the TV demands the video plane.
* `M17.4` showed Media3 on the video plane plays 4K60 in this app with 0.06–0.18 % of frames dropped, and that a native surface under the UI costs no more than the texture did (10.3 ms against 11.4 ms per frame with heavy danmaku).
* The official TV app, unmodified, plays smoothly on the same TV once its traffic goes through the thread ripper as a LAN proxy. So a native pipeline plus the ripper is enough on this hardware.
* M17's build tasks (`M17.7`–`M17.12`) haven't started. This is the last point where nothing has to be undone.

---

## 3. Requirements

From your answers on 2026-11-14.

| | |
| :--- | :--- |
| **Audience** | Android TV only; phones are left to upstream PiliPlus. Meant for public release, but the repository's owner is the only user today. So nothing has to be staged or migrated for anyone else, and each plan lists what waits until there are other users |
| **Drivers** | D-pad feel and focus; playback; maintenance load. App weight is not a driver |

**In scope**

| # | Screen or function | Notes |
| :--- | :--- | :--- |
| S1 | QR login, account switch, sign out | TV QR flow only |
| S2 | Home: 推荐, 热门, 番剧 and 影视, 直播 | |
| S3 | Search, with results by type | Text entry through the TV's keyboard |
| S4 | Video page (UGC): intro, parts, related | |
| S5 | 番剧 and 影视 page: seasons, episodes | |
| S6 | Player with HUD | Quality, codec, speed, subtitles, audio, danmaku settings, SponsorBlock, chapters, 4K, HDR, Dolby Vision |
| S7 | Danmaku: display, filters, settings | Sending is out |
| S8 | Comments: read, with replies | Posting is out |
| S9 | Actions: like, coin, favourite, triple-like, follow, 稍后再看 | |
| S10 | Dynamics feed and a dynamic's detail | The one place for updates from followed accounts |
| S11 | History, favourites, 稍后再看 | |
| S12 | Member pages: videos, collections | |
| S13 | Live: lists, a room, live danmaku, SuperChat | |
| S14 | Thread ripper (BTR), with its settings | |
| S15 | Settings (the TV's subset), about, update check | |
| S16 | Messages and articles, view only | "Maybe" in your answer: decision AD8 in Way A's plan |

**Out of scope**: the phone and tablet UI, sending danmaku, comments or messages, creating dynamics, downloads, DLNA casting from the app, WebDAV, audio-only pages, desktop builds.

---

## 4. Principles for the New Architecture

They hold for every way. Each answers a problem in §2.2.

1. **TV screens are designed for a remote.** Focus order is declared by the screen, not inferred from it. (P1)
2. **Video always goes to the video plane, through one player engine.** No texture path, so no rule about which qualities are safe on which path. (P2)
3. **Nothing heavy on the UI thread**: no network forwarding, no danmaku layout, no parsing. (P3)
4. **Upstream PiliPlus is an input, not ground we may not touch.** Way A merges it on purpose, by pull request. Way B reads it as the reference for Bilibili's API. (P4)
5. **Fail closed.** A stream the device can't play correctly is refused with a message. It's never retried on a path known to be unsafe.
6. **Gates before code.** The planner writes each milestone's device bar, with numbers, before the executor writes the milestone's code.
7. **One release line.** No variant branches.

---

## 5. The Three Ways

**Way A: on upstream PiliPlus.** Stay a fork. Replace the retrofit with a TV shell: the fork's own screens on upstream's data layer and controllers, Media3 on the video plane as the TV's player, upstream merged by pull request. The old focus engine becomes a fallback lane that shrinks screen by screen. → [`WAY_A_PLAN.md`](./WAY_A_PLAN.md)

**Way B: from the ground up.** A new repository and a native Android TV app: Kotlin, Media3 on a `SurfaceView`, a declared-focus interface, the thread ripper as a Media3 data source, and Bilibili's API ported from PiliPlus and kept current by watching upstream's diffs. → [`WAY_B_PLAN.md`](./WAY_B_PLAN.md)

**Way C: a private fork of MyTVB.** An existing native client with the thread ripper added. It has no licence, so it can't be published. → [`WAY_C_PLAN.md`](./WAY_C_PLAN.md)

---

## 6. Comparison

| | Today | Way A | Way B | Way C |
| :--- | :--- | :--- | :--- | :--- |
| **D-pad feel** | 37–67 ms a step; heuristics | Declared focus on rebuilt screens; Flutter's floor stays. `GA3` measures it | Native focus. Its gate `G1` measures it | Native |
| **4K, HDR, Dolby Vision** | No (4K on a variant) | Yes, through an adapter and a transparent surface | Yes, the platform's normal path | Yes, unverified on this TV |
| **Live above 1080p** | Unsafe on this TV | After its own spike | Same engine as video | Yes |
| **Ongoing maintenance** | Syncs, 38 patches, hooks, 3 lines of code | Syncs by pull request, 34 patches, a shell that depends on upstream's controllers | Own code only | A faster upstream than today's |
| **Bilibili API upkeep** | Upstream's, by merge | Upstream's, by merge | Ours, by watching upstream | MyTVB's, by merge |
| **Everything PiliPlus has** | Yes | Yes, through the legacy lane | No: the 16 screens in §3 | No |
| **Public release, later** | Yes | Yes | Yes | **Never**: no licence. Fine while private |
| **Work reused** | | HUD, the M17 adapter, the bridge, the tests | Specifications, rules, fixtures, tools | Little |
| **First benefit** | | Media3 as the TV's player, at `M17.12` | Usable every day after its fourth milestone | Soonest |
| **Size** | | About 81 sessions, counted task by task | About 83 at milestone level; expect more when detailed | Its own plan, about 35 tasks |
| **Largest risk** | | `GA3`; upstream's video controllers outside their page | API upkeep; the amount to build | A dead end if the app is ever to be public |

**When each is the right choice**

* **A**: when everything PiliPlus has should stay reachable, when the first improvement should come soon, and if `GA3` shows a purpose-built Flutter screen is fast enough on this TV.
* **B**: when the end state matters most (no patches, no hooks, no second player, no code the project doesn't own), and if `GA3` misses its bar.
* **C**: when a native app is wanted soonest and the app will stay private. It can't become the public one.

---

## 7. In-Flight Work Under the Chosen Way

| Item | What happens |
| :--- | :--- |
| `M17.5`–`M17.12` | Continue, as milestone A1 of Way A, with the changes listed there |
| M18 and `variant/4k-passthrough` | M18 is closed. The variant is retired when Media3 becomes the TV's default, at `M17.12` |
| The `M17.4` spike (a git stash) | Kept. `M17.5` runs on it |
| Today's app on `main` | A merge no longer publishes once `A0.1` is done; a release is cut on purpose, after a gate |
| The official app through the LAN proxy | Stays the user's stopgap |
| The private MyTVB + BTR plan | Paused. It's Way C |

Way A's decisions, all settled on 2026-11-14, are in [`WAY_A_PLAN.md`](./WAY_A_PLAN.md) §9.
