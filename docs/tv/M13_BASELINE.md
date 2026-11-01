# M13.0: D-Pad Baseline and Focus Bug Inventory

**Status**: ✅ Done. The six runs are done on `<vm-tv>` and on `<physical-tv>`, the inventory's causes are done on `<vm-tv>`, and the user confirmed the budget below on 2026-11-01. The inventory stays open for bugs they remember.

M13 rebuilds the focus engine, but nobody has timed a D-pad step on a TV. The only figure, about 3.2 ms per step, came from a development Mac. So this task answers one question first: **how much of the lag is the engine's?** Anything that turns out to be something else, such as rendering, heavy upstream widgets or video decoding, becomes its own item instead of being folded into M13.

## The Device

**`<vm-tv>`** (the user's decision, 2026-10-31). The focus engine is the same code on any device, so the bug inventory, the recorded paths and the scorer can all be worked out there. `<physical-tv>` had one bench on 2026-11-01, at the user's request, to set the budget on real hardware. Three limits follow for `<vm-tv>`:

* **Its times aren't the TV's, and neither are its shares.** It's an emulator on the development machine, with a different CPU and GPU. Use its numbers to compare builds. The bench showed they also understate the engine's share of a step, so only `<physical-tv>` can judge speed.
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

* On `<physical-tv>`, read `默认画质` first and stay at or below 1080P60. 4K on this path can shut that TV down. Build with `--target-platform android-arm`, because that TV is 32-bit. `PiliPlus TV dev` isn't signed in there. Put it to sleep last, because it stops answering `adb` while it's asleep.
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

The budget is the time limit on one D-pad step. M13.5 won't switch to the new scorer unless it holds, so it decides whether the new engine ships. These limits come from the `<physical-tv>` bench, and the user confirmed them on 2026-11-01.

**The goal** stays: `work` p90 at or under 16.7 ms and `total` p90 at or under 33.3 ms. A step can't end within one frame of the key press, because it has to wait for the next vsync, so `total` allows two frames, leaving out the panel's own delay. Today settings and the paused detail page meet the `work` half, and no run meets the `total` half. It can't be the gate, because on home `raster` alone takes 15.3 ms, and while a video plays `input` and `raster` each reach about 19 ms at p90. Neither is the engine's.

**The gate** for M13.5 covers what the engine controls, on `<physical-tv>`:

| Measure | Runs | Limit | Today | Holds today |
| :--- | :--- | :--- | :--- | :--- |
| `decide`, p90 | Home, settings, both paused runs | 6 ms | 2.89–7.65 ms | All but comments paused |
| `decide`, p99 | All six | 16.7 ms, one frame | 3.33–20.59 ms | All but comments playing |
| `engine`, p50 | All six | 0.1 ms | 0.07–0.09 ms | Yes |
| `work`, p90 | Settings, both paused runs | 16.7 ms | 8.7, 14.0, 17.8 ms | All but comments paused |
| `total`, p90, steps that don't scroll | Settings, detail paused | 35 ms | 30.9, 34.7 ms | Yes |
| `total`, p90, steps that scroll | Comments paused | 55 ms | 70.3 ms | No |

Four of these limits fail today, so they ask the new engine to be faster, not just no slower. `decide` at 6 ms leaves room for `build` and `raster` inside one frame on comments, which also brings `work` under 16.7 ms there. The last limit is the one nobody has shown can be reached: it needs the ring to move in the frame that scrolls, which it has deliberately not done since M7. If M13.2 can't do that, the limit falls back to 72 ms, no worse than today.

Home and the playing runs are outside the `work` and `total` limits until their own items below are fixed.

M13.5 needs one more bench on `<physical-tv>`, with the same six runs and the rules above. The day-to-day work stays on `<vm-tv>`, where idle `decide` runs 3.4–4.6 times faster than on the TV, so `decide` p90 at or under 1.75 ms there is a fair stand-in. It isn't while a video plays, when the ratio is 10–12.

## Results, on `<physical-tv>`

One bench on 2026-11-01, on a warm TV with normal thermal status, at the 1080P 60帧 default, signed out, and with the same clean probe as `<vm-tv>`. Hardware decoding worked, on a video with about 1,900 danmaku. There was no `gdec:1`, ANR or `moved=0 handled=1`. All times are in ms. The clocks hold here too: a sample taken just after `buildFinish` was always positive, 98 µs to 10.7 ms after it, over 20,841 frames.

| Run | Steps | `decide` p50 / p90 / p99 | Engine per frame p50 | `raster` p50 / p90 | `input` p50 / p90 | `work` p90 | `total` p50 / p90 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `m13-home` | 154 | 2.84 / 3.48 / 4.21 | 0.08 | 15.3 / 17.0 | 5.3 / 6.1 | 21.3 | 37.4 / 41.9 |
| `m13-settings` | 212 | 2.44 / 2.89 / 3.33 | 0.07 | 3.7 / 4.5 | 5.2 / 6.0 | 8.7 | 28.8 / 34.4 |
| `m13-detail-idle` | 209 | 5.02 / 5.83 / 6.28 | 0.08 | 6.0 / 6.9 | 5.7 / 6.7 | 14.0 | 27.7 / 34.7 |
| `m13-detail-play` | 192 | 5.08 / 8.24 / 11.02 | 0.08 | 9.5 / 18.4 | 9.3 / 18.8 | 27.7 | 34.2 / 54.1 |
| `m13-comments-idle` | 207 | 6.64 / 7.65 / 8.65 | 0.09 | 6.3 / 8.3 | 5.6 / 7.0 | 17.8 | 54.7 / 70.3 |
| `m13-comments-play` | 185 | 9.40 / 13.94 / 20.59 | 0.09 | 9.0 / 18.8 | 9.6 / 16.7 | 33.8 | 66.7 / 90.8 |

Each part's share of `total`, in percent:

| Run | `input` | `decide` | `ring` past `decide` | `wait` | `build` | `raster` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `m13-home` | 15 | 8 | 2 | 28 | 4 | 42 |
| `m13-settings` | 21 | 10 | 8 | 40 | 6 | 15 |
| `m13-detail-idle` | 21 | 18 | 3 | 30 | 5 | 22 |
| `m13-detail-play` | 29 | 16 | 4 | 9 | 8 | 30 |
| `m13-comments-idle` | 11 | 12 | 41 | 19 | 4 | 12 |
| `m13-comments-play` | 15 | 15 | 30 | 15 | 5 | 16 |

**The engine's share**: `decide` is 8–18 % of a step, against 0.5–6 % on `<vm-tv>`. On the worst step it takes more than a frame by itself. Where a step scrolls, the ring path is the larger part: with `decide`, it's 45–53 % of a step on comments, against 10–21 % on the four runs that barely scroll. The per-frame cost is still only 0.08 ms. So M13 does have a speed case, in `decide` and in the ring path, but not in the per-frame callback.

**Steps that scroll**: a step counts when `ring` runs at least 3 ms past `decide`. That's every comment step and 35 of the settings steps. `ring` runs 10.5 ms past `decide` on settings, and 21–25 ms on comments. The probe can't split that further: part is the wait for the frame, and the rest is that frame's work, which on comments includes laying out upstream's cards.

**Against `<vm-tv>`**: idle `decide` takes 3.4–4.6 times as long here, and 10–12 times as long while a video plays. `raster` goes the other way: the emulator's 33–48 ms is 4–10 ms on this GPU, and 15 ms on the home grid.

**Not the engine, so its own items**:

* Painting the home grid: `raster` takes 15.3 ms, 42 % of a step, and 59.5 % of that run's frames are over 16.7 ms. Settings, mostly text, takes 3.7 ms. This alone keeps home over the goal.
* Video and danmaku on the UI thread: `input` reaches 17–19 ms at p90 and 27–40 ms at p99, and `raster` 18–19 ms at p90. `decide` also runs up to 1.4 times slower. The UI still holds 57–58 fps.
* An ANR, from `<vm-tv>`: leaving a video stuck on 加载中 froze the app, with Android's main thread running Dart and blocked inside `libmpv`. Dart shares that thread with input, so any blocking mpv call also stops the D-pad. It didn't happen on `<physical-tv>`, where hardware decoding works.

**Not from these runs**: `run.sh`'s `C2BqBuffer failures` count comes from a thread in the TV's codec service, which had been retrying since about 13 minutes after the TV started, 9.4 hours before the bench. It used 6 % of one core, and `dumpsys media.player` answered in 0.14 s, so it isn't the M16.3 hang. Its cause is unknown. The TV's load average of about 20 is kernel threads waiting, and the CPU was 88 % idle in the one sample taken.

## Results, on `<vm-tv>`

These times compare builds. They aren't the TV's times. All are in ms. A plain step is one that doesn't scroll.

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

**The engine's share here**: `decide` is 0.5–6 % of `total` on most runs, and at most about 10 % on the 29 plain steps of the comments run. On scrolling steps `ring`, including its one-frame wait by design, is 17–21 % of `total`. The per-frame cost is 0.02 ms. This understates the engine, because the emulator's CPU is faster and its software GPU inflates `raster`, so use the `<physical-tv>` results for the answer.

**Limits of these numbers**:

* `raster`: 33–48 ms on any frame right after another frame, against 1.2 ms after idle. That's the software GPU.
* Playing video: `total` 108–156 ms and `input` p99 up to 34 ms, on software decoding and a software GPU.

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

The fix is to pass each level its own child, as `Scrollable.ensureVisible` does. It's about six lines in `_ensureVisibleInUserScrollables`, none of them in the rule chain, and it's task `M13.0a` in `PLAN.md`:

```diff
+    BuildContext current = context;
+    RenderObject? firstTarget;
     ScrollableState? scrollable = Scrollable.maybeOf(context);
     while (scrollable != null) {
       if (_canUserScroll(scrollable)) {
-        final RenderObject? target = context.findRenderObject();
+        final RenderObject? target = current.findRenderObject();
         ...
           scrollable.position.ensureVisible(
             ...
             alignmentPolicy: alignmentPolicy,
+            targetRenderObject: firstTarget,
           );
+          firstTarget ??= target;
         ...
       final BuildContext scrollableContext = scrollable.context;
+      current = scrollableContext;
```

With this change alone, a widget test of the layout brought every section into view, and all 95 TV tests passed. On `<vm-tv>`, Down reached every section with the ring visible, but that build also carried the diagnostic change for bug 2, so `M13.0a` needs its own device pass. Other vertical pages with horizontal lists share this path (`live`, `pgc`, `search_panel`, the video introduction), and they weren't tested on the device.

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
* The remote's own delay. `total` starts at Android's key event.
* A held key. `run.sh` sends separate presses. Held keys repeat no faster than one step per 45 ms and one per frame, by design (`_kDirectionalRepeatMinIntervalMs`).
* Any comparison with `adb`'s own speed. `input keyevent` takes a few hundred ms per key, which sets the pace of a run, not the time of a step.
