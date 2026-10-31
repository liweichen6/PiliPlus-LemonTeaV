# M13.0: D-Pad Baseline and Focus Bug Inventory

**Status**: the tools are ready and checked off the device. No run has happened yet, so nothing below is a measurement.

M13 rebuilds the focus engine, but nobody has timed a D-pad step on a TV. The only figure, about 3.2 ms per step, came from a development Mac. So this task answers one question first: **how much of the lag is the engine's?** Anything that turns out to be something else, such as rendering, heavy upstream widgets or video decoding, becomes its own item instead of being folded into M13.

## The Device

**`<vm-tv>`** (the user's decision, 2026-10-31). The focus engine is the same code on any device, so the bug inventory, the recorded paths and the scorer can all be worked out there. `<physical-tv>` isn't needed for M13. Two limits follow:

* **Its times aren't the TV's.** It's an emulator on the development machine, with a different CPU and GPU. Use its numbers to compare builds and to see each part's share of a step. They can't show how a step feels on `<physical-tv>`, and its `raster` says nothing about that TV's GPU.
* **It isn't signed in.** A signed-out app shows no 稍后再看 or 观看记录 lists, and a video's own quality list stops at 1080P. A QR login is the user's to do.

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

`work` is `decide + build + raster`, the app's own share. A key that moves no ring within a second logs `moved=0`, and those are left out of the times.

Every 10 s it also logs frame times for that window, and `engine`: the time `_onPersistentFrame` takes on every frame, whether or not a key was pressed. That callback is what M13.2 replaces, and its cost has never been measured.

## The Runs

On `<vm-tv>`, in `PiliPlus TV dev`. Get to each screen by hand with a screenshot first, because `run.sh` replays keys on whatever is showing.

| # | Name | Screen | Keys | Video |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `m13-home` | Home grid and sidebar | `right right right down down left left left left up up` | None |
| 2 | `m13-settings` | Settings, right pane | `down down down down down down up up up up up up` | None |
| 3 | `m13-detail-idle` | Video detail, related list | `down down down up up up right left` | Paused |
| 4 | `m13-detail-play` | The same | The same | Playing |
| 5 | `m13-comments-idle` | Video detail, comments | `down down down down up up up up` | Paused |
| 6 | `m13-comments-play` | The same | The same | Playing |

Home and settings have no video behind them, so "while a video plays" only applies to the last four.

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

The plan's target is a step within one frame, which is 16.7 ms at 60 Hz. A step can't end within one frame of the key press, because it has to wait for the next vsync. So the proposal, to confirm once the numbers are in:

* **`work`, p90: 16.7 ms or less.** One frame of the app's own time.
* **`total`, p90: 33.3 ms or less.** Two frames from key to pixels, leaving out the panel's own delay.

M13.5 won't switch to the new scorer unless the budget holds on `<vm-tv>`. That proves the new engine isn't slower there, not that a step meets the budget on `<physical-tv>`.

## Bug Inventory

The user's list so far. They expect to add more as they remember it. Each one gets reproduced on `<vm-tv>` before it counts, and becomes a recorded path in M13.3.

| # | Screen | Steps | Expected | What happens | Kind | Reproduced | Cause |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 我的, with several sections on in settings (`稍后再看`, `观看记录` and so on) | Open 我的 and press Down through the sections | Focus carries on through every section, and the page scrolls to show it | Focus stops at the `观看记录` header, the page stops scrolling, and nothing below it can be reached or seen | `stuck` | Not yet. Seen on `<physical-tv>`, and needs a login on `<vm-tv>` | Unknown |

Kind is `jump`, `lost ring`, `lag` or `stuck`.

**Lead on 1, not confirmed**: `lib/pages/mine/view.dart` puts each section in one vertical `ListView`, which builds lazily, and each section holds a horizontal list of cards. A section past the build range has no focus nodes, so the engine may see nothing below the header. The user's screenshots of this page also show one state with no ring at all, which may be a second symptom.

## What These Runs Can't Show

* The panel's own delay. `total` ends when the frame is rasterized, not when it's lit.
* A held key. `run.sh` sends separate presses. Held keys repeat no faster than one step per 45 ms and one per frame, by design (`_kDirectionalRepeatMinIntervalMs`).
* Any comparison with `adb`'s own speed. `input keyevent` takes a few hundred ms per key, which sets the pace of a run, not the time of a step.
