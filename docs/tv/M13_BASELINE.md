# M13.0: D-Pad Baseline and Focus Bug Inventory

**Status**: the tools are ready and checked off the device. No run has happened on `<physical-tv>` yet, so nothing below is a measurement.

M13 rebuilds the focus engine, but nobody has timed a D-pad step on the TV. The only figure, about 3.2 ms per step, came from a development Mac. So this task answers one question first: **how much of the lag is the engine's?** Anything that turns out to be something else, such as rendering, heavy upstream widgets or video decoding, becomes its own item instead of being folded into M13.

## The Build

A `-Pdev` release build with a logging patch, not a profile build. `flutter build --profile` inherits the `debug` build type, so it would install as a separate `.debug` app with no login, and it needs the VM service. A `-Pdev` build keeps the `PiliPlus TV dev` login, runs the same code as a real release, and is how M16 measured its frame times. If these numbers can't say where the time goes, a profile build with a timeline is the next step.

```bash
git apply tool/tv_m13/logging.patch
```

```bash
./tool/tv_patch.sh apply
```

```bash
ORG_GRADLE_PROJECT_dev=true flutter build apk --release --target-platform android-arm
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

`work` is `decide + build + raster`, the app's own share. A key that moves no ring within a second logs `moved=0`, and those are left out of the times.

Every 10 s it also logs frame times for that window, and `engine`: the time `_onPersistentFrame` takes on every frame, whether or not a key was pressed. That callback is what M13.2 replaces, and its cost has never been measured.

## The Runs

On a warm `<physical-tv>`, in `PiliPlus TV dev`. Get to each screen by hand with a screenshot first, because `run.sh` replays keys on whatever is showing.

| # | Name | Screen | Keys | Video |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `m13-home` | Home grid and sidebar | `right right right down down left left left left up up` | None |
| 2 | `m13-settings` | Settings, right pane | `down down down down down down up up up up up up` | None |
| 3 | `m13-detail-idle` | Video detail, related list | `down down down up up up right left` | Paused |
| 4 | `m13-detail-play` | The same | The same | Playing at 1080P60 |
| 5 | `m13-comments-idle` | Video detail, comments | `down down down down up up up up` | Paused |
| 6 | `m13-comments-play` | The same | The same | Playing at 1080P60 |

Home and settings have no video behind them, so "while a video plays" only applies to the last four.

```bash
./tool/tv_m13/run.sh m13-home 120 right right right down down left left left left up up
```

```bash
./tool/tv_m13/steps.py m13-home m13-settings m13-detail-idle m13-detail-play m13-comments-idle m13-comments-play
```

Device rules that matter here:

* Read `默认画质` before playing anything, and stay at or below 1080P60. Never pick 4K: on this path it can shut the TV down.
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

The plan's target is a step within one frame, which is 16.7 ms on this 60 Hz panel. A step can't end within one frame of the key press, because it has to wait for the next vsync. So the proposal, to confirm once the numbers are in:

* **`work`, p90: 16.7 ms or less.** One frame of the app's own time.
* **`total`, p90: 33.3 ms or less.** Two frames from key to pixels, leaving out the panel's own delay.

M13.5 won't switch to the new scorer unless the budget holds on `<physical-tv>`.

## Bug Inventory

Waiting for the user's list of screens where focus jumps or the ring disappears, with the steps if remembered. Screen recordings help. Each one gets reproduced on `<physical-tv>` before it counts, and becomes a recorded path in M13.3.

| # | Screen | Steps | Expected | What happens | Kind | Reproduced | Cause |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| | | | | | | | |

Kind is `jump`, `lost ring` or `lag`.

## What These Runs Can't Show

* The panel's own delay. `total` ends when the frame is rasterized, not when it's lit.
* A held key. `run.sh` sends separate presses. Held keys repeat no faster than one step per 45 ms and one per frame, by design (`_kDirectionalRepeatMinIntervalMs`).
* Any comparison with `adb`'s own speed. `input keyevent` takes a few hundred ms per key on the TV, which sets the pace of a run, not the time of a step.
