# M12 Side Track: 4K Crash Debugging

A side track of Milestone M12 ([`PLAN.md`](./PLAN.md), Task M12.3), on its own branch, `debug/tv-m12-crash`, created from `docs/tv-m12-device-profile`. It doesn't block the M12 fix: option B (the 1080P60 cap) can ship while it runs.

The goal is to find out three things:
* which part of the TV faults at 4K;
* which output paths survive 4K60;
* whether 4K can be fixed in the app instead of capped.

The plan, the status, the run log and the findings all live in this file. When the track ends (CD9), the findings move into `PLAN.md` (M12.3) and [`PROGRESS.md`](./PROGRESS.md), and each tool is kept or dropped.

## Status

| Task | Title | Status | Panic risk | Needs the user |
| :--- | :--- | :--- | :--- | :--- |
| `CD0` | Setup, tools and test media | 🔄 In progress (branch, plan and media inventory done) | None | The TV's adb port |
| `CD1` | The TV's own players | ⏳ Planned | High | Present; go-ahead and panic budget; the five-minute check from option F1 |
| `CD2` | MediaCodec without mpv (`app_process` harness) | ⏳ Planned | Low for the 20 s sweeps, high for the 10-minute runs | Go-ahead for the long runs |
| `CD3` | A `SurfaceView` probe app | ⏳ Planned | High | Go-ahead |
| `CD4` | Barebone mpv (production libmpv, no app around it) | ⏳ Planned | Low for the `vo=gpu` sweeps, high for the panic runs | Go-ahead; approval if the official mpv-android app is installed |
| `CD5` | Content bisect | ⏳ Planned | High | Go-ahead |
| `CD6` | TV picture settings | ⏳ Planned | High | Changes the TV's settings |
| `CD7` | Telemetry and post-panic forensics | ⏳ Planned (runs alongside CD1–CD6) | None of its own | One bug report after the first panic |
| `CD8` | Desk research | ⏳ Planned | None | Checks for a firmware update |
| `CD9` | Synthesis and merge-back | ⏳ Planned | None | Decides on the fix options |

## Starting Point (from M12.2)

* **Fault 1, the freeze, then the ANR** (`vo=gpu`, media_kit's default on Android):
  * At 4K, the MediaTek decoder decodes into 5 tiled output buffers, and those buffers also serve as its reference frames.
  * mpv keeps 4 of them: 2 rendered into its `AImageReader`, whose reader thread is named `ImageReader-16x16f22u256m5`, so 5 images at most, and 2 queued. It then waits for a frame the decoder has no buffer to decode into.
  * Not changed by `video-sync`, `video-latency-hacks` or a 1080p render target.
* **Fault 2, the kernel panic** (`vo=mediacodec_embed`): three panics, all at 4K59.94, all with the same signature:

  | # | Stream | Played before the panic | Read address |
  | :--- | :--- | :--- | :--- |
  | 1 | `BV1fiHN6zEfx`, AV1 | about 40 s | `0x1C3C5FD80`–`0x1C3C5FD9F` |
  | 2 | `BV1fiHN6zEfx`, AV1 | about 190 s | `0x1C3EAE200` |
  | 3 | `BV1kMxM6FECM`, AVC | about 150 s (141 s counted) | `0x1C3BFD500` |

  * Common to all three:
    * `sys.boot.reason` `kernel_panic,miup_hit_panic`;
    * hardware client `CID 0xE000` caught reading protect block 24;
    * panic notifiers from the picture-quality driver (`pq_panic_notify`) and the AI accelerator (`[MDLA][MIUP]`);
    * the decoder holding 11 frame buffers of 15.6 MB (`vdec_fb`).
  * All three read addresses fall in one window of about 2.8 MB.
  * Never seen:
    * a panic on `vo=gpu`, which never played 4K for more than a few seconds;
    * a panic at 1080p, which had only short runs;
    * a panic in 6.3 days of normal use before the first one.

## Questions

1. Is the panic in the TV for every app, or specific to how mpv hands decoded frames to the GPU?
2. Does the path the TV's own apps use, with the video on its own hardware layer, survive 4K60? This decides option F.
3. Which property of the stream triggers it: resolution, frame rate, bitrate, codec or bit depth? What is the safe envelope, for example 4K30?
4. Which hardware block is client `0xE000`, what does protect block 24 cover, and does a TV picture feature take part?
5. Can the `vo=gpu` deadlock be broken while keeping mpv's shaders, for example with a larger reader queue? If it can, does 4K on that path then panic too?
6. Does anything observable (temperature, memory, clocks, kernel warnings) come before a panic?

## Hypotheses

| ID | Hypothesis | Tested by |
| :--- | :--- | :--- |
| H1 | Platform, not mpv: any app that hands 4K60 decoder output to the GPU through a `SurfaceTexture` panics the TV. mpv, media_kit and Flutter are incidental | CD2c |
| H2 | The path the TV's own apps use (`SurfaceView`, the video plane, tunneled playback) is safe at 4K60 | CD1, CD3 |
| H3 | Client `0xE000` belongs to the picture-quality or AI pipeline (AI picture, AI super resolution, motion smoothing), and turning those features off avoids the panic | CD6, CD8 |
| H4 | A hardware engine reads past the end of a 4K frame buffer, because 2160 isn't a multiple of the tile height, and the overrun lands in block 24 | CD5 (alignment variants), CD7 and CD8 (addresses against buffers and regions) |
| H5 | The panic scales with throughput (pixel rate or memory bandwidth), not with resolution: 4K60 fails, 4K30 or 1440p60 don't | CD5 |
| H6 | The panic comes from buffer recycling (a buffer reused while another block still reads it), so it depends on how many frames the consumer holds | CD2 hold sweeps, CD4 queue options, CD5 reference-frame variant |
| H7 | A reader queue larger than 5 images, or mpv holding at most 1 frame, breaks the `vo=gpu` deadlock | CD2a/b, CD4 |
| H8 | Memory pressure (demuxer and cache size) plays a part. Low prior: about 850 MB was free during the M12.2 stalls | CD4, CD7 |
| H9 | Temperature or clock changes explain the spread in time to panic (40–190 s) | CD7 |

## Ground Rules

* **Privacy**, the same as `PLAN.md`:
  * No LAN IPs, ports, absolute local paths, usernames or device serials in this file or in commits.
  * Write `<physical-tv>`, and describe test files instead of giving their paths.
  * Logs, kernel logs and bug reports stay outside the repository; only summaries go here.
* **The user's login export is never touched.** The dev app (`PiliPlus TV dev`) keeps its imported login, so don't clear its data.
* **Panic-prone runs need the user's go-ahead.** A run is panic-prone if it hardware-decodes 4K into a surface for more than about 20 s.
  * Each batch needs the go-ahead and an agreed panic budget (suggested: at most 3 reboots per session).
  * After a reboot, the user re-enables wireless debugging and sends the new port.
* **Every run stops what it started at the end, even on an error**: the player app, the probe app or the harness.
* **No swipes on a player screen**: a vertical swipe changes the TV's volume. Use D-pad keys, intents or adb commands.
* **The user changes the TV's system settings**, not adb: picture mode, AI picture, motion smoothing, display mode, system updates.
* **Pushed test files are removed at the end of each session.** Check free storage first.
* **The user's normal app and its settings are left alone.**

## Test Media

Local copies supplied by the user, kept outside the repository:

| ID | Content | Video | Size and rate | Bit depth, HDR | Length | Video bitrate | Audio |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `M1` | Sony 4K60 HDR demo (Las Vegas at night) | HEVC Main 10, level 5.1 | 3840 × 2160 at 60 | 10-bit, HDR10 (PQ, BT.2020) | 3:09 | about 13.6 Mbps | None |
| `M2` | Xiaomi TV S Pro 2027 review | AV1 Main, level 5.1 | 3840 × 2160 at 59.94 | 8-bit SDR | 5:32 | 3.1 Mbps | AAC |
| `M3` | 8K demo | AV1 Main, level 6.0 | 8192 × 4320 at 25 | 8-bit SDR | 3:13 | 20.8 Mbps | None |

* `M2` matches the stream that panicked fastest (4K60 AV1).
* `M3` exceeds the 4096 × 2304 that the decoders claim. It tests what happens when the decoder can't open: the `无法加载解码器` toast and mpv's fallback to software decoding. It is not a panic test.
* There is no AVC file, and AVC is the codec of the third panic. The AVC and alignment variants below are made in CD0 from `M2`, with ffmpeg on the development machine (its hardware encoders, or libx264 if needed), 3–5 minutes each, looped for longer runs:

  | ID | Variant | For |
  | :--- | :--- | :--- |
  | `V-AVC60` | AVC High, 3840 × 2160 at 59.94, about 20 Mbps | The main AVC reproducer |
  | `V-HEVC60-8` | HEVC Main, 8-bit SDR, 3840 × 2160 at 59.94 | Against `M1`'s 10-bit HDR |
  | `V-AVC30`, `V-AVC50` | AVC at 4K, 29.97 and 50 fps | H5 (frame rate) |
  | `V-AVC-1800`, `V-AVC-1440`, `V-AVC-1080` | AVC at 60 fps: 3200 × 1800, 2560 × 1440, 1920 × 1080 | H5 (resolution ladder) |
  | `V-AVC-2176`, `V-AVC-2048`, `V-AVC-4096` | AVC at 60 fps: 3840 × 2176, 3840 × 2048, 4096 × 2160 | H4 (height alignment) |
  | `V-AVC60-8M`, `V-AVC60-40M` | `V-AVC60` at about 8 and 40 Mbps | Bitrate |
  | `V-AVC60-ref1` | `V-AVC60` with 1 reference frame and no B-frames | H6 and H7 (fewer buffers held as references) |

* Optional input from the user: a local copy of `BV1kMxM6FECM` at 4K AVC, bilibili's own encode of the third panic.
* Local files take the network, the CDN and the thread ripper out of the picture. M12.2 showed the stall happens with data already buffered.

## Tasks

* **Task CD0 (`🔄 In progress`) — Setup, Tools and Test Media** (no panic risk):
  * Branch and this plan: done.
  * Rebuild the run tools under `tool/tv_m12/`. The M12.2 scripts and instrumentation diff lived in a scratchpad that is gone; the diff can be recovered from the session transcript.
    * `run.sh` runs one test. It pushes the options file and starts the player, then streams logcat (and the kernel log, if readable) to the development machine, and runs the CD7 sampler. When the run ends, a trap stops everything it started, and it prints a one-line summary.
    * `variants.sh` makes the variants above.
    * `postpanic.sh` collects the evidence after a reboot: boot reason, `SYSTEM_LAST_KMSG`, `SYSTEM_BOOT` and exit info, with the panic signature on one line.
    * The adb address is passed as an argument or an environment variable and never written to a file.
  * Read-only checks on the TV:
    * Are `logcat -b kernel` and `dmesg` readable from the shell?
    * Which thermal, `cpufreq` and `devfreq` nodes are readable?
    * Which system properties name the picture-quality, AI picture, motion-smoothing, MIU or MDLA features? Record the names only.
    * Which app handles `VIEW` for a local `video/mp4`?
    * How much storage is free?
  * Reboot recovery: does wireless debugging stay on after a reboot, and does adb's mDNS discovery (`ADB_MDNS_OPENSCREEN=1 adb mdns services`) find the new port? If not, the user sends the port after each reboot, as in M12.2.
  * Make the variants and push the media to the TV: a shell-readable directory for the harness, and each probe app's own external files directory.
* **Task CD1 (`⏳ Planned`) — The TV's Own Players** (panic-prone; the user present):
  * Use the TV's built-in media player, whichever app handles `VIEW` for a local `video/mp4`, started over adb with an intent and driven with D-pad keys only.
    * First `M2` in a loop for 10 minutes, the fastest panicker so far.
    * Then `V-AVC60`.
    * Then `M1`: does the panel switch to HDR?
  * The user's five-minute check from option F1 counts here too: 云视听小电视 at 4K60 and 杜比视界, and YouTube at 4K60 if it's installed.
  * Answers H2:
    * The TV's own path survives 10 minutes twice → the panic comes from how our app hands frames to the GPU, and option F is promising.
    * It panics too → the TV faults on every path at 4K60, and only a cap or a firmware update helps.
* **Task CD2 (`⏳ Planned`) — MediaCodec Without mpv** (an `app_process` harness, like `tool/tv_codecs.sh`, so no install and no root):
  * A small Java program decodes a local file in a loop with `MediaExtractor` and `MediaCodec`, at real-time pace, into one of three outputs:
    * **a.** An `ImageReader` (`PRIVATE` format, GPU-sampled usage, `maxImages` N) with a policy that keeps K images acquired, the way mpv does. Sweep N = 5 (mpv's value) / 6 / 8 / 12 against K = 0–4, 20 s each. This reproduces the deadlock without mpv and finds the smallest queue that avoids it (H7). Low risk.
    * **b.** The same reader, with each image imported into GLES (an `EGLImage` from its `AHardwareBuffer`) and drawn offscreen. This is mpv's `vo=gpu` import path, MediaTek's `Detile` step included.
    * **c.** A `SurfaceTexture` consumed by GLES (`updateTexImage`, then a draw). This is what Flutter does with a texture, so it is in effect `vo=mediacodec_embed` (H1).
  * Panic-prone: 10-minute runs of b (if some N avoids the deadlock) and of c, on `M2`, then on `V-AVC60`.
  * Measured each second: frames decoded and released, dequeue failures, `C2BqBuffer` failures, `Detile` count. Also the time to panic.
  * scrcpy's server shows that `MediaCodec` and surfaces work from `app_process`. If the shell can't open the hardware decoder with a surface (SELinux), the same code moves into the CD3 app.
* **Task CD3 (`⏳ Planned`) — A `SurfaceView` Probe App** (panic-prone):
  * A tiny native Android app under `tool/tv_m12/`: no Flutter, debug-signed, in its own package with no login. It plays a local file in one of three modes:
    * `MediaCodec` into a `SurfaceView`;
    * tunneled playback, if the decoder reports `FEATURE_TunneledPlayback`;
    * optionally, Media3 ExoPlayer into a `SurfaceView`.
  * An intent carries the file and the mode. The app stops itself after T seconds.
  * Runs: `M2` and `V-AVC60` for 10 minutes in each mode. Then `M1`: does the panel enter HDR mode, and does `dumpsys SurfaceFlinger` show the layer on the hardware composer rather than the GPU?
  * Answers H2 for our own code, and the panic half of option F1 offline. F1 then only has to check HDR, Dolby Vision and the network headers in a `-Pdev` build.
* **Task CD4 (`⏳ Planned`) — Barebone mpv: Production libmpv, No App Around It**:
  * `tool/tv_m12/mpv_probe/` is a minimal Flutter app on the same media_kit fork and ref as `pubspec.yaml` (`My-Responsitories/media-kit`, `native`):
    * a full-screen `Video` widget and nothing else: no network, login, danmaku or HUD;
    * plays a local file in a loop;
    * reads `vo`, `hwdec` and any mpv option from a text file in its external files directory, like the M12.2 instrumentation;
    * prints mpv's log and frame counters to logcat;
    * stops itself after T seconds.
  * First, reproduce M12.2: the `vo=gpu` deadlock, and the `vo=mediacodec_embed` panic on `M2`. This confirms the probe behaves like the app.
  * Optional cross-check with the official mpv-android app, which has its own mpv and FFmpeg builds. Only with the user's approval to download and install it.
  * The matrix:

    | Parameter | Values | Why |
    | :--- | :--- | :--- |
    | `vo` | `gpu` (default), `mediacodec_embed`, `gpu-next` (if the build has libplacebo) | Output path |
    | `hwdec` | `mediacodec`, `mediacodec-copy`, `no` | Zero-copy, copy or software |
    | `video-sync` | `display-resample` (PiliPlus default), `audio`, `display-vdrop` | How many frames mpv queues |
    | `interpolation`, `video-latency-hacks`, `swapchain-depth` | `no` and `yes`; `yes`; `1` and `3` | Fewer frames held on the `vo=gpu` side (H7) |
    | `framedrop` | `vo`, `decoder+vo` | Whether mpv drops before the queue fills |
    | `vd-queue-enable`, `vd-queue-max-samples` | `no`; `yes` with 2 and 8 | The decoder-side frame queue (more frames held) |
    | `vd-lavc-o` | `ndk_codec=1`, `ndk_async=1`, `delay_flush=1`, whichever this FFmpeg has | FFmpeg's NDK and asynchronous MediaCodec modes |
    | `hwdec-extra-frames` | 0, 6, 16 | Extra hardware frames; probably ignored for MediaCodec, to confirm |
    | `demuxer-max-bytes`, `demuxer-max-back-bytes`, `cache` | 4 MiB (PiliPlus default, `bufferSize` 4.0), 64 MiB, 400 MiB; `cache=no` | Memory pressure (H8) |
    | `android-surface-size` and the `SurfaceTexture` size | The video's size, 1920 × 1080 | The size of the buffers the decoder or mpv draws into |
    | Audio | `audio=no`, `ao=audiotrack`, `ao=opensles` | Whether audio timing matters |
    | `scale`, `dscale`, `deband`, `glsl-shaders` | `bilinear`, `no`, PiliPlus's super-resolution shader | GPU load on `vo=gpu`, once 4K plays there |

  * Order: first the `vo=gpu` deadlock options, which are short, low-risk runs. Then only the options the panic results point to, because each panic run costs a reboot.
* **Task CD5 (`⏳ Planned`) — Content Bisect** (panic-prone):
  * 10-minute runs over the variants, on the path from CD1–CD4 that panics fastest:
    * frame rate (H5);
    * the resolution ladder (H5);
    * height alignment (H4);
    * bitrate;
    * codec and bit depth (`M1`, `M2`, `V-AVC60`, `V-HEVC60-8`);
    * reference frames (`V-AVC60-ref1`, H6).
  * Frame rate goes first. 4K30 is the most useful result: if it is safe, the cap could let bilibili's 4K30 videos keep 4K. Then alignment, then the ladder.
  * A short run of `M3`, the 8K AV1 beyond the decoders' limit: does the decoder refuse it, does mpv fall back to software decoding, does the app freeze?
  * Output: a safe envelope, the streams that survive 10 minutes twice, to refine option B's cap.
* **Task CD6 (`⏳ Planned`) — TV Picture Settings** (panic-prone; the user changes the settings in the TV's own menu and restores them afterwards):
  * On the reproducer, one setting at a time:
    * AI picture, AI scene detection and AI super resolution off (the panic notifiers include the AI accelerator, MDLA);
    * motion smoothing (MEMC) off;
    * noise reduction off;
    * picture mode Game or PC, which bypasses most processing.
  * Then the reverse: everything on.
  * Answers H3. A setting that stops the panic points to the faulting block, and is at least a workaround for the user.
* **Task CD7 (`⏳ Planned`) — Telemetry and Post-Panic Forensics** (with every panic-prone run):
  * During the run, streamed to the development machine so it survives a panic:
    * `logcat -b all`, and the kernel log if it's readable;
    * a sampler every 2 s: thermal zones, CPU and `devfreq` frequencies (memory, GPU, video) where readable, `/proc/meminfo`;
    * `dumpsys SurfaceFlinger` and `dumpsys media.codec`, once per run.
  * After a reboot: `sys.boot.reason`, `SYSTEM_LAST_KMSG`, `SYSTEM_BOOT` and exit info. One `adb bugreport` after the track's first panic, kept outside the repository because it holds account and device identifiers.
  * A panic table: run, path, stream, time to panic, client, block, read address, `vdec_fb` count and size, the last kernel lines before the panic, and the temperature at the panic.
  * Answers H9, and feeds H4: do the read addresses land just past a decoder buffer, or in a fixed region?
* **Task CD8 (`⏳ Planned`) — Desk Research** (no device):
  * **Decode the panic.** Search public MediaTek TV kernel sources for `miup_hit_panic`, `[MIUP][HIT]`, `pq_panic_notify` and `[MDLA][MIUP]`: GPL releases for TVs on MT9690 (`merak`), and other MediaTek TV SoCs.
    * Map client `0xE000` to a hardware block.
    * Find what protect block 24 covers.
    * Map the read addresses against the reserved-memory regions printed at boot, if the kernel log is readable (CD0).
  * **Firmware.** Compare the TV's firmware version with the latest. The user checks for a system update; after an update, re-run the reproducer.
  * **Known reports.** Look for reboots or freezes at 4K on Hisense or MediaTek TVs from users of mpv-android, media_kit, Kodi, SmartTube or VLC, and for mpv issues about `hwdec_aimagereader` and buffer starvation.
  * **mpv's `hwdec_aimagereader`.** Confirm the hard-coded `maxImages` (5, from the reader thread's name). If H7 holds, work out what building a patched libmpv for media_kit on `armeabi-v7a` would take.
* **Task CD9 (`⏳ Planned`) — Synthesis and Merge-Back**:
  * Write the conclusions in M12.3's terms:
    * the faulting component;
    * the safe paths and streams at 4K;
    * the candidate fixes, for example:
      * option B's cap refined (say, 4K30 allowed);
      * a go or no-go on option F for 4K60;
      * a new option, a patched libmpv with a larger reader queue that keeps `vo=gpu` and the shaders, if H7 holds and that path survives 10 minutes twice;
      * a workaround for the user, such as a picture setting.
  * Move the findings into `PLAN.md` (M12.3) and `PROGRESS.md`.
  * Decide which tools stay (documented in `docs/tv/README*.md`) and which are dropped.
  * Reports to upstream or to the TV's maker only with the user's approval.

## Order and Budget

* **Session 1** (no panic expected; can run without the user once the port is known): CD0, CD8, CD2a, and CD4's `vo=gpu` options, at most 20 s of 4K per run.
* **Session 2** (the user present, panic budget agreed): CD1 (`M2`, 10 minutes) and CD2c (`M2`, 10 minutes). Then CD6 or CD3, depending on the results.
* **Session 3**: CD5 on the fastest reproducer. CD4's panic options, if the panic turns out to be specific to mpv.
* **After session 2**:

  | Result | What it means | Next |
  | :--- | :--- | :--- |
  | The TV's own player panics too | The TV faults on every path at 4K60, so there's no app-side fix | A cap (B or C) and a firmware report. CD5 looks for the safe envelope. F is a no-go for 4K60 |
  | The TV's own player survives, CD2c panics | Handing 4K frames to the GPU is the trigger | F is promising; CD3 confirms with our own `SurfaceView`. Both mpv paths stay capped |
  | CD2c survives, mpv panics | Something in mpv or Flutter | CD4's matrix |
  | CD2a finds a reader queue that avoids the deadlock, and CD2b survives 10 minutes twice | A patched libmpv could keep `vo=gpu` at 4K | CD8 checks what the build costs |

* **Verdicts**:
  * A panic makes a path or stream **unsafe**.
  * 10 minutes of playback twice without one makes it **safe**. That is about three times the slowest panic so far (190 s).
  * One 10-minute pass makes it **probably safe**.

## Run Protocol

1. **Before**: record the kernel uptime, `sys.boot.reason` and free storage. Start the log streams on the development machine and the sampler.
2. **Run** for the planned time: 20 s for deadlock sweeps, 60 s for a smoke test, 10 minutes for a verdict.
3. **After**: stop everything the run started (a trap, also on failure), stop the streams, record the counters.
4. **After a reboot**: wait for the user's port, run the post-panic collection, and take the time to panic from the stream's last line.
5. Add one row per run to the run log below.

## Out of Scope

* Rooting, unlocking the bootloader, custom firmware.
* Opening the TV to reach the mainboard's serial console (UART). It would show the whole kernel log live, but the inside of a TV carries mains voltage and the warranty is at stake. The user's call only; not planned.
* Hidden factory or service menus, which can change the panel's calibration.
* The user's normal app and its settings.

## Run Log

| Run | Date | Task | Path | Stream | Options | Played | Dropped | Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| — | | | | | | | | No runs yet |

## Log

### [2026-10-29] Track Created (`CD0`, Part 1)
* **Status**: 🔄 `CD0` in progress. The branch, this plan and the media inventory are done; the tools, variants and TV checks are next.
* **Branch**: `debug/tv-m12-crash`, from `docs/tv-m12-device-profile`.
* **Files Changed**: `[NEW] docs/tv/M12_CRASH_DEBUG.md`.
* **Inputs from the user**:
  * three local test videos (`M1`–`M3`);
  * ideas to cover: a barebone mpv matrix (`vo`, codec, resolution, demuxer size and other options), and ways to debug the TV's hardware and firmware.
* **Media inventory**: probed with `ffprobe` on the development machine (the table above). The set has no AVC file; the AVC variants are made in `CD0`.
* **Lost since M12.2**: the run scripts and the instrumentation diff were kept in a scratchpad that no longer exists. `CD0` rebuilds them, and the diff can be recovered from the session transcript.
