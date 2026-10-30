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
| `CD0` | Setup, tools and test media | ✅ Done (session 1) | None | The TV's adb port |
| `CD1` | The TV's own players | 🔄 Mostly done (MiXplorer panics the TV; Just Player survives; the TV's own `com.vt.tv.mediacenter` and the five-minute check from option F1 are left) | High | Present; go-ahead and panic budget; the five-minute check from option F1 |
| `CD2` | MediaCodec without mpv (`app_process` harness) | ✅ Done (session 2), but for CD2b, deferred: offscreen 4K60 survives 10 minutes on a warm TV | Low for the 10 s sweeps, high for the 10-minute runs | Go-ahead for the long runs |
| `CD3` | A `SurfaceView` probe app | ✅ Done (session 2), but for tunneled playback: the `SurfaceView` path survives; the `TextureView` path reproduces the panic | High | Go-ahead |
| `CD4` | Barebone mpv (production libmpv, no app around it) | 🔄 Partly done (session 2, with the official mpv-android instead of a harness on the app's libmpv; the options matrix isn't run) | Low for the `vo=gpu` sweeps, high for the panic runs | Go-ahead for panic runs |
| `CD5` | Content bisect | 🔄 Partly done (on a warm TV, 1080p60 and 4K30 each survived 10 minutes on the GPU path; alignment, bitrate and the resolution ladder aren't run) | High | Go-ahead |
| `CD6` | TV picture settings | ⏳ Planned, low priority: the AI engine runs on the video plane, which doesn't panic, and not on the path that does (finding 9) | High | Changes the TV's settings |
| `CD7` | Telemetry and post-panic forensics | 🔄 In progress (11 panic signatures collected; no warning signs before a panic; no temperature available) | None of its own | One bug report after the first panic |
| `CD8` | Desk research | 🔄 In progress (mpv's upstream change found; no public source for the panic strings yet) | None | Checks for a firmware update |
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

## Findings So Far

Details and raw numbers are in the [Log](#log).

1. **The freeze comes from the TV's buffer budget, not from mpv's image count** (session 1, CD2a, without mpv). At 4K, MediaTek's buffer manager (`C2MtkTvBufferManager`) gives the output surface the decoder's own buffer count plus exactly 2. The size of the consumer's queue (`maxImages`) is ignored. A player that holds more frames than the stream leaves free deadlocks the decoder. Held frames count both the images it keeps and the decoded frames it queues:

   | Stream | Decoder buffers (`bufferCount`) | Surface slots (`mMaxSlot`) | Freezes when the player holds |
   | :--- | :--- | :--- | :--- |
   | bilibili's 4K60 AVC (`V-AVC60`, 3 B-frames) | 6 | 8 | 3 or more frames (images kept + frames queued) |
   | 4K60 AVC with 1 reference frame and no B-frames (`V-AVC60-ref1`) | 3 | 5 | 4 or more |
   | 4K60 AV1 (`V-AV1-60`) | 9 | 11 | any queued frame (up to 2 kept images with nothing queued plays) |
   | 4K60 HEVC, no B-frames, encoded on the development machine (`V-HEVC60-8`) | 6 | (never reached) | never in the sweep (up to 4) |
   | 1080p60 AVC (`V-AVC-1080`) | 5 | (never reached) | never (up to 8) |

   * mpv's `vo=gpu` holds about 4 (2 images, 2 queued; M12.2), so every bilibili 4K stream freezes. 1080p has no such cap.
   * `maxImages` 2, 3, 4, 5, 6, 8 and 12 all behave the same, so mpv's upstream change from 5 to 3 images (finding 6) wouldn't fix this TV.
   * None of these decoder settings changes the budget:
     * the standard `low-latency` key;
     * MediaTek's `render-planar`, `low-latency-mode` and `game-mode`, which the decoder logs as 0, so they weren't taken;
     * `target-width` and `target-height` at 1920 × 1080: taken, but the output stays 3840 × 2176 with 8 slots.
2. **A texture consumer doesn't freeze** (CD2c, 10 s). A `SurfaceTexture` drawn by GLES, which is what Flutter does and so what `vo=mediacodec_embed` amounts to, plays 4K60 AVC at 60 fps with 2 frames queued. That is the path that panicked in M12.2. Its 10-minute runs are the next panic test.
3. **The screensaver blocks 4K hardware decoding.** The TV's screensaver (Google TV ambient mode) takes the hardware JPEG decoder. While it holds it, every new hardware video decoder above 1080p fails right after it starts: the vendor resource manager logs `[C2GRM] 1hw + 1sw (>fhd)`, and the decoder reports error -14. The tools now send a wake-up key before and during each run. The same resource limit may explain the app's `无法加载解码器` toast when a 4K video opens while another decoder is still busy (M12.1 side finding).
4. **The panic logs point at the picture-quality pipeline** (CD7, from the three saved panic logs).
   * The panic is raised from the `mtk_miup` interrupt and lands on whatever CPU 0 is running (`logcat`, a Mali thread, idle), so the backtrace names no software culprit.
   * In the panic notifier chain, three drivers rule themselves out:
     * the JPEG decoder (`jpd_cid = 0x8118`);
     * the demux and descrambler (`no match tsp module`);
     * the render DMA (its windows are off).
   * The picture-quality driver dumps the memory clients of its video window (window 0): `SCMI`, `UCM` and `MDW`. The AI accelerator only repeats the hit.
   * The decoder's frame buffers in the panic's IOMMU dump are `0xEF2000` = 15,671,296 bytes each, exactly the size the decoder announces for 4K AVC in the harness (3840 × 2176, `bufferSize:15671296`).
   * So client `0xE000` is most likely one of the picture-quality memory clients reading video frames (H3).
   * The decoder also exposes picture-quality vendor parameters (`vendor.mtk-codec2.memc-mode`, `vendor.mtk-camera.ai-sr`, `vendor.mtk-camera.enable-pq`, `vendor.mtk-pq.pqsetting`), candidates for CD6 from the app's side.
   * The kernel reports the SoC as `MediaTek MT5896`; the GPU property says `mt9690`.
5. **AI picture is on.** `sys.vt.aipq.smart_scene_state=1`, and the TV has `com.vt.tv.aipq` and `com.vt.tv.ai_sense` services. It is the first candidate for CD6.
6. **mpv upstream cut its image reader from 5 to 3 images** on 2026-09-11 (`c8d3f6884d`, mpv PR #18453), after mpv-android issue #540: 5 was too many for a MediaTek Fire TV Stick's decoder. The app's libmpv, the media_kit fork's build `20260906` (and the newer `20260930`), is mpv v0.41.0 with 5 images. On this TV the count makes no difference (finding 1).
7. **Playing 4K60 doesn't panic the TV by itself** (session 2). The panic isn't specific to mpv, Flutter or PiliPlus, because another app reproduces it. But neither is it specific to the output path, the stream, audio or `MediaPlayer`:

   | Player | Output | Stream | Audio | Second decoder | Media session, audio focus | Result |
   | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
   | MiXplorer (`MediaPlayer`) | GPU, into the app's window | `M4` | Yes | Opened, refused | Yes | **Panic at 144 s** |
   | MiXplorer, repeated on another boot | The same | `M4` | Yes | Opened, refused | Yes | **Panic at about 165 s** |
   | The harness, offscreen | GPU, 1920 × 1080 target | `V-AV1-60` | No | No | No | 600 s, no panic |
   | Probe app | `SurfaceView` (video plane) | `V-AVC60` | No | No | No | 600 s, no panic |
   | Probe app | `TextureView` (GPU, into the window) | `V-AVC60` | No | No | No | 600 s, no panic |
   | Probe app | `TextureView` | `V-AVC60` | Yes | No | No | 600 s, no panic |
   | Probe app | `TextureView` | `M4` | Yes | No | No | 600 s, no panic |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | No | No | 600 s, no panic |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | Opened, refused | No | 600 s, no panic |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | Opened, refused | Yes | **Panic at about 234 s** |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | No | Yes | **Panic at about 264 s** |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | No | Session only | **Panic at about 174 s** |
   | Probe app, `MediaPlayer` | `TextureView` | `M4` | Yes | No | Focus only | **Panic at about 119 s** |
   | Probe app, `MediaPlayer`, repeated on a warm TV | `TextureView` | `M4` | Yes | No | No | **Panic at about 178 s** |
   | Probe app, `MediaPlayer` | `SurfaceView` | `M4` | Yes | Opened, refused | Yes | 600 s, no panic |
   | Probe app, `MediaPlayer` | `SurfaceView` | `M2` (AV1, looped) | Yes | Opened, refused | Yes | 600 s, no panic |
   | Just Player (Media3 1.11.1) | `SurfaceView`, its controls in a window above | `M4` | Yes | No | Yes | 600 s, no panic |
   | mpv-android, `vo=mediacodec_embed` | `SurfaceView` | `M4` | Yes | No | Yes | 600 s, no panic, no freeze |
   | Just Player | `SurfaceView` | `M2` (AV1, its full 5:32) | Yes | No | Yes | 325 s, no panic |
   | mpv-android, `vo=mediacodec_embed` | `SurfaceView` | `M2` (AV1, its full 5:32) | Yes | No | Yes | 325 s, no panic, no freeze |

   * The last column means nothing: the run that survived 600 s with no session panicked when repeated later (finding 14). The runs weren't in random order.
   * The window's composition is the same in both: one 1920 × 1080 window layer, `DEVICE`, scaled to the panel by the hardware. So is the decoder's setup (`bufferCount:6`, `bufferSize:15671296`, `sideband:0`, `bufferQueue:1`).
   * All eight new panics have the signature of M12.2: `miup_hit_panic`, `CID 0xE000` read, block 24, at `0x1C43C7F00`, `0x1C3BE5800`, `0x1C3BFDE00`, `0x1C43C7000`, `0x1C3BF8400`, `0x1C3BEB200`, `0x1C3BEEE40` and `0x1C43C7000` again. The eleven read addresses span about 8.3 MB, not the 2.8 MB of the first three.
8. **A second decoder that the TV refuses is neither enough nor needed** (H10). Within about 0.6 s of `MediaPlayer` opening its decoder (0.57 s and 0.35 s in the two runs), MiXplorer's own process opens a second `c2.mtk.avc.decoder` on a surface. The resource check refuses it (`[CheckVdecResource] previous video:… no resource`, `VCodec Initialize failed`), the kernel driver logs `mtk_vdec_s_ctrl: ctrl-id=0x99300e fails!`, and the picture-quality service logs `closePqRepository fail` for a stream it doesn't know. The first decoder plays on. Its failure is logged under the tag `FRAME`, so it is probably a frame grabber for a thumbnail. The probe app's `second=` option reproduces every one of these lines, and that alone survives 600 s. And a run with a media session and audio focus but no second decoder also took the TV down, at about 264 s.
9. **The `SurfaceView` path is the TV's video path, and its AI picture engine runs on it** (session 2).
   * The layer is composed as `DEVICE(MM)`: the buffers are 4 KB handles to frames that go to the video plane without the GPU. Only here does the `[MI][AIPQ]` post-processing run (6,094 `SendRaw` calls in 10 minutes, none in either MiXplorer run), and it runs without a panic. That weakens H3 as far as the AI engine goes.
   * The decoder's buffers are larger on this path (`bufferSize:16203776`, not `15671296`).
10. **The TV's temperature can't be read over adb.** `dumpsys thermalservice` gives the same placeholder for every sensor, `battery` and `usb_port` included (56 on one boot, 39 on the next), and the `thermal_zone` nodes are empty. So H9 can't be tested from here; the sampler's temperature column means nothing.
11. **The decoder names the path a run is on.** Its log line `sideband:0, bufferQueue:1, hwRender:…, gdec:…` reads `hwRender:1, gdec:0` on the video plane and `hwRender:0, gdec:1` on the GPU path. Every panic in this track is on the GPU path, and no run on the video plane has panicked.
12. **mpv can run on the video plane** (session 2). `vo=mediacodec_embed` is the setting that panicked in M12.2 (option D), but there media_kit gives mpv a `SurfaceTexture` from Flutter, so the GPU still draws every frame. Given a real `SurfaceView`, mpv-android's decoder reports `hwRender:1, gdec:0`, and it plays 4K60 for 10 minutes with a media session and audio focus. AV1 passes too, for the file's full 5:32. That is a candidate the plan didn't have: a `SurfaceView` for mpv, in place of a second player. It keeps option D's limit, no mpv shaders, and needs a change to the media_kit fork's Android `VideoOutput`.
13. **Fault 1 belongs to mpv on this TV, and it isn't certain.** mpv-android, with its own mpv and FFmpeg builds and no Flutter, freezes at its defaults exactly as the app does. It froze 5 times in 6, from a fresh start and from a running app alike. The sixth run played 30 s with matching mpv logs, launched while the `mpv.conf` dialog was open with the keyboard up, and that state wasn't reproduced. So finding 1's table says when a freeze can happen, not that it always does. Where mpv doesn't freeze at 4K60, it is on the path that panics.
14. **The GPU path's panic depends on the TV's state, not on a media session** (H1, H9, H11). A session, then audio focus, each took the TV down alone, and the two have no log message in common that the survivors lack. Then S2-7, which had survived 600 s with neither, panicked at about 178 s when repeated exactly. So they were never the cause. The order of the on-screen GPU runs shows what changed:

    | Time | Run | State of the TV | Result |
    | :--- | :--- | :--- | :--- |
    | 01:39 | MiXplorer | On for days, after a 10-minute offscreen run | Panic at 144 s |
    | 13:14–14:00 | 4 probe runs, no session | Cold: off for 11 hours before 12:58 | All survived |
    | 14:01 | MiXplorer | Over an hour of 4K | Panic at 165 s |
    | 14:15 | Probe, no session | Off for about 3 minutes | Survived |
    | 14:27 | Probe, session and focus | Straight after that run | Panic at 234 s |
    | 14:38–15:28 | 4 runs on the video plane | Warm | All survived |
    | 15:40 | Probe, session and focus | Straight after those | Panic at 264 s |
    | 15:47 | Probe, session only | Off for about 3 minutes | Panic at 174 s |
    | 15:59 | Probe, focus only | Off for about 8 minutes | Panic at 119 s |
    | 16:05 | Probe, no session, no focus (S2-7 again) | Off for about 3 minutes | Panic at 178 s |
    | 16:41 | The same, after finding 15's three runs | 30 minutes of playback | Panic at about 11 s |

    * Four of the five survivors come from the first hour after a cold start. Between 14:01 and 16:05, six of seven GPU runs on screen at 4K60 panicked, all within 5 minutes. A warm TV (H9), or something else that builds up over the day, fits this. It isn't proven: the 14:15 run survived on a warm TV.
    * The first panic of the day came about 66 minutes after the cold start, about 50 of them spent playing 4K.
    * One warm run didn't panic and doesn't fit neatly: the offscreen AV1 run (S2-1), 12 minutes before MiXplorer's first panic, at about 48 fps. So being on screen may still matter.
    * The session's effects in the logs are all at startup: Bluetooth media control (`MediaPlayerList`, `AvrcpTargetJni`), Cast (`cast_shell`) and Google Assistant (`katniss`). After the first 20 s, the crash runs log nothing that the survivors don't.
    * What holds either way: warm or not, nothing on the video plane has panicked, and the GPU path has panicked 8 times in this track and 3 in M12.2.
    * No cold-start test is planned. The user's TV stays on all the time, and turning it off only puts it in a shallow sleep, so a warm TV is the normal case. The 11 hours off before 12:58 came from a panic's shutdown. So the panic's timing on a warm TV is what matters for users, and H9 stays unproven.
15. **On a warm TV, only 4K60 on the GPU path, on screen, panics** (H5, session 2). Run one after another on one boot, and ended by a control:

    | Output | Stream | Decoder path | Result |
    | :--- | :--- | :--- | :--- |
    | `TextureView`, `MediaPlayer` | 1080p60 AVC | `hwRender:0, gdec:0` | 600 s, no panic |
    | `TextureView`, `MediaPlayer` | 4K30 AVC | `hwRender:0, gdec:1` | 600 s, no panic |
    | Offscreen `SurfaceTexture` | 4K60 AVC, 1920 × 1080 target | `hwRender:0, gdec:1` | 600 s at 60 fps, no panic |
    | `TextureView`, `MediaPlayer` (the control) | `M4`, 4K60 AVC | `hwRender:0, gdec:1` | **TV lost at about 11 s**, the fastest yet |

    * Each is one pass, so **probably safe** by this plan's verdicts. In the boots before, 4K60 panicked within 3 minutes of a start at the same uptime, so these three runs lasted over three times that.
    * So neither `gdec`, nor 60 fps through the decoder, nor the GPU drawing into a 1920 × 1080 target is enough. It takes 4K60 going to the screen through the GPU.
    * 1080p runs a different path: `gdec:0`, and no `Detile` lines at all. At 4K, each 15,671,296-byte frame holds the tiled picture (8,355,840 bytes of luma, then chroma) and, from offset 12,533,760, a 1920 × 1080 scaled copy (VSD). On the video plane the decoder's frames are larger, 16,203,776 bytes.
    * `Detile` logs the frames' addresses, but these are IOVAs (`0x218B1D000`) and the panic's are physical (`0x1C3…`), so they can't be matched. H4 stays open.
    * A cap at 1080P60 is supported, with 4K30 as a possible exception. The re-encoded 4K30 clip needs only 3 decoder buffers, though, so bilibili's own 4K30 streams may still hit Fault 1.

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
| H1 | Platform, not mpv: any app that hands 4K60 decoder output to the GPU through a `SurfaceTexture` panics the TV. mpv, media_kit and Flutter are incidental. **Holds on a warm TV** (finding 14): a bare `MediaPlayer` on a `TextureView` panics | CD2c, CD3 |
| H2 | The path the TV's own apps use (`SurfaceView`, the video plane, tunneled playback) is safe at 4K60. **Holds so far**: AVC is safe by this plan's verdicts (4 passes of 10 minutes), AV1 probably safe (one of 10 minutes, two of the file's 5:32). No panic on a warm TV. Tunneled playback, HDR, Dolby Vision and network streams aren't tested | CD1, CD3 |
| H3 | Client `0xE000` belongs to the picture-quality or AI pipeline (AI picture, AI super resolution, motion smoothing), and turning those features off avoids the panic. **Weakened**: the AI engine runs on the video plane, which doesn't panic (finding 9) | CD6, CD8 |
| H4 | A hardware engine reads past the end of a 4K frame buffer, because 2160 isn't a multiple of the tile height, and the overrun lands in block 24 | CD5 (alignment variants), CD7 and CD8 (addresses against buffers and regions) |
| H5 | The panic scales with throughput (pixel rate or memory bandwidth), not with resolution: 4K60 fails, 4K30 or 1440p60 don't. **Supported** on a warm TV (finding 15); 1440p60 is untested | CD5 |
| H6 | The panic comes from buffer recycling (a buffer reused while another block still reads it), so it depends on how many frames the consumer holds | CD2 hold sweeps, CD4 queue options, CD5 reference-frame variant |
| H7 | A reader queue larger than 5 images, or mpv holding at most 1 frame, breaks the `vo=gpu` deadlock | CD2a/b, CD4 |
| H8 | Memory pressure (demuxer and cache size) plays a part. Low prior: about 850 MB was free during the M12.2 stalls | CD4, CD7 |
| H9 | Heat explains the panics' timing: the GPU path panics on a warm TV, within minutes. Not proven, and not tested further: the TV reports no real temperature (finding 10), and it is warm in normal use (finding 14) | CD3 |
| H10 | A second hardware decoder that the TV refuses while a 4K one plays leaves something behind (the picture-quality stream state, the vdec firmware's instance table), and a hardware client later reads through it. **Rejected**: not enough alone (600 s, no panic), and not needed (S2-17) | CD3 (`second=`) |
| H11 | An active media session or audio focus starts something the panic needs on the GPU path. **Rejected**: the run with neither panics too (finding 14) | CD3 (`session=`, `focus=`) |

## Ground Rules

* **Privacy**, the same as `PLAN.md`:
  * No LAN IPs, ports, absolute local paths, usernames or device serials in this file or in commits.
  * Write `<physical-tv>`, and describe test files instead of giving their paths.
  * Logs, kernel logs and bug reports stay outside the repository; only summaries go here.
* **The user's login export is never touched.** The dev app (`PiliPlus TV dev`) keeps its imported login, so don't clear its data.
* **Panic-prone runs need the user's go-ahead.** A run is panic-prone if it hardware-decodes 4K into a surface for more than about 20 s.
  * Each batch needs the go-ahead and an agreed panic budget (suggested: at most 3 panics per session).
  * A panic shuts the TV down; it doesn't come back by itself. Notify the user at once. They turn it on, re-enable wireless debugging and send the new port.
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
| `M4` | Flagship phone chip comparison (bilibili's own 4K AVC encode, supplied after the plan) | AVC High, level 5.2, 3 B-frames | 3840 × 2160 at 59.94 | 8-bit SDR | 57:15 | 3.9 Mbps on average | AAC |

* `M2` matches the stream that panicked fastest (4K60 AV1).
* `M3` exceeds the 4096 × 2304 that the decoders claim. It tests what happens when the decoder can't open: the `无法加载解码器` toast and mpv's fallback to software decoding. It is not a panic test.
* `M4` is bilibili's own 4K AVC encode, the codec of the third panic. The variants below are 3-minute cuts (from 2:00) made by `tool/tv_m12/variants.sh` on the development machine. `V-AVC60` and `V-AV1-60` are cut from `M4` and `M2` without re-encoding. The rest re-encode `M4` with the VideoToolbox encoders, or libx264 where the encoder settings matter. The harness loops them for longer runs:

  | ID | Variant | For |
  | :--- | :--- | :--- |
  | `V-AVC60` | `M4` cut, unchanged: AVC High 3840 × 2160 at 59.94 (this part of the video averages about 9 Mbps) | The main AVC reproducer |
  | `V-AV1-60` | `M2` cut, unchanged: AV1 3840 × 2160 at 59.94 | The main AV1 reproducer |
  | `V-HEVC60-8` | HEVC Main, 8-bit SDR, 3840 × 2160 at 59.94 | Against `M1`'s 10-bit HDR |
  | `V-AVC30`, `V-AVC50` | AVC at 4K, 29.97 and 50 fps | H5 (frame rate) |
  | `V-AVC-1800`, `V-AVC-1440`, `V-AVC-1080` | AVC at 60 fps: 3200 × 1800, 2560 × 1440, 1920 × 1080 | H5 (resolution ladder) |
  | `V-AVC-2176`, `V-AVC-2048`, `V-AVC-4096` | AVC at 60 fps: 3840 × 2176, 3840 × 2048, 4096 × 2160 | H4 (height alignment) |
  | `V-AVC60-8M`, `V-AVC60-40M` | `V-AVC60` at about 8 and 40 Mbps | Bitrate |
  | `V-AVC60-ref1` | `V-AVC60` with 1 reference frame and no B-frames | H6 and H7 (fewer buffers held as references) |

* Local files take the network, the CDN and the thread ripper out of the picture. M12.2 showed the stall happens with data already buffered.

## Tasks

* **Task CD0 (`✅ Done`, session 1) — Setup, Tools and Test Media** (no panic risk):
  * Branch and this plan: done.
  * The run tools, in `tool/tv_m12/`. The M12.2 scripts and instrumentation diff lived in a scratchpad that is gone; the diff can be recovered from the session transcript if CD4 needs it.
    * `run.sh` runs one test: the CD2 harness (`probe`) or any start and stop command (`shell`). It sends a wake-up key, then streams logcat and the kernel log to the development machine and runs the CD7 sampler (`sampler.sh`). When the run ends, a trap stops everything it started, and it prints a one-line summary. A TV that stops answering ends the run as `lost`.
    * `probe.sh` builds the CD2 harness (`CodecProbe.java`), pushes it and the chosen videos to the TV's work folder (`/data/local/tmp/m12`), and removes that folder with `--clean`.
    * `variants.sh` makes the variants above.
    * `postpanic.sh` collects the evidence after a reboot: boot reason, `SYSTEM_LAST_KMSG`, `SYSTEM_BOOT` and exit info, with the panic signature on one line.
    * Machine- and network-specific values come from the environment and are never written to a file: `ANDROID_SERIAL` (the TV's adb address), `M12_MEDIA` (the media folder) and `M12_RUNS` (run output), both folders outside the repository.
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
* **Task CD2 (`🔄 In progress`; CD2a done in session 1) — MediaCodec Without mpv** (an `app_process` harness, like `tool/tv_codecs.sh`, so no install and no root):
  * A small Java program (`tool/tv_m12/CodecProbe.java`) decodes a local file in a loop with `MediaExtractor` and `MediaCodec`, at real-time pace. It keeps Q decoded frames (`lookahead`) behind the oldest one, which it shows only once they are there, as mpv does. The output is one of three:
    * **a.** An `ImageReader` (`PRIVATE` format, GPU-sampled usage, `maxImages` N) with a policy that keeps K images acquired, the way mpv does. Sweep N, K and Q, 10 s each. This reproduces the deadlock without mpv and finds what avoids it (H7). Low risk. **Done**: see the session 1 log.
    * **b.** The same reader, with each image imported into GLES and drawn offscreen: mpv's `vo=gpu` import path, MediaTek's `Detile` step included. Deferred: Java has no call to turn an `AHardwareBuffer` into an `EGLImage` (`eglGetNativeClientBufferANDROID` is native-only), so it needs NDK code. CD2a's counts already explain the deadlock without it.
    * **c.** A `SurfaceTexture` consumed by GLES (`updateTexImage`, then a draw). This is what Flutter does with a texture, so it is in effect `vo=mediacodec_embed` (H1). A 10 s smoke run works (below).
  * `fmt.KEY=VALUE` arguments set keys in the decoder's format, `vendor=1` lists the decoder's vendor parameters.
  * Panic-prone: 10-minute runs of b (if some N avoids the deadlock) and of c, on `M2`, then on `V-AVC60`.
  * Measured each second: frames decoded and released, dequeue failures, `C2BqBuffer` failures, `Detile` count. Also the time to panic.
  * scrcpy's server shows that `MediaCodec` and surfaces work from `app_process`. If the shell can't open the hardware decoder with a surface (SELinux), the same code moves into the CD3 app.
* **Task CD3 (`🔄 In progress`) — A `SurfaceView` Probe App** (panic-prone):
  * Just Player and mpv-android were installed on the TV for session 2, with the user's approval, and removed at its end.
  * Built: `tool/tv_m12/probe_app/` and `probe_app.sh`, with the harness's `decode` loop on a `SurfaceView` or a `TextureView` (`view=`), or the system's `MediaPlayer` (`player=media`). It takes the harness's options, including `audio`, `drop` (release late frames unshown) and `second` (open a second decoder), plus `session` (an active media session) and `focus` (audio focus). Tunneled playback and ExoPlayer aren't built yet. Videos go in shared storage, `Movies/m12`: the app can't read files adb puts in its own data folder, since they belong to the shell.
  * A tiny native Android app under `tool/tv_m12/`: no Flutter, debug-signed, in its own package with no login. It plays a local file in one of three modes:
    * `MediaCodec` into a `SurfaceView`;
    * tunneled playback, if the decoder reports `FEATURE_TunneledPlayback`;
    * optionally, Media3 ExoPlayer into a `SurfaceView`.
  * An intent carries the file and the mode. The app stops itself after T seconds.
  * Runs: `M2` and `V-AVC60` for 10 minutes in each mode. Then `M1`: does the panel enter HDR mode, and does `dumpsys SurfaceFlinger` show the layer on the hardware composer rather than the GPU?
  * Answers H2 for our own code, and the panic half of option F1 offline. F1 then only has to check HDR, Dolby Vision and the network headers in a `-Pdev` build.
  * Open-source players could stand in for the parts not built, with the user's approval to install them. Just Player is Media3 ExoPlayer with tunneled playback, so it tests option F's real engine. Wholphin has both ExoPlayer and mpv but needs a Jellyfin server.
* **Task CD4 (`⏳ Planned`) — Barebone mpv: Production libmpv, No App Around It**:
  * `tool/tv_m12/mpv_probe/` is a minimal Flutter app on the same media_kit fork and ref as `pubspec.yaml` (`My-Responsitories/media-kit`, `native`):
    * a full-screen `Video` widget and nothing else: no network, login, danmaku or HUD;
    * plays a local file in a loop;
    * reads `vo`, `hwdec` and any mpv option from a text file in its external files directory, like the M12.2 instrumentation;
    * prints mpv's log and frame counters to logcat;
    * stops itself after T seconds.
  * First, reproduce M12.2: the `vo=gpu` deadlock, and the `vo=mediacodec_embed` panic on `M2`. This confirms the probe behaves like the app.
  * Optional cross-check with the official mpv-android app, which has its own mpv and FFmpeg builds. Only with the user's approval to download and install it. Without a Flutter SDK on the development machine, it is also the cheapest way to run this matrix.
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
      * mpv with `vo=mediacodec_embed` on a real `SurfaceView` (finding 12);
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
  * 10 minutes of playback twice without one makes it **safe**. That is about two and a half times the slowest panic so far (234 s).
  * One 10-minute pass makes it **probably safe**.

## Run Protocol

1. **Before**: record the kernel uptime, `sys.boot.reason` and free storage. Start the log streams on the development machine and the sampler.
2. **Run** for the planned time: 20 s for deadlock sweeps, 60 s for a smoke test, 10 minutes for a verdict.
3. **After**: stop everything the run started (a trap, also on failure), stop the streams, record the counters.
4. **After a panic**: wait for the user's port, run the post-panic collection, and take the time to panic from the stream's last line.
5. Add one row per run to the run log below.

## Out of Scope

* Rooting, unlocking the bootloader, custom firmware.
* Opening the TV to reach the mainboard's serial console (UART). It would show the whole kernel log live, but the inside of a TV carries mains voltage and the warranty is at stake. The user's call only; not planned.
* Hidden factory or service menus, which can change the panel's calibration.
* The user's normal app and its settings.

## Run Log

| Run | Date | Task | Path | Stream | Options | Played | Dropped | Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| S1-1 | 2026-10-30 | CD2a | `ImageReader` | `V-AVC60` | images 2–12 × kept 0–6 × queued 0–4 (55 runs; 9 invalid, the screensaver held the hardware) | 10 s each | — | Freezes exactly when kept + queued ≥ 3; images make no difference |
| S1-2 | 2026-10-30 | CD2a | `ImageReader` | `V-AV1-60`, `V-HEVC60-8` | images 5 × kept 0–2 × queued 0–2 (16 runs) | 10 s each | — | AV1 freezes on any queued frame; this HEVC never froze |
| S1-3 | 2026-10-30 | CD2a | `ImageReader` | `V-AVC60-ref1`, `V-AVC-1080` | kept + queued 2–8 (8 runs) | 10 s each | — | 1 reference frame: freezes at 4 or more; 1080p: never |
| S1-4 | 2026-10-30 | CD2a | `ImageReader` | `V-AVC60` | kept 2, queued 2, with 5 format keys (low latency, MediaTek planar, low-latency, game mode, target size) | 10 s each | — | Freezes as without them |
| S1-5 | 2026-10-30 | CD2c | `SurfaceTexture` + GLES | `V-AVC60` | queued 2 | 10 s | 3 of 596 not shown before the end; 65 late | Plays at 60 fps; no freeze, no panic (a smoke test only) |
| S2-1 | 2026-10-30 | CD2c | `SurfaceTexture` + GLES, offscreen (nothing on screen) | `V-AV1-60` (looped) | queued 2 | 600 s | about 48 of 60 fps decoded | **No panic** in 10 minutes (the app panicked at 40 s and 190 s on this stream) |
| S2-2 | 2026-10-30 | CD1 | MiXplorer's player: the video drawn by the GPU into its window, one window layer composed by the hardware composer | `M4` (bilibili 4K60 AVC) | — | about 144 s | — | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C43C7F00`, block 24. The first this session |
| S2-3 | 2026-10-30 | CD3 | Probe app, `SurfaceView` (`DEVICE(MM)`, the video plane) | `V-AVC60` (looped) | queued 2 | 600 s | 196 of 35,954 late, 60 fps | **No panic**; AI post-processing active |
| S2-4 | 2026-10-30 | CD3 | Probe app, `TextureView` (one window layer) | `V-AVC60` (looped) | queued 2 | 600 s | 12,431 of 35,954 late, 60 fps | **No panic** |
| S2-5 | 2026-10-30 | CD3 | Probe app, `TextureView` | `V-AVC60` (looped) | queued 2, audio | 600 s | 14,141 of 35,949 late, 60 fps | **No panic** |
| S2-6 | 2026-10-30 | CD3 | Probe app, `TextureView` | `M4` | queued 2, audio | 600 s | 10,627 of 35,956 late, 60 fps | **No panic** |
| S2-7 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | — | 600 s | Position kept up | **No panic** |
| S2-8 | 2026-10-30 | CD1 | MiXplorer's player, the same command as S2-2 | `M4` | — | about 165 s | — | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C3BE5800`, block 24. The second this session |
| S2-9 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | second decoder at 350 ms, refused | 600 s | Position kept up | **No panic** |
| S2-10 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | second decoder at 350 ms, media session, audio focus | about 234 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C3BFDE00`. The third this session |
| S2-11 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `SurfaceView` (`DEVICE(MM)`) | `M4` | second decoder at 350 ms, media session, audio focus | 600 s | Position kept up | **No panic**: S2-10 with only the output changed |
| S2-12 | 2026-10-30 | CD1 | Just Player, Media3 1.11.1, `SurfaceView` (`DEVICE(MM)`) | `M4` | as the app ships | 600 s | Video plane active throughout | **No panic** |
| S2-13 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `SurfaceView` (`DEVICE(MM)`) | `M2` (AV1, looped) | second decoder at 350 ms, media session, audio focus | 600 s | Position kept up | **No panic** |
| S2-14 | 2026-10-30 | CD4 | mpv-android 2026-09-17 at its defaults (`vo=gpu`) | `M4` | cold start | 30 s | — | **Froze** within 5 s, as in M12.2: `C2BqBuffer` failures, GPU path |
| S2-15 | 2026-10-30 | CD4 | The same, the same settings | `M4` | app already running | 30 s | No `C2BqBuffer` failures, about 1,040 `Detile` lines a second | **Played** without a freeze: mpv's logs match S2-14 |
| S2-16 | 2026-10-30 | CD4 | mpv-android, `vo=mediacodec_embed` into its `SurfaceView` (`hwRender:1`) | `M4` | `mpv.conf` | 600 s | Video plane active throughout; one audio underrun warning | **No panic, no freeze** |
| — | 2026-10-30 | CD3 | Probe app | `M4` | media session, audio focus | — | — | **Invalid, not counted**: a bug in the probe's `clip` option quit the app at once, so nothing played |
| S2-17 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | media session, audio focus; no second decoder | about 264 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C43C7000`. The fourth this session |
| S2-18 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | media session only: no audio focus, no second decoder | about 174 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C3BF8400`. The fifth this session |
| S2-19 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | audio focus only: no session, no second decoder | about 119 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C3BEB200` (the kernel log; `sys.boot.reason` garbles it as `0x1c3bug200`). The sixth this session |
| S2-20 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | S2-7 repeated exactly, on a warm TV | about 178 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C3BEEE40`. The seventh this session |
| S2-21 | 2026-10-30 | CD5 | Probe app, `MediaPlayer` on a `TextureView` (`gdec:0`) | `V-AVC-1080` (looped) | warm TV | 600 s | Position kept up | **No panic** |
| S2-22 | 2026-10-30 | CD5 | Probe app, `MediaPlayer` on a `TextureView` (`gdec:1`) | `V-AVC30` (looped) | warm TV | 600 s | Position kept up | **No panic** |
| S2-23 | 2026-10-30 | CD2c | `SurfaceTexture` + GLES, offscreen (`gdec:1`) | `V-AVC60` (looped) | warm TV, queued 2 | 600 s | 5,540 of 35,955 late, 60 fps | **No panic** |
| S2-24 | 2026-10-30 | CD3 | Probe app, `MediaPlayer` on a `TextureView` | `M4` | S2-7 again, straight after S2-23 | about 11 s | Position kept up | **Panic**: `miup_hit_panic`, `CID 0xE000` read at `0x1C43C7000`, the same address as S2-17 (from `sys.boot.reason`). The eighth this session |
| S2-25 | 2026-10-30 | CD1 | Just Player, `SurfaceView` (`hwRender:1`) | `M2` (AV1, 5:32) | warm TV | 325 s | Video plane active throughout | **No panic** |
| S2-26 | 2026-10-30 | CD4 | mpv-android, `vo=mediacodec_embed` into its `SurfaceView` (`hwRender:1`) | `M2` (AV1, 5:32) | warm TV | 325 s | Video plane active throughout | **No panic, no freeze** |
| S2-27 | 2026-10-30 | CD4 | mpv-android, `vo=gpu` | `M4` | 2 runs from a running app, 2 from a fresh start | about 16 s each | — | **All 4 froze**: `C2BqBuffer` failures; no panic |

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

---

### [2026-10-30] Session 1: Setup, the Deadlock Explained Without mpv, and Desk Research (`CD0`, `CD2a`, `CD2c` Smoke Test, `CD7`, `CD8`)
* **Status**: `CD0` ✅; `CD2a` ✅; `CD2c` smoke test only; `CD8` 🔄. No panic-prone run yet, and the TV didn't reboot.
* **Branch**: `debug/tv-m12-crash`.
* **Files Changed**: `[NEW] tool/tv_m12/` (`lib.sh`, `run.sh`, `sampler.sh`, `probe.sh`, `postpanic.sh`, `variants.sh`, `CodecProbe.java`); `[MODIFY] docs/tv/M12_CRASH_DEBUG.md`.
* **Inputs from the user**: `M4`, bilibili's own 4K AVC encode (a 57-minute video), and the TV's adb address. The four videos were moved into a media folder outside the repository and renamed by ID.
* **Setup**:
  * adb had to run outside the tool sandbox to reach the TV.
  * All the variants in the Test Media table were made.
  * The harness and the clips under test were pushed to `/data/local/tmp/m12` on the TV (about 0.9 GB; 15 GB free). They stay there for the next session, and `probe.sh --clean` removes them.
* **TV checks** (`CD0`, read-only):
  * **Kernel log**: `logcat -b kernel` is readable from the shell, about 15,000 lines buffered. `dmesg` and `/proc/iomem` are denied.
  * **Sensors**: the thermal-zone and `devfreq` nodes (including the AI accelerator's `apusys_power:APUMDLA`) are denied. The CPU clock is readable: 1.8 GHz on all four cores at idle. `dumpsys thermalservice` reports a single temperature, 56 °C at idle, for every sensor type.
  * **Picture features**: `sys.vt.aipq.smart_scene_state=1`. The TV has `com.vt.tv.aipq`, `com.vt.tv.ai_sense` and `com.vt.tv.videocolor`.
  * **Players for `VIEW` on a local `video/mp4`**: FongMi TV (`com.fongmi.android.tv`) and MiXplorer's player. The TV's media center (`com.vt.tv.mediacenter`) has only a file browser and doesn't take `VIEW`, so CD1 drives it through its file browser or uses one of the two.
  * **Installed**: 云视听小电视 and YouTube. The dev app `PiliPlus TV dev` is no longer installed.
  * **Firmware**: build `UKN6.251123.001.049` (`00.00.00.49`), bootloader `01.01.260731`, kernel 5.15.192 (android14-11).
  * **Uptime**: 2.3 days since the third panic, with no panic since.
  * **Reboot recovery**: adb's mDNS discovery is switched off in this machine's adb environment, and forcing it on found no service. The user still sends the new port after a reboot.
* **The deadlock, without mpv** (`CD2a`; Findings 1–2): runs S1-1 to S1-5 in the Run Log.
  * mpv's own settings reproduce the freeze in the harness: 5 images, 2 kept, 2 queued. The AVC decoder delivers 5 frames, then stops, with `C2BqBuffer … consecutive failures` as in M12.2.
  * In every frozen run the buffer manager logs `[newBuffer_l] … mContinueFailCnt(512), mAllocatedCount(8), mMaxSlot(8)`. The decoder announces `WxH[3840 x 2176] … bufferCount:6, bufferSize:15671296`.
  * The rule from 79 valid runs: the slots are always the decoder's buffer count plus 2. The stream's references (B-frames, reference count) set the buffer count, and the reader's `maxImages` changes nothing.
  * The decoder lists 105 vendor parameters. Besides the picture-quality ones, they include `vendor.mtk.output.buffer.alloc.config.usage` and `vendor.mtk-codec2.non-tunnel-render-latency`, not tried yet.
* **The screensaver** (Finding 3): its photo player started at 00:46:45 and took `c2.mtk.jpeg.decoder` (`dumpsys media.resource_manager`). Every run after it failed at start, until the TV was woken.
* **Panic logs** (`CD7` on the three saved `SYSTEM_LAST_KMSG`s; Finding 4): saved outside the repository.
* **Desk research** (`CD8`):
  * mpv's upstream change (Finding 6), and which mpv the app's libmpv uses.
  * No public hits for `miup_hit_panic`, `[MIUP][HIT]` or the PQ notifier names. Mapping client `0xE000` needs the TV maker's GPL kernel source for this SoC (to request or download).
* **CD4 (barebone mpv)**: this machine has no Flutter SDK. A lighter route is the libmpv package the app's build downloads (the media_kit fork's `libmpv-android-video-build` release `20260906`, `default-armeabi-v7a.jar`, 6.4 MB, checked against the SHA-256 in the fork's `build.gradle`). It would be driven from an `app_process` harness with a small NDK shim, rendering into a `SurfaceTexture` like Flutter, so it's the exact libmpv without the app. Downloading it needs the user's approval.
* **What this means for M12.3**:
  * Fault 1 is a firmware limit: 2 spare output buffers at 4K. Through `vo=gpu` it could only be avoided if mpv held at most 2 frames for bilibili's AVC, and no queued frame at all for AV1. mpv's display loop always queues frames, so AV1 can't work on this path, and AVC is doubtful; CD4 would confirm with mpv's own options.
  * Option B (the 1080P60 cap) stays the safe fix.
  * The texture path doesn't freeze. Whether it panics without mpv and Flutter decides whether anything other than option F can bring 4K back.
* **Next** (session 2, panic-prone, needs the user's go-ahead and panic budget):
  1. `CD2c`: the texture harness for 10 minutes on `V-AV1-60`, then on `V-AVC60`.
  2. `CD1`: a TV player on the same clips.
  3. Then `CD6` (AI picture off) or `CD3`, depending on the results.

### [2026-10-30] Session 2: The Panic Reproduced Without mpv, and the Video Plane Survives (`CD1`, `CD2c`, `CD3`, `CD4`, `CD5`)

* **Status**: `CD2` ✅ (CD2b deferred); `CD3` ✅; `CD1`, `CD4` and `CD5` partly done; `CD6` low priority; `CD9` next. The findings are [above](#findings-so-far), 7–15; the runs are S2-1 to S2-27.
* **Result**: 4K60 drawn by the GPU to the screen panics the TV, in any player, on a warm TV, which is its normal state. 1080p60, 4K30 and offscreen 4K60 each survive one 10-minute run there. Nothing on the video plane has panicked, in three players, on AVC and AV1.
* **For the fix** (M12.3):
  * Option B's 1080P60 cap is supported.
  * Option D is explained: it panicked because Flutter's texture keeps the GPU in the path.
  * Option F looks promising. Just Player, on Media3 1.11.1, plays 4K60 AVC and AV1 with a media session and audio focus. HDR, Dolby Vision and network streams are still F1's to check.
  * A new candidate: mpv with `vo=mediacodec_embed` on a real `SurfaceView` (finding 12).
* **Wrong turns, kept here so that they aren't repeated**:
  * A refused second decoder (H10) and a media session (H11) each looked like the trigger, and neither was. Runs were added to a surviving setup in order, so every change coincided with the TV warming up. Finding 14 shows the order. Repeating the survivor unchanged settled it, and should come first next time.
  * One run counted as a survivor for a moment although nothing had played: the `clip` option stayed in the probe app's process. The empty log gave it away, and it is logged as invalid. Check a run's counters before trusting its result.
* **Device notes**:
  * A panic shuts the TV down; it doesn't reboot. `SYSTEM_LAST_KMSG` can lag by a boot, and `sys.boot.reason` can garble an address (`0x1c3bug200` for `0x1C3BEB200`), so take the address from the kernel log when it's there.
  * The TV's keyboard rewrites what `adb shell input text` types. The probe app's `clip` option puts text on the clipboard to paste instead.
* **Cleanup**: Just Player, mpv-android, the probe app and every test file are removed from the TV. The user's MiXplorer stays.
