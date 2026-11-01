# M13.0: D-Pad Baseline and Focus Bug Inventory

**Status**: the six runs and the inventory's causes are done, on `<vm-tv>`. The budget below is a proposal that waits for the user, and the inventory stays open for bugs they remember.

M13 rebuilds the focus engine, but nobody has timed a D-pad step on a TV. The only figure, about 3.2 ms per step, came from a development Mac. So this task answers one question first: **how much of the lag is the engine's?** Anything that turns out to be something else, such as rendering, heavy upstream widgets or video decoding, becomes its own item instead of being folded into M13.

## The Device

**`<vm-tv>`** (the user's decision, 2026-10-31). The focus engine is the same code on any device, so the bug inventory, the recorded paths and the scorer can all be worked out there. `<physical-tv>` isn't needed for M13. Three limits follow:

* **Its times aren't the TV's.** It's an emulator on the development machine, with a different CPU and GPU. Use its numbers to compare builds and to see each part's share of a step. They can't show how a step feels on `<physical-tv>`, and its `raster` says nothing about that TV's GPU.
* **`PiliPlus TV dev` is signed in there**, since the user's QR login during M13.0. So playing a video changes that account's watch history, and Select on a `×` in 稍后再看 removes the video from the real list. Stay on arrow keys in those lists. A new login is the user's to do.
* **Hardware decoding doesn't work there.** The emulator's H.264 decoder takes the video and never outputs a frame, so the player stays on 加载中, and leaving it can freeze the app (see the ANR under Results). Turn `开启硬解` off for a playing run, and back on afterwards.

It's AVD `Television_4K`, arm64. It only starts with an explicit skin:

```bash
emulator -avd Television_4K -no-window -skin 3840x2160 -no-snapshot-save -no-boot-anim -no-audio
```

## The Build

A `-Pdev` release build with a logging patch, not a profile build. `flutter build --profile` inherits the `debug` build type, so it would install as a separate `.debug` app with no login, and it needs the VM service. A `-Pdev` build keeps the `PiliPlus TV dev` login, runs the same code as a real release, and is how M16 measured its frame times. If these numbers can't say where the time goes, a profile build with a timeline is the next step.

```bash
git apply tool/tv_m13/logging.patch
```

```bash
./tool/tv_patch.sh apply
```

```bash
ORG_GRADLE_PROJECT_dev=true flutter build apk --release --target-platform android-arm64
```

Then undo both before committing. The probe must never ship:

```bash
./tool/tv_patch.sh revert
```

```bash
git apply -R tool/tv_m13/logging.patch
```

The patch adds `lib/tv/tv_step_probe.dart`, and six hooks and an import in `lib/tv/tv_navigation.dart`. It works on `main` and on `variant/4k-passthrough`, which have the same `tv_navigation.dart`.

## What a Step Shows

Each D-pad key that moves the ring logs one line, in microseconds:

| Field | From | To | If it's large |
| :--- | :--- | :--- | :--- |
| `input` | Android's key event | Dart's key handler | The UI thread is busy |
| `decide` | Start of `inDirection` | Its result | The engine: the rule chain, M13.2 and M13.4 |
| `ring` | Dart's key handler | The ring's rect changes | The post-frame ring path |
| `wait` | The ring's rect changes | The next frame's build starts | Frame pacing, up to one frame is normal |
| `build` | Build start | Build end, on that frame | Heavy widgets, or the engine's per-frame work |
| `raster` | Raster start | Raster end, on that frame | Painting, not the engine |
| `total` | Android's key event | Raster end, on that frame | The whole step |

`work` is `decide + build + raster`, the app's own share. A key that moves no ring within a second logs `moved=0`, and those are left out of the times. With `handled=0` nothing lay in that direction. With `handled=1` focus did move, but the ring's rect didn't: the list scrolled under it, or the ring was already hidden.

Every 10 s it also logs frame times for that window, and `engine`: the time `_onPersistentFrame` takes on every frame, whether or not a key was pressed. A `[m13] clock` line checks the probe itself: `Timeline.now` taken just after a frame's `buildFinish`, minus that `buildFinish`, which is small and positive if the clocks agree.

## The Runs

On `<vm-tv>`, in `PiliPlus TV dev`. Get to each screen by hand with a screenshot first, because `run.sh` replays keys on whatever is showing.

| # | Name | Screen | Keys | Video |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `m13-home` | Home grid and sidebar | `right right right down down left left left left up up` | None |
| 2 | `m13-settings` | Settings, right pane | `down down down down down down up up up up up up` | None |
| 3 | `m13-detail-idle` | Video detail, related list | `down down down up up up` | Paused |
| 4 | `m13-detail-play` | The same | The same | Playing |
| 5 | `m13-comments-idle` | Video detail, comments | `down down down down up up up up` | Paused |
| 6 | `m13-comments-play` | The same | The same | Playing |

Home and settings have no video behind them, so "while a video plays" only applies to the last four. Runs 3 and 4 leave out `right left`: on the related list `right` moves nothing and `left` leaves the list, so one cycle would end the run outside it. Start each comments run on a comment, and check the pause by comparing two screenshots.

```bash
./tool/tv_m13/run.sh m13-home 120 right right right down down left left left left up up
```

```bash
./tool/tv_m13/steps.py m13-home m13-settings m13-detail-idle m13-detail-play m13-comments-idle m13-comments-play
```

Device rules that matter here:

* If a run ever moves to `<physical-tv>`, read `默认画质` first and stay at or below 1080P60. 4K on this path can shut that TV down.
* Keys only, never a swipe. `run.sh` refuses Back and Select.
* A D-pad press scrolls the page, so a run may reach the end of a list. Those keys log `moved=0`, which is why the key lists go both ways.

## Reading the Results

| What the numbers show | What it means |
| :--- | :--- |
| `decide` or `engine` is a large share of the frame | The engine is the problem, and M13.2 and M13.4 are the fix |
| `build` is large, `decide` and `engine` small | Upstream widgets rebuilding: its own item |
| `raster` is large | Painting on this GPU: its own item |
| `input` is large while a video plays | Decoding or danmaku is starving the UI thread: its own item |
| `ring` is about one frame longer on steps that scroll | `_onFocus` waits a frame before it moves the ring when a step scrolls, by design since M7 |

## The Budget

The budget is the time limit on one D-pad step. M13.5 won't switch to the new scorer unless it holds on `<vm-tv>`, so it decides whether the new engine ships.

The plan's target is a step within one frame, which is 16.7 ms at 60 Hz. A step can't end within one frame of the key press, because it has to wait for the next vsync. So the first proposal was `work` p90 at or under 16.7 ms and `total` p90 at or under 33.3 ms: two frames from key to pixels, leaving out the panel's own delay.

The runs show that can't be the gate on `<vm-tv>`. Four of the six runs miss it today, because of the emulator's `raster`, so it would block a new engine for something the engine doesn't do. The proposal, for the user to confirm, keeps those two figures as the goal for `<physical-tv>`, and gates M13.5 on the parts the engine controls:

| Measure | Runs | Limit | Today |
| :--- | :--- | :--- | :--- |
| `decide`, p90 | Idle | 2.5 ms, 15 % of a frame | 0.98–2.27 ms |
| `decide`, p99 | All six | 5 ms | 1.38–4.46 ms |
| `engine`, p90 | All six | 0.1 ms | 0.1 ms or less |
| `total`, p90, steps that don't scroll | Idle | 33.3 ms | 22.0–23.8 ms |
| `ring`, p50, steps that scroll | Idle | One frame, 16.7 ms | 12.1–14.5 ms |

These limits sit just above today's figures, so they stop the new engine from getting slower. They don't ask it to get faster, because the runs show little speed to win. Passing them proves the new engine isn't slower on `<vm-tv>`, not that a step meets the goal on `<physical-tv>`.

## Results, on `<vm-tv>`

These times compare builds and show each part's share. They aren't the TV's times. All are in ms. A plain step is one that doesn't scroll.

**Probe**: the key time arrived in milliseconds, in a field Dart reads as microseconds, so `logging.patch` now multiplies it by 1000 (`input` can read up to 1 ms long). `Timeline.now` taken just after each frame's `buildFinish` was always positive, 15 µs to 23 ms after it over about 9,400 frames, so the clocks agree. A `[m13] clock` line reports this. `moved=0 handled=1` means focus moved but the ring's rect didn't, because the list scrolled under it or the ring was already hidden. None of the six runs had one.

**Setup changes**: runs 3 and 4 use `down down down up up up`, because `right` moves nothing there and `left` leaves the list. `开启硬解` was off for the playing runs, because the emulator's H.264 decoder never output a frame, so they used software decoding on a software GPU. It's back on.

| Run | `decide` p50 / p90 | Engine per frame p50 | `work` p90 | `total` p50 / p90 | Plain steps `total` p90 | Scrolling steps `ring` p50 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `m13-home` | 0.82 / 1.19 | 0.02 | 6.0 | 16.4 / 23.7 | 23.7 | One step |
| `m13-settings` | 0.72 / 0.98 | 0.02 | 39.0 | 17.5 / 66.6 | 22.0 | 12.1 |
| `m13-detail-idle` | 1.09 / 1.40 | 0.02 | 3.9 | 16.5 / 23.5 | 23.5 | None |
| `m13-detail-play` | 0.49 / 1.01 | 0.02 | 69.3 | 107.8 / 144.2 | 143.4 | 4.9 |
| `m13-comments-idle` | 1.87 / 2.27 | 0.02 | 43.2 | 68.7 / 77.6 | 23.8 | 14.5 |
| `m13-comments-play` | 0.79 / 1.37 | 0.02 | 72.2 | 155.9 / 187.3 | 178.5 | 27.4 |

**The engine's share**: `decide` is 0.5–6 % of `total` on most runs, and at most about 10 % on the 29 plain steps of the comments run. On scrolling steps `ring`, including its one-frame wait by design, is 17–21 % of `total`. The per-frame cost is 0.02 ms, so M13.2 is justified by correctness, not speed. `<vm-tv>`'s software GPU inflates `raster`, so the share on a real GPU would be larger. `decide` would have to run about 7 times slower than here to fill a frame by itself, and `<vm-tv>` can't show whether the TV's CPU does.

**Not the engine, so its own items**:

* `raster` on `<vm-tv>`: 33–48 ms on any frame right after another frame, against 1.2 ms after idle. It's the software GPU, and painting on `<physical-tv>` remains unmeasured.
* Playing video on `<vm-tv>`: `total` 108–156 ms and `input` p99 up to 34 ms, on software decoding and a software GPU.
* An ANR: leaving a video stuck on 加载中 froze the app, with Android's main thread running Dart and blocked inside `libmpv`. Dart shares that thread with input, so any blocking mpv call also stops the D-pad.

## Bug Inventory

The user's list so far. They expect to add more as they remember it. Each one gets reproduced on `<vm-tv>` before it counts, and becomes a recorded path in M13.3.

| # | Screen | Steps | Expected | What happens | Kind | Reproduced | Cause |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 我的, with several sections on in `我的页卡片` (`稍后再看`, `观看记录` and so on) | Open 我的 and press Down through the sections | Focus carries on through every section, and the page scrolls to show it | Down from the `观看记录` header moves focus off screen: the ring disappears, the page stops scrolling, and nothing below it can be reached or seen | `stuck`, `lost ring` | Yes, on `<vm-tv>` | `_ensureVisibleInUserScrollables` reveals the same leaf in every scrollable, so the outer list never scrolls |
| 2 | 稍后再看, and pages with other floating controls | Try to reach `播放全部` from every card and `×` next to it, at the top and at the end of the list | Focus can land on `播放全部`, and Select plays the list | No key reaches it | `stuck` | Yes, on `<vm-tv>`, and on two more pages | The rules only accept a target outside the focused list, and a floating control sits over it |
| 3 | Video cards, such as the related list | Focus a card and press Right | Focus can land on the card's `⋮` | Right does nothing (`moved=0 handled=0`) | `stuck` | Yes, on `<vm-tv>`, in the related list. Found in M13.0 | The `⋮` is a `Stack` sibling of the card, so no rule offers it |
| 4 | 稍后再看 | Focus a `×` in the right column and press Up | Focus stays in its column | Focus lands on the left-column card of the same row | `jump` | Yes, twice, on `<vm-tv>`. Found in M13.0 | The rule compares the `×` with card centres, and that card's centre is above it |

Kind is `jump`, `lost ring`, `lag` or `stuck`. Bugs 1 and 2 were proven with throwaway builds on `<vm-tv>`. Those builds aren't on any branch, and M13.0 changes no app code.

**Bug 1**: `lib/pages/mine/view.dart` puts each section's horizontal list inside one vertical `ListView`. `_ensureVisibleInUserScrollables` walks up the scrollables, but passes the focused card to each one. `ensureVisible` then measures against the card's nearest viewport, the horizontal list, so the outer list gets the wrong offset and stays where it is. Focus goes off screen, `_computeFocusedRect` hides the ring, and `inDirection` pulls the off-screen rect back to the list's edge, so Down only bounces between cards in that row. The lead about lazy building was wrong: the section was built, and the page just didn't scroll to it.

Passing each level its own child, as `Scrollable.ensureVisible` does, fixed it on the device: Down reached every section with the ring visible, and all 95 TV tests passed. About six lines change, none of them in the rule chain. Other vertical pages with horizontal lists share this path (`live`, `pgc`, `search_panel`, the video introduction), but they weren't tested on the device.

**Bug 2**: `_findVerticalCandidate` looks inside the focused list first. Once that runs out, it needs a target at or past the list's bottom edge, and a floating control sits inside that edge. Going right needs a target past the focused rect's right edge, and cards run to the edge of the screen. Letting a control over the list count as below it put the ring on `播放全部` on the device, and all 95 TV tests passed. That proves the cause but isn't the fix, because the button could only be reached from the end of a 48-item list. The `AnimatedSlide` lead wasn't the cause: `enablePlayAll` defaults to on, and the button was fully on screen.

| Floating control | Result |
| :--- | :--- |
| 稍后再看 `播放全部`, comments reply button, WebDAV save | Reproduced on `<vm-tv>` |
| Button over a long list, over a two-column grid and over empty space below a short list, and a full-width bar over a list | Not reached in 1,500 random keys on the real engine. Reached with the diagnostic change |
| A button below the list, as a control | Reached without the change |
| `fav_detail`, `main_reply`, `article`, `dynamics_detail`, `music`, `dynamics_topic`, `dynamics_mention`, `follow`, `member_video`, `member_opus`, `bubble`, `blacklist`, `danmaku_block`, `live_dm_block`, `pgc_review`, `video/post_panel` | Same layout, not tested on the device. The account's only favourites folder is empty, so `fav_detail` shows no list there |

**Bug 3**: `lib/common/widgets/video_card/video_card_h.dart` puts the `⋮` beside the card's `InkWell` in a `Stack`, and `video_card_v.dart` does the same. The embedded-action rules only look at a card's children, and `_filterOutEmbeddedSecondaryActions` drops small buttons that sit inside a larger candidate. A 1,500-key test reached a `⋮` that's a child of the card, and not one that's a sibling. The diagnostic change for bug 2 doesn't help, so this is a separate cause.

**Bug 4**: going up, `_findVerticalCandidate` takes any target whose centre is above the focused rect's top. A `×` sits at the bottom of its row, so the neighbouring card in the same row counts as the row above.

## What These Runs Can't Show

* The panel's own delay. `total` ends when the frame is rasterized, not when it's lit.
* A held key. `run.sh` sends separate presses. Held keys repeat no faster than one step per 45 ms and one per frame, by design (`_kDirectionalRepeatMinIntervalMs`).
* Any comparison with `adb`'s own speed. `input keyevent` takes a few hundred ms per key, which sets the pace of a run, not the time of a step.
