# Playback Parameters on the Video Plane

What was tried on `<physical-tv>` (MediaTek MT9690) to make 4K60 play well on the video plane, what each option did, and which ones became settings. These are the numbers behind `TvVideoPlane`'s defaults. The story around them is in [`PROGRESS.md`](./PROGRESS.md) (M16) and [`M12_CRASH_DEBUG.md`](./M12_CRASH_DEBUG.md).

Every number comes from one TV, in one session. Treat them as a comparison, not a guarantee for other TVs.

## How It Was Measured

* **Setup**: a `-Pdev` release build with [`tool/tv_m16/logging.patch`](https://github.com/liweichen6/PiliPlus-LemonTeaV/blob/variant/4k-passthrough/tool/tv_m16/logging.patch) applied, a warm TV, real bilibili streams through the thread ripper, and danmaku on. Each option ran on a fresh start, 90 s measured after 30 s of settling.
* **mpv's counter**: `frame-drop-count`, as a share of the frames due at 59.94 fps.
* **What reached the screen**: `dumpsys SurfaceFlinger --latency` on the video layer gives the time each frame was presented, 127 frames at a time, sampled 8 times per run. `Layer fps` is their average. `Long intervals` is the share of gaps over 25 ms, against 16.7 ms for a clean frame.
* **Why both**: mpv's counter can be switched off without fixing anything (`framedrop=no`, below), and the layer's timing can't.
* **Path check**: every run on this page had `hwRender:1, gdec:0` in the decoder's log, with the 4K layer composed as `DEVICE`.

## Results

### 4K60 AV1, Real Stream

| mpv option | mpv dropped | Layer fps | Long intervals | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| Baseline, `video-sync=display-resample` | 8.0 % | 52.0 | 10.3 % | |
| The same, repeated at the end of the batch | 5.7 % | 52.2 | 9.7 % | The drift between identical runs is about 2 points |
| `video-sync=audio` | 7.2 % | 52.7 | 9.3 % | No effect |
| `video-latency-hacks=yes` | 7.0 % | 52.0 | 11.0 % | No effect |
| `framedrop=no` | 0 % | 54.4 | 10.3 % | Hides the drops: the layer barely moves |
| `vd-queue-enable=yes`, 1 frame | 1.1 % | 55.1 | 6.8 % | Helps |
| `vd-queue-enable=yes`, 2 frames | 0.2 % | 57.1 | 5.1 % | Helps more |
| **`vd-queue-enable=yes`, 4 frames** | **0.3 %** | **58.7** | **2.1 %** | **Adopted** |
| `vd-queue-enable=yes`, 8 frames | Not run | | | The media service hung first; see below |

Why the queue works: with no queue, mpv decodes on the thread that also runs its core. A decode thread lets frames be ready ahead of the moment they're due.

### 4K60 AVC, Real Stream

| mpv option | mpv dropped | Layer fps | Long intervals |
| :--- | :--- | :--- | :--- |
| No queue | 1.0 % | 54.9 | 7.5 % |
| Queue, 2 frames | 0.4 % | 56.2 | 6.1 % |

The first AVC comparison was thrown away. Its position sat at the end of the video, so nothing was playing. `tool/tv_m16/sweep_summary.py` now says so instead of reporting a rate.

### Ten-Minute Runs, Final Settings (4-Frame Queue)

| Stream | Played | mpv dropped | UI fps | Before the queue |
| :--- | :--- | :--- | :--- | :--- |
| 4K60 AVC | 610 s | 125 (0.3 %) | 48.2 | 1.6 % over 628 s |
| 4K60 AV1 | 610 s | 59 (0.16 %) | 54.7 | 6.6 % over 630 s |

### UI Frame Times, Plane Against Texture

At 1080p, danmaku on, 90 s each. These show what Hybrid Composition costs, and no mpv option changes them.

| Video | Path | UI fps | Frames over 16.7 ms | Frame total, p50 | Frame total, p90 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Moderate danmaku, 1080P60 | Plane | 54.7 | 26.4 % | 13.9 ms | 21.5 ms |
| Moderate danmaku, 1080P60 | Texture | 59.3 | 13.5 % | 8.6 ms | 15.4 ms |
| Heavy danmaku, 1080P | Plane | 42.3 | 85.7 % | 24.0 ms | 41.6 ms |
| Heavy danmaku, 1080P | Texture | 56.1 | 26.8 % | 10.4 ms | 25.6 ms |

## Which Options Became Settings

| Option | Decision | Why |
| :--- | :--- | :--- |
| `vd-queue-max-samples` | **Setting**, `视频直通解码队列`: 关闭, 1, 2 or 4 帧, default 4 | The one option that changed the result, and a TV with a different decoder may want a different size. Only tested sizes are offered. Frames held from this decoder can deadlock it (`M12_CRASH_DEBUG.md`, finding 1), so a larger number isn't merely slower. A stored value that isn't one of these falls back to 4 |
| `video-sync` | Already a setting upstream (`视频同步`) | No effect here. Left alone |
| `framedrop` | Not a setting | `no` only hides drops, which would read as a fix |
| `video-latency-hacks` | Not a setting | No effect |
| `vo` | **Never a setting** | Anything but `mediacodec_embed` is the path that panics the TV |
| `hwdec` | **Never a setting** | Pinned to `mediacodec`: the default can fall back to software, which this output can't show |
| `androidAttachSurfaceAfterVideoParameters` | **Never a setting** | It's what keeps Flutter's texture away from mpv |

There's deliberately no free-form box for mpv options. It could set `vo` and walk around everything that keeps 4K off the GPU.

## Not Tested

* `vd-queue-max-samples=8` or more.
* `vd-queue-max-bytes`, `vd-queue-max-secs` and `hwdec-extra-frames`.
* HDR, Dolby Vision, HEVC and live streams at 4K.
* Any TV but `<physical-tv>`.
* Picture smoothness by eye: the numbers show frames arriving, not how it looks on the panel.

## The Media Service Hang

During these runs, after about 9.6 hours of uptime and dozens of starts, `dumpsys media.player` stopped answering and every new process hung on the codec list, including one with none of the app's code. Only a restart cleared it. It began between the 4-frame and 8-frame runs, so the queue was a suspect. 8 force-stopped 4K60 AV1 cycles with the 4-frame queue, and about 90 more minutes of testing, didn't bring it back. The cause is unknown (`PROGRESS.md`, M16.3).

`dumpsys -t 6 media.player` answers in about 0.15 s when healthy, so `tool/tv_m16/stress.sh` checks it after every cycle.

## Reproducing This

Run these on `variant/4k-passthrough`, which has `tool/tv_m16/`.

```bash
git apply tool/tv_m16/logging.patch
./tool/tv_patch.sh apply
ORG_GRADLE_PROJECT_dev=true flutter build apk --release --target-platform android-arm
```

```bash
export ANDROID_SERIAL=<address> M12_RUNS=<folder outside the repository>
SECS=120 ./tool/tv_m16/sweep.sh <video url> base= 'queue=mpv.vd-queue-enable=yes\nmpv.vd-queue-max-samples=4\n'
```

```bash
git apply -R tool/tv_m16/logging.patch
```

* The stream has to be 4K, so pick 4K in the HUD first. Ask before the first 4K60 run of a session: on the wrong path, 4K60 can shut the TV down.
* `sweep.sh` runs each option under the guard in `tool/tv_m16/run.sh`, which stops the dev app if the decoder leaves the video plane.
* Don't commit the logging patch applied. Run logs stay outside the repository.
