> **Disclaimer**: This repo is entirely a product of wish coding, primarily completed by Argon at the beginning, then some 3.8 Flash and Opus/Sonnet 5.5 later.

<div align="center">
    <img width="160" height="160" src="assets/images/logo/logo.png" alt="PiliPlus TV logo">
    <h1>PiliPlus TV (Android TV + Overseas Acceleration)</h1>
    <p><a href="README.md">中文</a> | English</p>
    <p>A third-party Bilibili client engineered for <strong>Android TV D-pad navigation</strong> and <strong>overseas multi-threaded streaming acceleration</strong>.</p>
    <p>Built on top of <a href="https://github.com/lemonteaau/PiliPlus">lemonteaau/PiliPlus</a> (featuring <a href="https://github.com/MrTangLuyao/Bilibili-thread-ripper">Bilibili-thread-ripper / BTR</a>) and <a href="https://github.com/bggRGjQaUbCoE/PiliPlus">PiliPlus</a>, powered by a <strong>Three-Tier Decoupled TV Control Layer</strong> that syncs cleanly with upstream every week.</p>
</div>

---

## Key Features

### 1. Native-Grade Android TV & 10-Foot D-Pad Experience
- **2D Spatial Directional Focus Engine (`TvFocusTraversalPolicy`)**:
  - Smooth, predictable D-pad navigation across video grids, sidebars, settings lists, and dialogs, paired with a high-contrast focus ring (`#FFFFD166`) rendered on an isolated zero-rebuild `RepaintBoundary` layer.
  - **Multi-Layer Inline Sheet Focus Isolation & LIFO Promotion/Restoration**: Deep integration with `MiniScaffold` multi-layer inline bottom sheets (`Comment Details` / `Reply Dialog` / `Episodes` / `AI Summary`), auto-promoting focus on open, isolating underlying pages, and restoring focus to the trigger on dismissal.
  - **Pinned/Floating Sliver Header Smooth Scrolling & D-Pad Exit**: Full support for `SliverPinnedHeader` and `SliverFloatingHeaderWidget` — upward D-pad scrolling is never prematurely hijacked by pinned headers, with dual-coordinate directional exits.
  - **Embedded Comment Action Stepping**: Pressing D-pad Right on a comment card steps directly into its embedded action buttons (`Reply`, `View Thread`, `Like`, etc.), pressing Left steps back to the card, while Up/Down continues smooth single-card scrolling.
- **10-Foot Fullscreen & Split-Screen Player HUD (`TvPlayerHud`)**:
  - Dedicated TV On-Screen Display (OSD) overlay with D-pad transport controls for **Play/Pause, Previous/Next Episode, Episode/Part Picker, Video Quality, Playback Speed, Aspect Ratio, Danmaku Toggle, and Danmaku Settings**.
  - **Virtual Seek Target Accumulator**: Press Left/Right for `-10s / +10s` steps, or hold/rapid-press for smooth `1x → 2x → 3x` (`10s / 20s / 30s`) progressive scrubbing decoupled from hardware decoder latency.
  - **Hold-Select for 3.0x Temporary Speed**: Hold the remote `OK`/`Enter` key during playback for a `3.0x` temporary speed boost (`3.0倍速中`) and release to restore normal speed; a short press toggles Play/Pause.
  - **Remote Hold-to-Triple-Like**: Supports Like, Coin, and Favorite actions from the HUD—hold the Select/OK key on Like to trigger a **Triple-Like (一键三连)**.
  - **Split-Screen Quick Strip**: Top quick-action bar in detail view for instant fullscreen entry or episode switching.
- **Thoughtful TV Platform Adaptations**:
  - **Automatic QR Code Login Tab**: Automatically switches `LoginPage` to the QR-code tab on TV so you can sign in with your phone without typing on a remote.
  - **On-Demand Soft Keyboard Gate**: Traversing across `TextField`s with D-pad arrows never pops up the system IME until you explicitly press `OK`/`Enter`.
  - **Dialog Focus Handoff**: Dialogs shown above the app, such as the 🎉 update dialog opened from Settings → About → Version, take D-pad focus and the focus ring when they open, keep the page behind them unreachable, and hand focus back to the control that opened them when closed.
  - **Wired Ethernet Broadband Recognition**: Treats `ConnectivityResult.ethernet` as high-speed broadband on TV so 1080P+/4K streams are selected by default.
  - **TV Defaults**: On TV launches, fills in TV-optimal preferences that are not set yet (landscape layout, side navigation rail, dark theme, `1.2x` text scale, and `300dp` card width) without overwriting anything you changed. The player HUD depends on the **启用键盘控制** (Keyboard Control) switch, so keep it on.
- **Universal APK (Adaptive TV + Mobile Runtime)**:
  - The exact same APK automatically activates the TV control layer on **Android TVs, TV boxes, and projectors**, while running identically to standard touch-mode PiliPlus on **Android phones and tablets**.
- **Independent Package ID (`com.lemontea.piliplus.tv`)**:
  - Installed as **`PiliPlus TV`** (`com.lemontea.piliplus.tv`), allowing side-by-side coexistence with both official PiliPlus (`com.example.piliplus`) and LemonTea PiliPlus (`com.lemontea.piliplus`) on the same device.

### 2. Built-in Overseas Multi-Threaded Video Acceleration (BTR)
- **Faster Overseas Playback**: Splits video streams into chunks and downloads concurrently across multiple CDN nodes, significantly reducing buffering on overseas connections and 4K/high-bitrate streams (see [docs/thread-ripper.md](docs/thread-ripper.md)).
- **Works Out of the Box**: Enabled by default with overseas CDN nodes pre-selected.
- **Supports UGC & Bangumi/Movies**: Accelerates both regular videos and PGC episodes/movies/documentaries (excluding DRM-protected or preview-only streams and live streams).

#### Acceleration Settings
Located under **Settings → Audio & Video Settings** (changes take effect on the next video load):

| Setting | Default | Description |
| --- | --- | --- |
| Thread Ripper (线程撕裂者) | On | Master switch; turn off to use standard single-connection playback |
| PGC Acceleration (剧集加速) | On | Enable multi-threaded downloading for anime, movies, and documentaries |
| Overseas Nodes (海外节点) | On | Optimized for overseas networks; turn off if located in mainland China |
| Auto Concurrency (自动并发数) | On | Starts at 16 threads and dynamically scales between 8–64 threads based on buffering |
| Concurrency (并发数) | 8 | Fixed thread count (4–128) when Auto Concurrency is disabled |
| Custom Nodes (自定义节点) | Empty | Optional override to restrict downloads to specific CDN hosts |

---

## Known Issues

> [!WARNING]
> **On a TV with a MediaTek chip, turn on `4K 视频平面` before picking 4K, and don't pick 4K or higher without it.** On the one MediaTek MT9690 TV tested, without it 4K video freezes within seconds and the app then stops responding. 4K60 can also crash the TV's kernel and shut the TV down, and you have to turn it back on by hand.
>
> - TVs now default to **1080P 60 fps**. Existing installs that never changed the default quality get this too; a default you already chose is left alone.
> - This is a default, not a hard limit. You can still pick 4K in the player, and that pick is saved as the new default quality, so every later video is affected too. If you already picked 4K, change it back under `设置 → 音视频设置 → 默认画质` (Settings → Audio & Video → Default Quality).
> - **`设置 → 音视频设置 → 4K 视频平面`** (Settings → Audio & Video, TV only, off by default) sends the decoder straight to the TV's video layer, around the GPU. With it on, 4K60 AVC and AV1 played steadily inside the app on this TV. It applies the next time a video opens.
>   - On this path, super-resolution, flip, zoom and screenshots don't work, and neither do the `裁剪`, `等宽`, `等高` and `原始` fit modes. With heavy danmaku the UI drops to about 42 fps; the video itself isn't affected.
>   - Turning it off puts a default quality above 1080P 60 fps back to 1080P 60 fps.
>   - A video opened from a live room reuses the room's player, so it can't play 4K there. Go back to the home page and open the video again.
> - Only this one physical TV has been tested. Nothing suggests a problem on TVs with other chips so far.

---

## Download & Installation

Download the APK matching your device's CPU architecture from [Releases](../../releases/latest):

| Device Type | Recommended APK | Notes |
| --- | --- | --- |
| **64-bit Android TV / TV Box / Phone & Tablet** | `app-arm64-v8a-release.apk` | For Shield TV, Chromecast 4K, modern 64-bit TV boxes, and most phones/tablets |
| **32-bit Smart TV / Projector / TV Stick** | `app-armeabi-v7a-release.apk` | **Most physical smart TVs and projectors run a 32-bit OS; choose this if `arm64-v8a` fails to install** |
| **Android Emulator / x86_64 Device** | `app-x86_64-release.apk` | For x86_64 Android TV or mobile emulators |

---

## Automated Upstream Sync & Updates

This repository syncs weekly (every Saturday at `16:16 UTC`) with [`lemonteaau/PiliPlus`](https://github.com/lemonteaau/PiliPlus) (which tracks [`bggRGjQaUbCoE/PiliPlus`](https://github.com/bggRGjQaUbCoE/PiliPlus)) via GitHub Actions, automatically applying the TV patch pipeline and publishing new release APKs when upstream changes land.

- Release versions follow the format `2.1.6.2-fork.5720` (`<upstream_version>-fork.<commit_count>`).
- In-app update checks (**Settings → About → Check for Updates**) point directly to `liweichen6/PiliPlus-LemonTeaV`.

---

## TV Architecture & Developer Documentation (`docs/tv/`)

All Android TV functionality is isolated into a **Three-Tier Decoupled TV Control Layer** (`lib/tv/*`, build-time patches in `lib/scripts/tv_*.patch`, and `< 20 lines` of upstream hooks). Full documentation is available in `docs/tv/`:

| Document | Description |
| :--- | :--- |
| [**docs/tv/README.en.md**](docs/tv/README.en.md) ([中文](docs/tv/README.md)) | **TV module overview, upstream sync guide (GitHub Actions & local CLI), local APK build guide, and signing setup** |
| [**docs/tv/ARCHITECTURE.md**](docs/tv/ARCHITECTURE.md) | **Three-Tier Decoupled TV Control Layer specification**, performance & hardening mechanisms (`F1`–`F9`, `M6`–`M9`), and 22 preserved TV invariants (`C1`–`C22`) |
| [**docs/tv/REVIEW.md**](docs/tv/REVIEW.md) | **Comprehensive Android TV layer review**: file-by-file engineering audit, technical observations (`R1`–`R7`), and upstream merge risk matrix |
| [**docs/tv/PLAN.md**](docs/tv/PLAN.md) | Complete milestone, epic, and task roadmap across Phase 1 (Foundation), Phase 2 (Optimization), and Phase 3 (Remediation) |
| [**docs/tv/PROGRESS.md**](docs/tv/PROGRESS.md) | Task-by-task changelog, performance benchmark tables, and dual-device verification logs |
| [**docs/thread-ripper.md**](docs/thread-ripper.md) | Architecture and adaptive concurrency design of the Bilibili-thread-ripper (BTR) engine |

---

## Acknowledgements & License

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus): The core upstream project, licensed under [GPL-3.0](LICENSE) (this repository is distributed under the same license).
- [lemonteaau/PiliPlus](https://github.com/lemonteaau/PiliPlus): Upstream fork integrating overseas multi-threaded video acceleration (BTR).
- [N3urda/PiliPlus-TV](https://github.com/N3urda/PiliPlus-TV): Source of inspiration — originally intended to merge `lemonteaau` into it, but as fixing one issue kept uncovering more, decided to rebuild from scratch onto `lemonteaau` instead.
- [MrTangLuyao/Bilibili-thread-ripper](https://github.com/MrTangLuyao/Bilibili-thread-ripper): Origin of the multi-threaded streaming proxy concept, licensed under MIT (see [docs/licenses/bilibili-thread-ripper.txt](docs/licenses/bilibili-thread-ripper.txt)).
