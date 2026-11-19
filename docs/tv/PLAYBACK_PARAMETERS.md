# Playback Parameters on the Video Plane

Since M17, every video and live room on TV plays on Media3 ExoPlayer, on the video plane (see "Media3 on the Video Plane" below). The rest of this page is M16's: what was tried on `<physical-tv>` (MediaTek MT9690) to make 4K60 play well on mpv's video plane, what each option did, and which ones became settings. These are the numbers behind `TvVideoPlane`'s defaults on `variant/4k-passthrough`. The story around them is in [`PROGRESS.md`](./PROGRESS.md) (M16) and [`M12_CRASH_DEBUG.md`](./M12_CRASH_DEBUG.md).

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

## Media3 on the Video Plane (M17)

ExoPlayer draws into a `SurfaceView` under a see-through Flutter surface (`ARCHITECTURE.md` §2.16). Its settings, and why (`PLAN.md`, `M17.2` and `M17.6`):

| Setting | Value on TV | Why |
| :--- | :--- | :--- |
| Media3 | 1.11.1, pinned | 1.12.0 wasn't stable by `M17.12` (2026-11-18); a switch needs a device run first |
| Buffer, video | 缓冲大小 100 MB and 缓冲时长 180 s, bytes before time, forward only | Media3 keeps it on the Java heap, 192 MB on this TV, where about 170 MB ran out (`M17.5a`). The app's own settings, filled on TV only when unset |
| Buffer, live | 直播缓冲大小 64 MB, 直播缓冲时长 no limit | Upstream's 0 for 直播缓冲大小 would mean twice 缓冲大小 |
| Start and restart | 1 s buffered to start, 2 s after a rebuffer, or half the live offset | `DefaultLoadControl`'s rule, kept |
| Live start | Three target durations from the live edge (about 3 s) | Bilibili's playlists ask for the oldest segment (`#EXT-X-START:TIME-OFFSET=0`) of a seven-second window, which fell out of it at the first delay; the tag is dropped (`M17.12`) |
| Retries | A video 3, at 4, 6 and 10 s; a live room 5, at 4 s, or at once when it falls out of its window; then a fresh play link for a video; then the failure screen | Fail closed: never to mpv (`M17.6`, decision 4) |
| Codec selector | Media3's default; no decoder fallback | The one change other forks tied to a black picture was a custom selector |
| 4K check | The decoder's declared ranges | Bilibili's 3996-wide 4K fails Media3's performance-point check on this TV's decoders |
| Dolby Vision | Only through a Dolby Vision decoder that declares the stream's profile | Profile 5 has no other decoder |
| Tunneling, frame-rate requests, placeholder surface | Off | A decoder must never run on an EGL surface on this TV |
| `Range` on byte 0 | `bytes=0-` for a direct video request | `upos-sz-mirrorcosov` answers 567 without it |

### Media3 Beside mpv, 4K60 on the Plane

| Stream | Player | Played | Video dropped | Layer fps | Long intervals | UI fps |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| AVC | mpv, 4-frame queue (M16) | 610 s | 0.3 % | | | 48.2 |
| AVC | Media3 (`M17.4`) | 699 s | 0.18 % | 56.9 | 5.2 % | 49.9 |
| AVC | Media3, the build (`M17.12`) | 13.3 min | | 56.6 | 5.7 % | |
| AV1 | mpv, 4-frame queue (M16) | 610 s | 0.16 % | | | 54.7 |
| AV1 | Media3 (`M17.4`) | 717 s | 0.06 % | 58.0 | 3.2 % | 58.0 |
| AV1 | Media3, the build (`M17.12`) | 10.9 min | | 58.1 | 3.3 % | |

* `M17.12` measured the video layer only (`tool/tv_m17/`); Media3's dropped-frame count goes to 播放信息 and isn't logged.
* No Media3 option was swept as mpv's were: the video was already at or better than M16's, and what's left is the UI at 4K and the waits, which M18 measures.
* On this TV, the video plane draws a source narrower than 16:9 squeezed when the TV's 图像比例 is 自动 (`PLAN.md`, `M19.1`). No player setting changes that.

## Not Tested

* `vd-queue-max-samples=8` or more.
* `vd-queue-max-bytes`, `vd-queue-max-secs` and `hwdec-extra-frames`.
* HDR, Dolby Vision, HEVC and signed-in 2K/4K live streams (`M16.5` put live rooms on the plane and verified signed-out live streams up to 540p plus live-to-1080p-video transitions; signed-in 2K/4K live streams haven't been measured here yet).
* Any TV but `<physical-tv>`.
* Picture smoothness by eye: the numbers show frames arriving, not how it looks on the panel.

## The Media Service Hang

During these runs, after about 9.6 hours of uptime and dozens of starts, `dumpsys media.player` stopped answering and every new process hung on the codec list, including one with none of the app's code. Only a restart cleared it. It began between the 4-frame and 8-frame runs, so the queue was a suspect. 8 force-stopped 4K60 AV1 cycles with the 4-frame queue, and about 90 more minutes of testing, didn't bring it back. The cause is unknown (`PROGRESS.md`, M16.3).

`dumpsys -t 6 media.player` answers in about 0.15 s when healthy, so `tool/tv_m16/stress.sh` checks it after every cycle.

## Reproducing This

Run these on `variant/4k-passthrough`, which has `tool/tv_m16/`. For ExoPlayer on `main`, `tool/tv_m17/run.sh` guards and records a run, opened by URL or driven by hand (`-`), and `tool/tv_m17/report.sh` summarises it.

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
