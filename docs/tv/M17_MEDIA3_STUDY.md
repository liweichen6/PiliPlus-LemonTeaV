# M17 Study: Media3 for the TV Player

**Status**: ✅ Done. `M17.1` and `M17.2` were finished on 2026-11-12 and `M17.3` on 2026-11-13, which closes Epic M17.1. The spike, `M17.4`, is next.

This file is Epic M17.1 of [`PLAN.md`](./PLAN.md): what to learn from other people's code before M17's spike touches the TV. It has one section per task. Everything here comes from reading. Nothing was built, installed or run, and no device was used.

## M17.1: The PiliPlus Media3 Forks as They Are Now

### What Was Read

Each fork was cloned and read at one commit. "Upstream at" is the commit of `bggRGjQaUbCoE/PiliPlus` the fork last merged, and the two sizes are the fork's whole difference from it.

| Fork | Branch | Commit | Commit date | Upstream at | Media3 | `lib/plugin/pl_player/controller.dart` | Files changed |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `kkren/PiliPlus` | `main` | `b8d0945f4` | 2026-11-03 | `d9e9626f1` (2.2.0.2) | 1.10.1 | +561 −168 | 89 |
| `AvalonUltra/PiliPlus` | `main` | `e3ef0a646` | 2026-11-03 | `d9e9626f1` (2.2.0.2) | 1.10.0 | +635 −32 | 67 |
| `yifgu/PiliPlus` | `main` | `b4d3c7e69` | 2026-11-12 | `915276c87` | 1.11.1 | +271 −19 | 42 |
| `loneshu7/PiliPlusPlus` | `sync/upstream-20261102-3e2ef60` | `5bdf4bfd6` | 2026-11-04 | `3e2ef609` | 1.10.1 | +1,121 −158 | 126 |

* **Upstream PR 2145** (`PA733:feat/hdr`, head `d37d0a766`): nine commits, all on 2026-05-18, closed unmerged on 2026-07-02; 20 files, +1,882 −149. AvalonUltra's `HdrPlayerPlugin.kt` is the same file, byte for byte, so the Android half of AvalonUltra is PR 2145. AvalonUltra's author (`dianjin`) added an iOS player and later fixes on top.
* **loneshu7's default branch is behind.** `main` is `4f386389d` from 2026-09-06. The work goes on in the sync branch above, which contains `release/2.1.10`.
* **None of the four has issues enabled.** So "what the author found broken" comes from commit messages, code comments, READMEs and loneshu7's own log.
* All four are GPL-3.0, as this repository is.

### The Table

File names used in the table, for each fork at its commit above:

* **kkren**: `Kt` is `android/app/src/main/kotlin/com/example/piliplus/Media3PlayerPlugin.kt`, `Dart` is `lib/plugin/pl_player/media3/media3_player_controller.dart`.
* **AvalonUltra**: `Kt` is `.../piliplus/HdrPlayerPlugin.kt`, `Dart` is `lib/plugin/pl_player/models/android_hdr_playback_backend.dart`.
* **yifgu**: `Kt` is `.../piliplus/Media3Session.kt`, `Br` is `.../piliplus/Media3Bridge.kt`.
* **loneshu7**: `Kt` is `.../piliplus/ExoPlayerPlugin.kt`, `Doc` is `docs/android_exoplayer.md`.
* **All four**: `Ctl` is `lib/plugin/pl_player/controller.dart`.

| Question | kkren | AvalonUltra (PR 2145) | yifgu | loneshu7 |
| :--- | :--- | :--- | :--- | :--- |
| **Which videos it plays** | Every video and every live room while `播放器内核` is Media3. The setting is read once for each controller (`Ctl` 194) | Only qualities 125, 126 and 129, with the setting on. Not live, and not with flip, 听视频, 超分辨率 or rotation (`Ctl` 951–973, 986–1007) | Only a stream whose codec string says Dolby Vision Profile 5, with its setting on Media3. Not live, not 听视频 (`Ctl` 754–759) | Everything. Its aim is to remove mpv on Android |
| **How video and audio become a source** | A fixed quality: two sources from `DefaultMediaSourceFactory`, joined by `MergingMediaSource(true, true, …)` (`Kt` 467–480). The quality `自动`: one DASH manifest built in Dart, with the audio inside it (see below) | Two `ProgressiveMediaSource`s in `MergingMediaSource(video, audio)`, with no offset adjustment and no clipping (`Kt` 464–475). A URL containing `.mpd` goes to `DashMediaSource` (`Kt` 492–494) | Two `ProgressiveMediaSource`s in `MergingMediaSource(true, …)` (`Kt` 150–163). The two URLs are passed apart, never as mpv's `edl://` string | Two sources from `DefaultMediaSourceFactory` in `MergingMediaSource(true, true, …)`, when the audio URL differs from the video URL (`Kt` 591–634) |
| **Headers, and the thread ripper's loopback URLs** | `User-Agent` by `setUserAgent`, `Referer` as a default request property (`Kt` 188–191, 439–446). It has this fork's thread ripper (since `0e4f8c87`, 2026-10-17). The loopback URLs go in unchanged, with two changes around them: cleartext to `127.0.0.1` is allowed in `res/xml/network_security_config.xml`, and the proxy is told not to cancel a track's earlier request (`supersedeTrackRequests`, `Ctl` 901) | Both headers as default request properties; cross-protocol redirects allowed (`Kt` 488–491). No ripper, so Media3 fetches the CDN URLs | Headers checked for CR and LF in Kotlin (`Media3Request.kt` 30–37), then default request properties (`Kt` 150). No ripper. Only `http(s)` URLs or an absolute path are accepted | Headers as default request properties plus `setUserAgent`; cross-protocol redirects allowed (`Kt` 593–596). No ripper. `//upgcxcode/` in a CDN URL is rewritten to one slash (`MediaUri.kt` 8–19) |
| **Order of calls on open** | The open waits in a Dart queue until the platform view exists, because the view factory creates the player (`Dart` 241–261, `Kt` 59–71). Then `setMediaSource`, `seekTo(start)`, `playWhenReady`, `prepare` (`Kt` 454–465) | A new ExoPlayer for every open (`Kt` 64–68, `Ctl` 1011–1050). `setMediaSource`, `prepare`, then `seekTo(start)` when it isn't 0, so loading starts at 0 first (`Kt` 277–281). Play is a separate call | One method call that returns only when playback ends. A new ExoPlayer, the view attached, then `setMediaSource`, `seekTo`, `setPlaybackSpeed`, `playWhenReady = true`, `prepare` (`Kt` 164–170) | `setMediaSource(source, startPosition)`, then `prepare`, on a player that already holds its surface (`Kt` 636–645). Every event carries a generation number, so events from an older open are dropped (`Kt` 1096–1102) |
| **Seek** | `seekTo`, exact (`Kt` 382–386) | `seekTo`, exact (`Kt` 293–295) | `seekTo`, exact (`Kt` 200–202) | `seekTo`, exact (`Kt` 199–203) |
| **Quality switch, next video, 重载视频, and what survives** | The same ExoPlayer gets another open. Speed and volume stay on the player. The HDR window mode is dropped and set again from the new format (`Kt` 697–698, 262–270). 重载视频 prepares the same URLs again at the current position (`Kt` 365–371). A subtitle change also prepares the whole source again (`Kt` 406–413) | Each one disposes the session and builds a new one, so the decoder starts over and Dart has to set the speed again (fix `984c75eb`). Flip, 听视频, 超分辨率 or rotation switch to mpv in the middle of a video (`Ctl` 1051–1068) | A new source closes the session and opens another. Position and speed are carried in Dart, under a source counter that drops late results (`Ctl` 748–752, 1051–1173) | The player stays and only the `MediaSource` is replaced. Position and play intent ride in the request; speed, volume, mute and the subtitle choice stay on the player (`Doc` 133–139). A retry is `seekTo` and `prepare` on the same source (`Kt` 727–738) |
| **View type, and the surface's life** | `PlayerView` with `surface_type=surface_view`, in a platform view made by `initSurfaceAndroidView` (`Dart` 184–219). The player belongs to a session keyed by player id, so a new platform view takes over the same player (`Kt` 53–72, 313–335). The view is hidden before the page pops (`lib/pages/video/view.dart` 300–305) and rebuilt by a version counter. Nothing in Kotlin handles Home, back or sleep | One `PlayerView` for a session, handed to every platform view that asks (`Kt` 229–243), made by `initSurfaceAndroidView` (`Dart` 159). Rebuilt by a version counter once `open` has a session id (`Ctl` 1044–1049). `setKeepContentOnPlayerReset(true)` and a transparent shutter keep the last frame (`Kt` 257–262). Nothing in Kotlin handles Home or sleep | A platform view in the video page since 2026-11-04 (`4b99a229`); before that, its own activity. Made by `initExpensiveAndroidView`, "to preserve the SurfaceView's HDR output" (`lib/plugin/pl_player/view/media3_video_view.dart` 23–24). Each platform view is an empty `FrameLayout` that the session's view is moved into (`Br` 23–37, 74–82). `onStop` pauses and nothing resumes (`MainActivity.kt` 26–29) | A Flutter texture from `createSurfaceProducer(resetInBackground)`. The surface is set again in `onSurfaceAvailable` and cleared in `onSurfaceCleanup` (`Kt` 299–301, 379–392). No `SurfaceView`, on purpose (`Doc` 37–39) |
| **HDR signalling, and what it does for SDR video** | On each video input format: when the transfer is PQ or HLG and the display reports any HDR type, the window gets `COLOR_MODE_HDR`, and on API 35 and later `setDesiredHdrHeadroom(1.0)` on the window and `(4.0)` on the `SurfaceView` (`Kt` 563–618). SDR video: `COLOR_MODE_DEFAULT` and headroom 0. Reset on every open and on dispose | Dart turns `COLOR_MODE_HDR` on when the backend opens and off when the last session is disposed, by a reference count (`Kt` 165–190). The backend only opens for HDR qualities, so SDR video never has it. No headroom calls | `COLOR_MODE_HDR` when the session starts; the earlier mode is put back on close (`Kt` 54, 74, 245). Only Dolby Vision plays there. No headroom calls | None. Flutter composites the texture in SDR |
| **The Dolby Vision rule, and HDR Vivid** | None. Default renderers and codec selector, so Media3 picks any decoder it accepts. HDR Vivid has no case of its own and is treated by its transfer function | None in the player. `supportsHdr` asks for HDR10 on the display for 125, and for any HDR type at all for 126 and 129, with a comment that such a display can show Dolby Vision "through an HDR10-compatible output path" (`Kt` 192–213). On failure it falls back to mpv | Four checks. The display reports Dolby Vision (`Kt` 69–72). A `video/dolby-vision` decoder exists (77–80). A `MediaCodecSelector` returns no decoder for any other video type (82–89). The selected track is `video/dolby-vision` with codecs `dvhe.05` or `dvh1.05` (125–137, 256). Any miss closes the session with a message. Profile 8.4, HDR 真彩 and HDR Vivid stay on mpv | None, as it has no HDR output |
| **Audio: which tracks, and how** | Whatever track the app chose (AAC, 杜比全景声 or Hi-Res), to Media3's default audio renderer. No audio attributes, so audio focus stays with Dart. The manifest for `自动` declares 2 channels for any track | Under this backend the app's list drops Hi-Res (30251) and 杜比全景声 (30250, 30255), so AAC plays (`lib/pages/video/controller.dart` 1146–1163). An audio renderer error reopens the video with no audio at all (`Ctl` 1570–1583). No audio attributes | Whatever the app chose. `USAGE_MEDIA` and `CONTENT_TYPE_MOVIE`, with ExoPlayer handling audio focus, and `setHandleAudioBecomingNoisy(true)` (`Kt` 92–96). Dart's audio session is deactivated first (`Ctl` 1085) | Whatever the app chose, through a `DefaultAudioSink` with its own normalization processor (`Kt` 1447–1467). Focus stays in Dart, in the shared controller (`Doc` 185–200) |
| **Subtitles** | The VTT text is written to a cache file and side-loaded; `PlayerView` draws it natively (`Kt` 500–522). Flutter's `SubtitleView` is hidden (`Ctl` 198) | Parsed in Dart (VTT, SRT, ASS) into cues. Each position event picks the current text for a plain `Text` widget (`Ctl` 580–605, 2418–2513; from PR 2145) | None | Side-loaded; Media3 parses and times them. `onCues` sends the cues, bitmaps included, to a Flutter overlay (`Kt` 688–710; `lib/plugin/pl_player/exo_player/exo_subtitle_cue.dart`) |
| **Error mapping and retries** | `error.message`, or the code's name, as a bare string into upstream's handler (`Kt` 215–217). It matches none of the mpv patterns there, so nothing retries and nothing is shown. `playing` stays true, because it's read from `playWhenReady` (`Kt` 544–547) | A map with the code, cause, renderer name and format, and an audio flag (`Kt` 389–419), joined into one string in Dart. One rebuild at the current position; a second error within 30 s falls back to mpv with `已使用兼容播放` (`Ctl` 1544–1590) | Any error closes the session and shows `Media3 播放失败：… 请在音视频设置中切回软解，并重新打开视频`. No retry and no fallback (`Kt` 98–100, 249–253; `Ctl` 1181–1189) | A map with a category (network, source, decoder, drm, remote, unexpected), a phase, `recoverable`, the HTTP status, the URL without its query, and the cause chain (`Kt` 1589–1694). Dart retries recoverable network errors with a growing delay, and a decoder error once on a software decoder (`lib/plugin/pl_player/models/exo_player_failure.dart` 140–158; `Kt` 740–788) |
| **Position events across the channel** | The whole state map, with formats and decoder counters, every 500 ms, on every player event, and up to four times a second while bytes arrive (`Kt` 195–201, 538–561, 668–685) | Three events (position, duration, buffered) every 250 ms while playing or buffering (`Kt` 429–462) | One state map every 500 ms and on every player event (`Kt` 55–61, 221–229) | A small `progress` event every 250 ms, and the full state map on every player event (`Kt` 103–111, 1054–1091) |
| **Devices named** | None | The PR author's phone; a Pixel 7 Pro in a comment | None. The README asks users to compare on their own device | A Samsung SM-S9180 on Android 16 |
| **What its author found broken** | The manifest had to be base64; cleartext to the proxy; seams during the back gesture | Dark danmaku; a black screen on reload; an audio error taking the player down; crashes in upstream code that assumed mpv | Green or purple Profile 5 through mpv's hardware decoding; lifecycle crashes | A black picture on one phone; a 403 from a doubled slash; a byte budget that starved loading |

Notes on the table:

* **Why kkren keeps both kinds of source.** The DASH manifest is only for a quality it added, `自动`. `lib/utils/dash_mpd_utils.dart` (174 lines) writes one `Representation` for each quality of one codec, with the `SegmentBase` ranges Bilibili already sends, so Media3 itself switches quality by bandwidth. A fixed quality has nothing to adapt, so it goes in as two merged sources. With the ripper on, each `Representation` gets its own loopback URL. This fork has no `自动` quality and M17 doesn't add one, so only the merged form matters here.
* **No fork changes Media3's seek parameters, turns tunneling on, or sets a wake mode.** Only yifgu gives ExoPlayer audio attributes.
* **None was tested on a TV**, and the last row is short on purpose: the details are below.

### What Each Author Found Broken

* **kkren** (terse commit messages, no log):
  * `5a806d6c` (2026-06-29): the generated manifest only loaded once it was base64 in the `data:` URI.
  * `0e4f8c87` and `4be4ef5b` (2026-10-17): Media3 reaches the ripper's proxy over plain HTTP, which the app's network security policy has to allow. The second commit narrows it to `127.0.0.1`.
  * `lib/pages/video/view.dart` 599–608: a 2-pixel black strip over the top of the player, "to cover subpixel gaps exposed by Android predictive back scaling", and the surface is hidden before the page pops. Both are signs of the platform view not following Flutter's route animation.
* **PR 2145** (`PA733`, all 2026-05-18):
  * Danmaku is too dark over HDR video (the author's comment on the pull request; a phone).
  * `ded5f5dae`: a black screen when the buffer emptied or the video was reloaded.
  * `e0704a62a`, `83b1392e6`: an audio decoder error took the whole HDR player down. The code comment names a Pixel 7 Pro, which can't decode 杜比全景声, so 杜比视界 fell back to SDR there.
* **AvalonUltra** (`dianjin`):
  * `70744ad8` (2026-07-12): pause and seek gestures crashed under the HDR backend. Upstream code does `videoPlayerController!` in many places, and under this backend there is no media_kit player.
  * `39402a27` (2026-07-12): errors in the middle of a stream were common enough to need one retry before the fallback.
  * `984c75eb` (2026-10-14): 1× speed was ignored, and the speed was lost after a quality switch. The backend never recorded its rate, and a new session didn't get the user's speed.
  * `acd5e7c4` (2026-07-31, iOS): the audio-error test matched keywords in the whole error text, the text held a URL, and `ec-3` in it was taken for an audio error, so the audio track was dropped. The Android test still matches `eac3`, `ec-3` and `audio/` (`Ctl` 1602–1611).
  * `b4694785` (2026-10-29, iOS): a black picture after coming back from another video. All video pages share one `PlPlayerController`, and one native view was moved between two platform views. The Android side still hands one view to every platform view.
  * `ce432849`, `dd5b5792` (iOS): sound was lost when media_kit was disposed after the native player had started. The code is iOS only. The cause is general: two players and one audio session for the process.
* **yifgu**:
  * The README and `0beeaffb` (2026-10-26): Profile 5 decoded by hardware through mpv comes out green or purple, so its `mediacodec` and `mediacodec-copy` options for Profile 5 were removed, and mpv's route for it is software decoding with `gpu-next`.
  * `ba68c14c` (2026-10-25): `hdrCapabilities` can be null.
  * `785474be`, `6da6f7e7` (2026-10-26): a crash from entering fullscreen before the window existed, and a theme lookup that failed in release builds.
  * `4b99a229`, `abcf1614` (2026-11-04): the move from an activity to a platform view, then fixes to the bridge's lifecycle.
  * The README's own limits: no danmaku, external subtitles, SponsorBlock, background play or picture-in-picture; going to the background pauses, and the user resumes by hand.
* **loneshu7** (`Doc`, a dated log of builds and device checks):
  * 2026-08-02, a Samsung SM-S9180 on Android 16: every video was black while the position advanced, after one build added a custom codec selection and a custom `DefaultLoadControl` (`Doc` 1110–1117, 1193–1250). Both went back to Media3's defaults and the picture returned. The buffer settings then came back alone and the picture stayed, which pointed at the decoder settings. The cause was never confirmed.
  * The buffer (`Doc` 1263–1271, `Media3BufferPolicy.kt` 14–27): Media3 counts the byte budget against everything allocated, the back buffer included, so a small byte target can stop loading before the time minimum is reached. Its mapping now: minimum and maximum both set to the app's buffer duration, the start thresholds left at Media3's 1 s and 2 s, the app's byte size as the target, and no back buffer.
  * 2026-08-25: a CDN URL of the form `https://host//upgcxcode/…` got a 403 through Media3. And a listener that removed itself during dispatch threw.
  * `Doc` 1214–1220: it added a first-frame flag to 播放信息, to tell "no frame decoded" from "a frame decoded but not shown".
  * Never verified, by its own count: restoring after process death, and foldables.

### What This Changes in the Plan

1. **The ripper's URLs need a manifest change before Media3 can open them.** They are `http://127.0.0.1:…`. mpv opens its own sockets, so Android's cleartext policy never applied. Media3's `DefaultHttpDataSource` goes through the platform's HTTP stack, which refuses cleartext unless the app allows it. This app targets SDK 37 and has neither `usesCleartextTraffic` nor a `networkSecurityConfig`. kkren's 7-line file allows `127.0.0.1` and nothing else. `M17.4` needs it for its first open, and it's one more upstream file (`AndroidManifest.xml`) in the hook list for `M17.3`.
2. **杜比视界 isn't one profile.** yifgu separates Profile 5 (`dvhe.05`, `dvh1.05`) from Profile 8.4. Profile 5 has no picture an HEVC decoder can show correctly, which is what the plan's rule is about. Profile 8.4 has an HLG base layer, so an HEVC decoder shows a correct HLG picture. The plan's rule, "never decoded as plain HEVC", is right for Profile 5 and too strict for 8.4. `M17.2` decides the wording; `M17.5` should record the `codecs` string of every quality-126 stream it meets, since reading can't say which profiles Bilibili serves to this account.
3. **Only kkren makes the headroom calls.** The plan said kkren and PR 2145 both do. PR 2145 sets `COLOR_MODE_HDR` and stops there. So `M17.5` has three cases to compare, not two: no window calls, the color mode alone, and the color mode with headroom. `PLAN.md` is corrected.
4. **yifgu's player is no longer a separate screen.** Since 2026-11-04 it's a platform view under Hybrid Composition inside the video page. It still has its own native controls and no danmaku. As a fallback design it's now closer to the adapter than the plan assumed, and it's the only fork that states why it chose `initExpensiveAndroidView`.
5. **Every fork had to work around upstream code that assumes a media_kit player.** AvalonUltra crashed on it (`70744ad8`) and lost the speed (`984c75eb`). kkren and yifgu wrap each access in a getter of their own (`currentPlayerRate`, `isCurrentPlayerPlaying`, `currentPosition`). This is the cost the adapter is meant to avoid: with `TvExoPlayer implements NativePlayer`, `videoPlayerController` is never null and `state.rate` is the adapter's to keep right.
6. **A custom codec selector is the one change tied to a black picture.** loneshu7's case is unconfirmed, and its selector filtered for software decoders, not Dolby Vision. Still, yifgu's rule is a custom selector too. So `M17.4` runs with Media3's default selector, and `M17.5` adds the Dolby Vision selector as its own step, with a first-frame flag to read.
7. **Two forks keep the player and swap the source; one rebuilds the player each time.** Rebuilding lost the speed and restarts the decoder on every quality switch. The adapter keeps one ExoPlayer for the life of the `Player` object, which is also what `PlPlayerController` expects of mpv.

### Pieces to Adapt

Each entry names where it would go. Credit lines, to put in the header of any file that takes code from a fork:

* `Adapted from kkren/PiliPlus (GPL-3.0), commit b8d0945f4.`
* `Adapted from PiliPlus pull request 2145 by PA733 (GPL-3.0), commit d37d0a766.`
* `Adapted from AvalonUltra/PiliPlus (GPL-3.0), commit e3ef0a646.`
* `Adapted from yifgu/PiliPlus (GPL-3.0), commit b4d3c7e69.`
* `Adapted from loneshu7/PiliPlusPlus (GPL-3.0), commit 5bdf4bfd6.`

| # | Piece | Source | For |
| :--- | :--- | :--- | :--- |
| 1 | Cleartext to `127.0.0.1` only | kkren: `android/app/src/main/res/xml/network_security_config.xml` (whole file), `android/app/src/main/AndroidManifest.xml` 41 | `M17.4`, `M17.7` |
| 2 | Two progressive sources merged, with the headers on one HTTP factory | yifgu `Kt` 150–163 (explicit `ProgressiveMediaSource.Factory`, so no type sniffing); kkren `Kt` 188–191, 439–446, 467–480 | `M17.7` |
| 3 | Start position given with the source, and a generation number on every event | loneshu7 `Kt` 636–645, 1096–1102 | `M17.7`, `M17.8` |
| 4 | A player that outlives its view | kkren `Kt` 53–94, 313–335 (a session map; attach and detach); yifgu `Br` 23–37, 74–82 (an empty host view per platform view) | `M17.7`, with M16's `TvVideoPlane` |
| 5 | The Dolby Vision checks | yifgu `Kt` 69–72 (display), 77–80 (a decoder exists), 82–89 (the selector), 125–137 and 256 (the selected track's profile); `lib/plugin/pl_player/models/dolby_vision_profile5_mode.dart` 24–29 (the same test in Dart) | `M17.2` for the rule, `M17.7`, `M17.9` |
| 6 | Audio attributes, and pausing when the audio route is lost | yifgu `Kt` 92–96; `Ctl` 1085 (Dart's session released first) | `M17.2` decides who holds focus; `M17.7` |
| 7 | The error event and its kinds | loneshu7 `Kt` 1589–1694 (category, phase, `recoverable`, HTTP status, URL without its query, cause chain); `lib/plugin/pl_player/models/exo_player_failure.dart` (158 lines: user messages, the retry test). PR 2145 `Kt` 389–419 for the renderer's name and format | `M17.7`, `M17.8`, `M17.11` |
| 8 | Subtitle cues from the VTT text the app already has | PR 2145, as in AvalonUltra `Ctl` 2418–2513 (the parser) and 580–605 (the lookup by position) | `M17.8` |
| 9 | The window's HDR calls, as cases to compare | kkren `Kt` 563–618 (color mode and headroom); yifgu `Kt` 54, 245 (put the earlier mode back); `colorMode` added to `configChanges` in kkren's and AvalonUltra's manifests | `M17.5` |
| 10 | Facts for measuring and for 播放信息 | kkren `Kt` 638–658 (the display's HDR types, `hdrSdrRatio`), 718–822 (formats, color info, decoder names, dropped frames, decoder counters); loneshu7 `Kt` 790–793 (first frame rendered) | `M17.4`, `M17.5`, `M17.10` |
| 11 | The app's buffer settings as a Media3 load control | loneshu7 `Media3BufferPolicy.kt` (51 lines), `Kt` 1561–1574, and its JVM test `Media3BufferPolicyTest.kt` | `M17.2` decides the values; `M17.7` |
| 12 | Speed kept in the Dart state and applied to a new source | AvalonUltra `Dart` 95–110, commit `984c75eb` | `M17.8` |
| 13 | A counter that drops results from an older source | yifgu `Ctl` 91, 748, 1051–1173 | `M17.8` |
| 14 | Fail-closed wording | yifgu `android/app/src/main/res/values-zh/media3_strings.xml` 23–25 (no Dolby Vision display, no decoder, wrong profile); `Ctl` 1181–1189 | `M17.9` |
| 15 | Pause on `onStop` | yifgu `MainActivity.kt` 26–29 | `M17.7`; `M17.2` settles Home and sleep |
| 16 | The doubled-slash fix | loneshu7 `MediaUri.kt` 8–19 | Only where Media3 fetches a CDN URL itself: the ripper off, or fallen back to the direct source |
| 17 | The proxy's switch for a track's earlier request | kkren `lib/services/thread_ripper/range_proxy.dart` 21, 27, 521 | `M17.4` finds out whether it's needed (below) |
| 18 | Small JVM tests for the Kotlin's pure parts | yifgu `Media3RequestTest.kt`; loneshu7 `Media3DecoderModeTest.kt`, `Media3BufferPolicyTest.kt` | `M17.11` |

### What Not to Copy

1. **A second code path through `controller.dart`.** All four have one, 270 to 1,120 lines. It's the reason for the adapter.
2. **Falling back to mpv, or to a software decoder.** AvalonUltra does the first (`Ctl` 1005, 1586) and loneshu7 the second (`Kt` 740–788). On `<physical-tv>`, mpv above 1080P60 is the path that freezes, and 4K in software can't keep up. M17's rule is to stop and say so, as yifgu does.
3. **AvalonUltra's `supportsHdr`.** It lets 杜比视界 through on any HDR display (`Kt` 202–209), the opposite of the Dolby Vision rule. kkren has no check at all.
4. **Finding audio errors by keyword.** AvalonUltra's matcher (`Ctl` 1602–1611) is the one that misfired on iOS. Media3 says which renderer failed; use that.
5. **One native view shared by every platform view** (AvalonUltra `Kt` 229–243). All video pages share one controller, so two platform views exist during a route change.
6. **A player created by the view factory** (kkren `Kt` 59–71). Dart then has to queue calls until a view exists (`Dart` 241–261), and a player with no view can't exist. The channel creates the player; a view attaches when there is one.
7. **A new ExoPlayer for every open** (AvalonUltra `Ctl` 1011–1050; yifgu).
8. **Subtitles drawn by `PlayerView`** (kkren). It's a native layer the app's subtitle settings don't reach, and kkren prepares the whole source again to change the track.
9. **The whole state map on a timer** (kkren `Kt` 195–201, 538–561). Formats and decoder counters cross the channel at least twice a second, and every one lands on the UI thread, which is the thread M17's performance bar is about. A position event should carry three numbers; the rest is sent when it changes or when 播放信息 asks.
10. **`playing` read from `playWhenReady` alone** (kkren `Kt` 544–547): after an error the player is idle and still reports playing.
11. **kkren's volume scale**: a value above 1 is taken as a percentage and anything else as a fraction (`Kt` 393–397), so 1 % plays at full volume.
12. **`prepare` before `seekTo`** (AvalonUltra `Kt` 277–281): the first request is for the start of the file. Through the ripper that's a wasted session.
13. **loneshu7's route as a whole**: a texture has no HDR, and matching every mpv feature (Media3 effects for 超分辨率, an audio processor chain) is the 1–2 weeks the plan doesn't propose.
14. **yifgu's native controls**, and an `open` call that returns when playback ends. They fit a player with no Flutter UI over it.

### TV Checklist for `M17.12`

loneshu7's compatibility gates (`Doc` 41–77), cut down to what a TV with a remote can meet and what M17 keeps. Each line is a thing to try with ExoPlayer on, and again with the setting off to see mpv unchanged.

* **Rendering and the remote** (from "Rendering and interaction"):
  * The HUD, danmaku and subtitles show over the video plane, in split view and in fullscreen.
  * Select plays and pauses; Left and Right seek, with the acceleration; holding Select gives 3× and releasing it gives the earlier speed back.
  * Split view to fullscreen and back keeps the picture and the position.
  * Each 画面比例 entry that's offered changes the picture. None is offered that does nothing.
* **Playback state** (from "Playback state"):
  * Open with a resume position; pause; seek forward and back, inside the buffer and outside it; play to the end; replay; 循环; the next video by 自动连播.
  * 播放信息 shows the duration, position, buffer, speed, resolution and decoder, and they match what's on screen.
  * A quality switch keeps the position, the play or pause state, the speed and the volume.
  * 重载视频 comes back at the same position.
  * A live room opened from a video, and a video opened from a live room, each play on the right player.
* **Video features** (from "Video features"):
  * Danmaku on, off, and at the heaviest setting.
  * Bilibili's subtitles on and off, and a change of track, without the video stopping.
  * Chapters and SponsorBlock segments on the time bar, and a SponsorBlock skip.
  * A multi-part video, a PGC episode, and a playlist: the next item opens on ExoPlayer.
* **Audio** (from "Audio and tracks"):
  * The remote's volume keys and mute.
  * Another app taking audio focus pauses playback; the remote's media keys play and pause.
  * Each audio quality the list offers plays with sound.
* **System** (from "System and utilities"):
  * Home and back to the app; the TV asleep and awake again; another app opened over this one.
  * The network dropped and restored during playback; a CDN error; a decoder that fails to start. Each one ends in a retry on ExoPlayer or a message, never on mpv.
  * The app killed in the background and opened again.
* **Left out, with the reason**: touch gestures, pinch, foldables and control locking (no touch screen); flip, screenshots, the WebP capture and picture-in-picture (on M17's "not on this path" list); the mini player and DLNA (not part of the TV layer); background audio (a TV app in the background is stopped).

### Left for Other Tasks

* **For `M17.2`**:
  * What mode `initSurfaceAndroidView` ends up in for a view tree that holds a `SurfaceView`. kkren and AvalonUltra call it; yifgu and this fork's variant call `initExpensiveAndroidView`.
  * Whether Media3 really refuses cleartext to loopback under this app's target SDK, from Media3's source, so item 1 above rests on more than kkren's fix.
  * The Dolby Vision rule by profile (point 2 above).
  * Who holds audio focus: Dart alone (kkren, AvalonUltra, loneshu7), or ExoPlayer with Dart's session released (yifgu).
  * loneshu7's finding about the byte budget, checked against Media3 1.11.1's `DefaultLoadControl`.
* **For `M17.4`**:
  * This fork's proxy cancels a track's earlier request whenever a new `GET` arrives (`lib/services/thread_ripper/range_proxy.dart` 563–572), and kkren turned that off for Media3. With two progressive sources Media3 should hold one request for each track, so it may not matter here. Watch the proxy for cancelled requests during open and seek.
  * The route animation: kkren hides the surface before a page pops and paints a strip over a seam. See what a `SurfaceView` does on this TV when the video page pops and when it goes between split view and fullscreen.
* **For `M17.5`**:
  * The `codecs` string of every 杜比视界 stream met, and which decoder Media3 picked for it.
  * Whether 杜比全景声 and Hi-Res play on this TV at all. On a phone without the decoder, the audio error ended playback (PR 2145).
  * The three window cases of point 3, and whether the TV sends a `colorMode` configuration change when the panel enters HDR. Without `colorMode` in `configChanges`, that change restarts the activity.

## M17.2: Media3 Outside PiliPlus

**Status**: ✅ Done (2026-11-12). Each decision below has its source. What only a TV can answer is listed at the end for `M17.4` and `M17.5`.

### What Was Read

| Project | At | License | Read for |
| :--- | :--- | :--- | :--- |
| `androidx/media` (Media3) | tag `1.11.1` (`8c6678b65`), and the release notes up to `1.12.0-beta01` | Apache-2.0 | Decoder choice, surface loss, audio, buffering, HTTP loading |
| Flutter's engine and framework | 3.47.9, the sources in the local SDK (`c197ca5199e`) | BSD-3-Clause | Platform view modes; the transparent surface |
| `flutter/packages`, `video_player_android` | `11da3bab8` (2026-11-12) | BSD-3-Clause | ExoPlayer on a `SurfaceView` platform view |
| `moneytoo/Player` (Just Player) | `6df39ae74` (2026-11-12) | Unlicense | The settings of the one Media3 app that played 4K60 on `<physical-tv>` |
| `aaa1115910/bv` | `0e454c06e` (2025-12-08), and three of its issues | MIT | A Bilibili TV client on Media3 |
| `jellyfin/jellyfin-androidtv` | `e14b0884e` (2026-11-12) | GPL-2.0 | Ideas only. Nothing is copied from it |
| `yuliskov/SmartTube` | `ab04c75fa` (2026-11-12) | MIT | Its list of TV workarounds |
| `Hunter-Clipper/OpenIPTV` | `73ee38a` (2026-11-12) | GPL-3.0 | Found by a code search: a Flutter app that ships the transparent view on TVs |
| Android's SDK sources | API 37 (`Window`, `SurfaceView`, `Display`) | Apache-2.0 | The HDR window calls; changing a surface's Z order |
| Android's platform documents | "Mixed SDR/HDR composition" and "HDR video playback" on source.android.com | | SDR over HDR |

Media3 paths below are under `libraries/exoplayer/src/main/java/androidx/media3/exoplayer/` unless they say otherwise. Flutter engine paths are under `engine/src/flutter/shell/platform/android/`.

### Decisions

**1. Media3 version: pin 1.11.1.**

* It's the latest stable release (2026-09-11), the one Just Player had when it played 4K60 on `<physical-tv>`, and the one yifgu and OpenIPTV use.
* 1.12.0 is at beta01 (2026-11-11). Its notes have three changes that touch Dolby Vision, and M17's own checks cover the gaps until it's stable:
  * A profile Media3 doesn't know (it knows 4, 5, 7, 8, 9 and 10) is rejected in 1.12, where 1.11.1 plays it "as standard HEVC with incorrect colors". The track check in decision 2 catches it.
  * 1.12 stops picking a Dolby Vision decoder that doesn't support the stream's profile when no decoder fully supports the format. `M17.5` records the decoder's declared profiles.
  * 1.12 lets Profile 7 fall back to HEVC. Bilibili isn't known to serve it.
* From 1.10 to 1.11.1 the notes have nothing about MediaTek. What matters here: 1.11.0 fixed frame drops when a new surface is set on a device with no placeholder surface, which is the path decision 3 chooses; 1.11.0 removed the E-AC-3 JOC fallback on Pixel phones, the failure PR 2145 met; 1.10.1 fixed artifacts with AV1-based Dolby Vision.
* `M17.6` looks again if 1.12.0 is stable by then.

**2. Renderers: Media3's default codec selector, decoder fallback off, and a Dolby Vision rule by profile.**

* **What Media3 does by itself** (1.11.1):
  * `mediacodec/MediaCodecUtil.java` 379–414: a `video/dolby-vision` track has an "alternative" decoder type by profile. HEVC for profiles 4 and 8, AVC for 9, AV1 for 10, and **none for 5 and 7**. So Media3 never offers an HEVC decoder for Profile 5.
  * `video/MediaCodecVideoRenderer.java` 901–923: a display that doesn't report Dolby Vision gets the alternative decoders alone, when there are any. Otherwise the list is the Dolby Vision decoders, then the alternatives.
  * `mediacodec/MediaCodecRenderer.java` 1305–1309: with decoder fallback off, the default, only the first decoder in the list is tried.
  * `libraries/extractor/src/main/java/androidx/media3/extractor/mp4/BoxParser.java` 1669–1672 and 1842–1845: a track is typed Dolby Vision when its sample entry has a `dvcC`, `dvvC` or `dvwC` box. Without one, the stream is plain HEVC to Media3.
* **So the exact cases where a Dolby Vision stream reaches an HEVC or AVC decoder** are these: Profile 8 or 4 (HEVC) and 9 (AVC) on a display without Dolby Vision; the same profiles when the Dolby Vision decoder is listed second or, with fallback on, fails to start; and any stream whose container doesn't mark it, or marks a profile 1.11.1 doesn't know. Profile 5 only through the last one.
* **The rule**:
  * Before opening quality 126: the display reports Dolby Vision and a `video/dolby-vision` decoder exists, or the quality is refused with a message. This is yifgu's first two checks.
  * After tracks are selected: the video track is typed `video/dolby-vision` and its profile is the one the API's `codecs` string promised. If not, stop with a message. This is yifgu's fourth check, and it covers what 1.11.1 lacks.
  * **Profile 5**: nothing more is needed, because Media3 has no other decoder to give it.
  * **Profile 8.4**: on a TV with a Dolby Vision display and decoder it plays through that decoder. Where either is missing, an HEVC decoder shows its HLG base layer, which is a correct picture. The proposal is to allow that and label it HLG in 播放信息, not 杜比视界. `M17.6` confirms.
  * **No custom `MediaCodecSelector`.** yifgu's third check isn't needed, and it's the one piece `M17.1` tied to a black picture.
* **Decoder fallback stays off.** jellyfin turns it on, to play any file a server holds; Just Player and `bv` leave it off. Off is also the fail-closed choice: a decoder that won't start is an error, not a quiet switch to another one.
* **A way to ask before opening**, from jellyfin's idea (`playback/media3/exoplayer/src/main/kotlin/support/ExoPlayerPlaySupportReport.kt`): build a `Format` from the API's codec string, size and frame rate, and ask the player's own video renderer whether it supports it. The answer says handled or not, hardware or not, and whether it would use a decoder for a fallback type. `M17.9` can gate the quality list on Media3's own answer instead of a second copy of its rules.
* `bv` has no rule at all, and its issue 18 shows the result: on a box with no Dolby Vision decoder, every 杜比视界 video was a green screen, with the TV in HDR mode.

**3. The surface: a plain `SurfaceView`, and the decoder is released when the surface is lost.**

* `ExoPlayerImpl.java` 3571–3576 clears the video output when the surface is destroyed (Home, sleep). `video/MediaCodecVideoRenderer.java` 1318–1343 and 2481–2522 then keep the decoder running on a "placeholder surface", an EGL surface, on every device below API 35. `<physical-tv>` is API 34. That moves a live decoder from the video plane to a GPU surface, which M17's rules don't allow.
* **Decision**: a video renderer whose `shouldUsePlaceholderSurface` returns false. The decoder is then released with the surface and made again when one returns. M16 does the same for mpv: `TvVideoPlane` sets `vid=no` when the surface is lost. The cost is a decoder start on coming back from Home.
* **The view binds and unbinds its own surface**, as Flutter's `video_player_android` does (`android/src/main/java/io/flutter/plugins/videoplayer/platformview/PlatformVideoView.java`): `setVideoSurface` in `surfaceCreated`, and `clearVideoSurface(surface)` in `surfaceDestroyed`, which only unbinds if that surface is still the player's. Two views exist for a moment when a route changes, and this keeps the old one from taking the picture with it.
* **Not chosen for the spike**: Media3's `demos/surface` (`MainActivity.java` 230–235, 267–280), which gives the decoder one `SurfaceControl` for good and reparents it under whichever `SurfaceView` is showing. It avoids the decoder restart. Nothing has shown how this TV composes such a layer, so it's an option for later, and it would need its own video-plane check.

**4. Audio: media attributes on the player, audio focus left with Dart, and the TV decides between passthrough and decoding.**

* `audio/MediaCodecAudioRenderer.java`, `supportsFormat`: when the audio sink takes the encoded format, it's passed through and no decoder is used. Otherwise a decoder is needed, and for 杜比全景声 (E-AC-3 JOC) an E-AC-3 decoder counts, in 2-D (`mediacodec/MediaCodecUtil.java` 380–385).
* `audio/AudioCapabilities.java` 188–190: on a TV at API 33 or later, what the sink takes comes from `AudioManager.getDirectProfilesForAttributes`. It depends on where the sound is going (the TV's speakers, ARC, a soundbar) and on the attributes the player was given. The app doesn't choose, and passthrough wins when both exist.
* A track with neither route isn't an error. Its format is unsupported, so it isn't selected, and the video plays silent. The adapter has to see an audio track that wasn't selected and say so, or 杜比全景声 on the wrong output looks like a muted video.
* `ExoPlayer.java` 811: the player handles audio focus only when asked. The app already holds focus in Dart for any player (`lib/services/audio_session.dart`). **Decision**: `USAGE_MEDIA` and `CONTENT_TYPE_MOVIE` with focus handling off, so the capability query uses the right attributes and one owner holds focus. yifgu's way, ExoPlayer holding focus with Dart's session released, is right for a player with no Flutter UI and isn't needed here. Just Player and jellyfin let ExoPlayer hold focus because they have no other owner.
* Hi-Res is FLAC, which Android decodes in software. Whether more than 16 bits reach the output isn't decided here.

**5. Buffer: the app's own two settings, mapped as loneshu7 mapped them.**

* Media3's defaults (`DefaultLoadControl.java` 64–130): 50 s minimum and maximum, 1 s to start, 2 s after a rebuffer, no back buffer, and a byte target worked out from the tracks, about 138 MiB for video with audio. That memory is on the Java heap of a 32-bit app, so the default can't stay. 1.11.0's notes mention the same risk.
* The app's settings for mpv (`lib/utils/storage_pref.dart` 891–901): `cache-secs` of 16 s times the speed, and 4 MiB forward plus 4 MiB back, whichever limit comes first.
* **Decision**: minimum and maximum both at the app's seconds times the speed at open; start thresholds left at 1 s and 2 s; the byte target at the app's forward size; bytes before time; no back buffer. `DefaultLoadControl.java` 775–809 confirms loneshu7's reasons: the byte count covers everything allocated, and with bytes first a full budget also lets playback start. At 4 MiB a 4K stream holds about a second in the player, as it does in mpv today; the ripper's proxy holds the rest.

**6. No platform-view mode is cheaper than Hybrid Composition for a `SurfaceView` while Impeller is off.**

* `io/flutter/plugin/platform/PlatformViewsController.java` 68 and 229–241: a view tree with a `SurfaceView` can't use the texture mode. `initSurfaceAndroidView` falls back to Hybrid Composition, so kkren, AvalonUltra and `video_player_android` are on the same mode as `initExpensiveAndroidView`. `initAndroidView` would fall back to a virtual display, which is a texture again.
* `platform_view_android.cc` 557–563: the newer mode (`initHybridAndroidView`, "Hybrid Composition++") only exists on Impeller with Vulkan, on API 34 and later. This app's manifest turns Impeller off (`android/app/src/main/AndroidManifest.xml` 51–53), which is upstream's choice.
* So the two routes in the plan are the only two: Hybrid Composition, or no platform view at all. Turning Impeller on for the whole app to get the newer mode isn't proposed.
* `video_player_android`'s README advises against its own platform view on Android, for an open Flutter issue (164899): the video shows over the UI when the player is scrolled out of view. On the TV the player doesn't scroll in fullscreen; in split view it's one more thing for `M17.4` to look at.

**7. The transparent view can be built in Flutter's embedding, and one app already ships it on TVs.**

* `io/flutter/embedding/android/FlutterActivity.java` 1248–1263: the render mode and the transparency mode are two methods an activity can override. By default a transparent background also means a `TextureView`; an override can ask for a surface that is transparent. `MainActivity` extends `AudioServiceActivity`, which overrides neither.
* `io/flutter/embedding/android/FlutterSurfaceView.java` 116–119: a transparent one sets a transparent pixel format and `setZOrderOnTop(true)`. The video `SurfaceView` goes under Flutter's view in the same window, with the default Z order, so the stack is video, then the window, then Flutter. No translucent window theme is needed.
* **Switching while the app runs**: Flutter decides when it makes the view. Android itself allows a Z order change after the surface exists for apps that target above API 29 (`SurfaceView.java` 1003–1008 in the SDK sources), and this app targets 37, so a switch without a restart may be possible through `onFlutterSurfaceViewCreated`. OpenIPTV doesn't try: its setting applies after a restart. Only the TV can say.
* **The hole**: a region shows the video only where Flutter's final frame has no color. `BlendMode.clear` in a painter makes that hole, but only in the layer it paints into: under an ancestor that draws through an offscreen layer (`Opacity`, a `ShaderMask`, a clip with `saveLayer`) or a cached picture, the clear stays in that layer and the page's background shows again. The sure way is that nothing opaque is painted under the video on that route, with the clear as the tool for what must be painted around it.
* **`Hunter-Clipper/OpenIPTV` ships this on Android TV**, with Media3 1.11.1, and its activity has the same base class as this app's:
  * `android/app/src/main/kotlin/com/openiptv/app/MainActivity.kt` 50–62: `getRenderMode` returns `surface`, and `getTransparencyMode` returns `transparent` on TVs only.
  * `.../VideoLayer.kt` (132 lines): one `SurfaceView` added under Flutter's view, 1 pixel in size until Dart sends a rectangle, with a 500 ms delay before it's let go, so a route change doesn't restart the stream.
  * `lib/shared/widgets/video_surface.dart` 256–270 and 372–391: the rectangle from `localToGlobal` times the pixel ratio, and a painter that fills black and clears the hole.
  * Its own comments give the reason, which is M18's: on the texture, frames and screen refreshes drift apart. It isn't known on which TVs it was tried, and nothing here ran it.
* For M17 and for `M18.3` this turns the transparent view from an idea into something with a working example to adapt, under the same license.

**8. SDR graphics over HDR video: no window calls to start with, because the window's color mode doesn't reach a `SurfaceView`.**

* `Window.java` 1401–1407 in the SDK sources, on `setColorMode`: it "does not impact SurfaceViews or SurfaceControls, as those have their own independent color mode and HDR parameters", and the request "is not guaranteed to be honored". `setDesiredHdrHeadroom` only applies when the color mode is HDR, takes 1.0 to 10,000.0, and has the same note. `SurfaceView` has a headroom call of its own that works independently of the window's.
* So `COLOR_MODE_HDR` on the window is about the window's own content, which here is Flutter's SDR surface. It can't be what puts the video in HDR. That comes from the decoder's output on the `SurfaceView`.
* Just Player, `bv` and OpenIPTV make no HDR call on the window at all. `bv`'s issue 18 has a TV entering HDR mode from `bv` (with the wrong decoder, hence the green).
* **What the platform does with SDR layers** (Android's "Mixed SDR/HDR composition" document): since Android 13, when HDR content is on screen the SDR layers are dimmed by a per-layer ratio the display service sends to the hardware composer. It needs support from the device's composer, the document speaks only of built-in displays, and it calls validation device dependent. It says nothing about TVs or Dolby Vision. `Display.getHdrSdrRatio()` (API 34) reports the ratio, and returns 1.0 when `isHdrSdrRatioAvailable()` is false.
* **Decision**: the spike starts with no window calls. `M17.5` reads `isHdrSdrRatioAvailable()` and the ratio while HDR plays: if the TV reports no ratio, Android isn't dimming the UI and what's seen is the panel's own mapping. The color mode and the headroom calls are tried only if the UI looks wrong without them. This keeps the plan's order and gives it a reason.
* No project read does anything for its controls or danmaku over HDR. `bv` draws its danmaku over the same `PlayerView` with no special case.

**9. Loading: Media3 treats the ripper's proxy as mpv does.**

* `source/ProgressiveMediaPeriod.java` (the `load` loop), `source/ProgressiveMediaSource.java` 321, and `libraries/datasource/src/main/java/androidx/media3/datasource/HttpUtil.java` 57–69: one open-ended request for each track, with no `Range` header from byte 0 and `bytes=N-` after a seek outside the buffer. A seek inside the buffer makes no request. When the buffer is full, the loader stops reading and keeps the connection open, checking again every 1 MiB.
* That's what the proxy expects from mpv: one connection for a track, a new one for a seek, and a reader that stalls when it's full. A resume from the middle makes two requests for each track (the head, then the offset), as mpv's does.
* Media3 sends one header mpv doesn't, `Icy-MetaData: 1`, and may send `If-Range` when a response has an `ETag`. The proxy sends no `ETag`.
* **The ripper's "caught up" signal**: the adapter answers `demuxer-cache-idle` from `Player.isLoading`.
* `libraries/datasource/.../HttpDataSource.java` 232–238 and 378–389: Media3 turns the platform's refusal of plain HTTP into `CleartextNotPermittedException`. So `M17.1`'s first piece stands: the manifest has to allow `127.0.0.1`.

**10. Frame rate: Media3's request to the display is turned off for the spike.**

* `ExoPlayer.java` 513 and `video/VideoFrameReleaseHelper.java` 114: by default Media3 calls `Surface.setFrameRate` with the video's rate, in the "only if seamless" mode. mpv on the variant asks for nothing.
* **Decision**: `VIDEO_CHANGE_FRAME_RATE_STRATEGY_OFF` in `M17.4`, so its numbers compare with M16's. Whether 24 and 25 fps video should ask the panel to follow is a question for `M17.6`. Just Player keeps its own frame-rate matching behind a setting that is off.

**11. Tunneled playback stays off**, as the plan's rule says. Just Player has it behind a setting that is off by default (`Prefs.java` 74). OpenIPTV offers it for live streams and carries several recoveries for when it fails ("no picture", "clock stuck"), which shows how it behaves across TVs.

### The Five Questions From `M17.1`

1. **The mode `initSurfaceAndroidView` ends up in**: Hybrid Composition (decision 6).
2. **Cleartext**: confirmed from Media3's source (decision 9).
3. **The Dolby Vision rule by profile**: decision 2.
4. **Audio focus**: Dart keeps it (decision 4).
5. **loneshu7's byte budget**: confirmed in 1.11.1 (decision 5).

### What Else the Projects Showed

* **`bv` issue 145**: on a TCL TV with Android 11 and a 1080p UI, `bv` played 4K and HDR scaled down to 1080p and the TV didn't see HDR, while other players on the same TV played 4K HDR at the panel's resolution. Its author's TV, with a 4K UI, was fine. So a `SurfaceView` in a 1080p UI doesn't promise the panel's resolution on every TV. M16 already saw 4K on the plane on `<physical-tv>`; `M17.4` checks the layer's buffer size again under Media3.
* **SmartTube's levers for dropped frames on a `SurfaceView`** (`common/src/main/java/com/liskovsoft/smartyoutubetv2/common/exoplayer/versions/renderer/TweaksMediaCodecVideoRenderer.java` 44–52, 83–106; the switches are in `common/.../prefs/PlayerTweaksData.java` 130–272). They are user switches, not per-model rules, and two are worth knowing before 4K60 is measured:
  * Release each output buffer with no timestamp, for frame drops on a `SurfaceView` (ExoPlayer issue 6348).
  * Count a buffer as late only after a second, "for Sony Bravia". Those TVs have MediaTek chips, as `<physical-tv>` does.
  * The rest: a larger maximum decoder size for Amlogic, no snapping to vsync, skipping the profile and level check, a software decoder, a `TextureView`, an audio delay. Tunneling is a switch there too, off by default.
* **Just Player's whole setup** is Media3's defaults: default renderers and selector, no decoder fallback, default load control, `PlayerView`'s `SurfaceView`, and audio attributes (`app/src/main/java/com/brouken/player/PlayerActivity.java` 1227–1229, 1250–1254). Its `master` is now on 1.12.0-beta01.
* **`bv`'s player** (`player/core/src/main/kotlin/dev/aaa1115910/bv/player/impl/exo/ExoMediaPlayer.kt` 31–35, 72–88): two `ProgressiveMediaSource`s merged, with `User-Agent` and `referer`, the same shape as the forks. It takes the codecs for a quality from the API and doesn't check the device.

### Pieces to Adapt, Added to `M17.1`'s List

| # | Piece | Source | For |
| :--- | :--- | :--- | :--- |
| 19 | A see-through Flutter surface on TVs only | OpenIPTV `android/app/src/main/kotlin/com/openiptv/app/MainActivity.kt` 50–62 | `M17.4`, `M18.3` |
| 20 | A `SurfaceView` under Flutter's view, sized from Dart | OpenIPTV `.../VideoLayer.kt` (whole file) | `M17.4`, `M18.3` |
| 21 | The rectangle sent to the layer, and the hole painter | OpenIPTV `lib/shared/widgets/video_surface.dart` 256–270, 372–391 | `M17.4`, `M18.3` |
| 22 | A view that binds and unbinds only its own surface | `video_player_android` `.../platformview/PlatformVideoView.java` (the surface callback) | `M17.7` |
| 23 | Two overrides for dropped frames, if `M17.4` finds any | SmartTube `TweaksMediaCodecVideoRenderer.java` 44–52, 83–106 | `M17.4` |

Credit lines for these: `Adapted from Hunter-Clipper/OpenIPTV (GPL-3.0), commit 73ee38a.`; `Adapted from flutter/packages video_player_android (BSD-3-Clause), commit 11da3bab8.`; `Adapted from yuliskov/SmartTube (MIT), commit ab04c75fa.` Nothing comes from jellyfin's code: its license is GPL-2.0, and only the idea in decision 2 is used.

### For the TV

* **`M17.4`**:
  * With decision 3's renderer, Home and back and sleep and back: the decoder is released and comes back on the video plane, and how long the return takes.
  * The video layer's buffer size at 4K (`bv` issue 145), with the layer still `DEVICE`.
  * The transparent view as OpenIPTV builds it, beside the platform view. Whether the Z order can change while the app runs.
  * The proxy's log during open and seek: one request for a track at a time, and no trouble from the `Icy-MetaData` header.
  * The buffer mapping at 4 MiB with a 4K stream: stalls, and how the ripper's automatic concurrency reads `isLoading`.
  * If frames drop at 4K60: SmartTube's two overrides, one at a time.
* **`M17.5`**:
  * The TV's `video/dolby-vision` decoders and the profiles each declares, and which one Media3 picks for each `codecs` string met.
  * `isHdrSdrRatioAvailable()` and the ratio while HDR and Dolby Vision play, before any window call is tried.
  * What `getDirectProfilesForAttributes` reports on the TV's speakers and on any ARC device the user has, and whether 杜比全景声 is passed through, decoded, or left silent.

## M17.3: This App's Player Seam and the Containment Design

**Status**: ✅ Done (2026-11-13). The skeleton analyzes clean, and the inventory has no "unknown". Nothing was run on a device.

Line numbers are on `main` at `0d63f200e`. `Ctl` is `lib/plugin/pl_player/controller.dart`, and `View` is `lib/plugin/pl_player/view/view.dart`. The media_kit sources are the fork this app pins, `My-Responsitories/media-kit` at `73771ec38`.

### What the Interface Is

* `Player` is a `typedef` for `NativePlayer` (`media_kit/lib/src/player/player.dart` 3).
* `NativePlayer` isn't a plain class, as the plan had it. It **extends `PlatformPlayer`** (`.../native/player/real.dart` 48), an abstract class with a public constructor that already holds `state`, `stream` and one `@protected` controller for each stream (`.../player/platform_player.dart` 32–255). `PlatformPlayer` is exported.
* So the adapter is `class TvExoPlayer extends PlatformPlayer implements NativePlayer`. It inherits the state, the streams and their controllers, and `PlayerState`'s fields are plain mutable fields, so it can fill them from Media3's events.
* `VideoController` is a `typedef` for `PlatformVideoController` (`media_kit_video/lib/src/video_controller/video_controller.dart` 3), an abstract class with a public constructor and one abstract method, `setSize`. **The adapter can have a `VideoController` of its own.** That matters more than it looks: upstream's `SubtitleView` only reads `controller.player.state.subtitle` and `controller.player.stream.subtitle` (`media_kit_video/lib/src/subtitle/subtitle_view.dart` 43, 57), so with a `TvExoVideoController` in `PlPlayerController`'s field, subtitles keep upstream's own view, style and drag, and `videoController!` is never null.

### The Skeleton

A compile-only `lib/tv/tv_exo_player.dart` of 232 lines, with the hooks below applied to a working copy, passed `flutter analyze` on the three files with no issues. It isn't committed, and the hooks were reverted. What the analyzer demanded:

* **22 inherited methods overridden**, because `NativePlayer` adds a named `synchronized` parameter to each (`open`, `play`, `pause`, `seek`, `setRate`, `setVolume`, `setSubtitleTrack`, `stop`, `screenshot` and the playlist and track methods).
* **22 more members**: `getProperty`, `setProperty`, `setOption`, `command`, `setMediaHeader`, `replaceSingle`, `getAudioDevices`, `throwIfDisposed`, `current`, `disposed`, `onLoadHooks`, `onUnloadHooks`, three state flags (each a getter and a setter), `lock`, and `ctx`.
* **Two of them carry mpv's own types.** `ctx` is a `Pointer<mpv_handle>`, so the file imports `dart:ffi` and media_kit's generated bindings and holds `nullptr`. `lock` is a `Lock` from `synchronized`, which is already this app's dependency.
* `completer` has to be completed in the constructor, or `waitForPlayerInitialization` never returns.
* **No `noSuchMethod`**, as the plan asked. A member that upstream's media_kit adds to `NativePlayer` fails analysis in the TV checks.
* **What analysis can't show**: Dart lets a class implement another library's class without its private members. If media_kit's own code were handed the adapter and called one, it would throw at run time. The only place that hands a player to media_kit is `VideoController.create`, and the hook keeps the adapter away from it. Nothing in `lib/` reads `ctx` from a player.

### The Inventory

Everything `lib/` asks of the player that `PlPlayerController` owns. "Implement" means over the method channel in `M17.8`.

**Methods**

| Member | Called from | With ExoPlayer |
| :--- | :--- | :--- |
| `Player.create(configuration)` | `Ctl` 866 | Hook 2 below |
| `open(Media, play: false)` | `Ctl` 1003; again from `refreshPlayer`, `Ctl` 1021 | Implement. The `Media` holds one string: `edl://!no_chapters;%<length>%<video>;!new_stream;!no_chapters;%<length>%<audio>` (`Ctl` 990–998), or a single URL for 听视频 and for a video with no audio. The lengths make the split exact. `start` is the resume position. Of `extras`, the buffer values are already read at creation (the load control belongs to the player), and `video-rotate` and the normalization filter are ignored |
| `current` | `Ctl` 1017–1018 (重载视频 takes `current.last`) | Implement: keep the last `Media` |
| `play`, `pause` | `Ctl` 1298, 1307, 1448 | Implement |
| `seek` | `Ctl` 1260, 1447; `lib/pages/video/introduction/local/controller.dart` 128 | Implement |
| `setRate` | `Ctl` 1273 | Implement, and keep `state.rate` right (`Ctl` 1032 and 1271 compare with it) |
| `setVolume` | `lib/models/common/audio_normalization.dart` 112, 119, through `setVolumeCapped` | Implement. The value is 0–100 on mpv's cubic curve, so ExoPlayer's linear volume is `(v / 100)³` |
| `setMediaHeader` | `Ctl` 895 | Implement: kept for the HTTP factory |
| `setSubtitleTrack` | `lib/pages/video/controller.dart` 1115 (`no`), 1151 (a URL, or `memory://` and the VTT text) | Implement in Dart: parse the VTT into cues and feed `state.subtitle` and the `subtitle` stream by position. A URL is fetched first |
| `screenshot` | `Ctl` 1843; `lib/pages/video/reply_new/view.dart` 343 | Returns null, which both callers accept. Hidden in the HUD |
| `command` | `Ctl` 831–850 (`setShader`, also run at open for 番剧 when 超分辨率 is on) | No-op. 超分辨率 hidden |
| `dispose` | `Ctl` 767, 922, 1772 | Implement |

**mpv properties**

| Property | Where | With ExoPlayer |
| :--- | :--- | :--- |
| `getProperty('demuxer-cache-idle')` | `Ctl` 1136, the thread ripper's "caught up" signal | `'yes'` when `Player.isLoading` is false (`M17.2`, decision 9) |
| `getProperty('hwdec-current')` | `lib/pages/video/widgets/header_control.dart` 777 (播放信息) | The decoder's name |
| `getProperty('volume')` | the same, 778 | The volume, as mpv would print it |
| `setProperty('force-window', 'no')` | `Ctl` 892 | Ignored |
| `setProperty('file-local-options/vid', …)` | `header_control.dart` 588 (听视频 switched during a video) | Map: turn the video track off or on |
| `setProperty('af', …)` | `audio_normalization.dart` 109, 117 (volume above 100 %) | Ignored. The dialog is capped at 100 % in the HUD |
| `setProperty('video-rotate', …)` | `lib/pages/video/controller.dart` 163 | Ignored. Hidden |

**State and streams**

| Member | Read from | With ExoPlayer |
| :--- | :--- | :--- |
| `state.playing`, `position`, `duration`, `completed`, `rate`, `buffer` | `Ctl` (20 places), `View` 342 and 961, `lib/tv/tv_player_hud.dart` 575, `play_pause_btn.dart` 31, `post_panel/view.dart` 527 | Implement. `playing` is "play was asked for", as in mpv, with `buffering` beside it; after an error it goes false |
| `state.width`, `height` | `Ctl` 308, 362; 播放信息 | Implement, from the video size |
| `state.playlist` | `Ctl` 1180, 1236 (error reports); 播放信息 | Implement: one entry, the current `Media` |
| `state.videoParams`, `audioParams`, `track`, `tracks` | 播放信息; `header_control.dart` 585 (`tracks.video.length`) | Map from Media3's formats: codec, size, frame rate, color transfer; sample rate and channels |
| `state.subtitle`, `stream.subtitle` | upstream's `SubtitleView` | Implement, from the cues above |
| `stream.playing`, `completed`, `position`, `duration`, `buffer`, `buffering` | `Ctl` 1086–1161; `play_pause_btn.dart` 34; `post_panel/view.dart`; `lib/pages/sponsor_block/block_mixin.dart` 84, 86 | Implement. Position at most four times a second, and nothing else on a timer (`M17.1`, "what not to copy" 9) |
| `stream.error` | `Ctl` 1187–1240 | Implement, with chosen text (below) |
| `stream.log` | `Ctl` 1177 (debug builds) | Empty |
| `stream.size` | `lib/pages/live_room/controller.dart` 198 | Live only, so mpv's |

**The video controller**

| Member | Where | With ExoPlayer |
| :--- | :--- | :--- |
| `VideoController.create(player, …)` | `Ctl` 881 | Hook 3 |
| `videoController!` for `SubtitleView` | `View` 267, 1352 | Works unchanged with `TvExoVideoController` |
| `SimpleVideo(controller: videoController!)` | `View` 2035–2036 | Hook 4 |
| `videoController == null` | `lib/pages/video/view.dart` 1219 | Non-null, so the page builds its player |
| `videoController?.id.value` | `Ctl` 364 (iOS picture-in-picture) | Null |

**Errors.** Upstream's handler matches mpv's text. The adapter chooses what it says, so no hook is needed:

* A source or network error that Media3 calls recoverable is reported as `Failed to open http://127.0.0.1:…` or `Failed to open https://…`. Upstream then waits 3 s and, if nothing is buffered, shows `视频链接打开失败，重试中` and calls `refreshPlayer`, which opens the same media on the same player. The retry stays on ExoPlayer.
* A decoder error is never reported as `Could not open codec`, because upstream's toast for that promises a switch to software decoding. The adapter stops, shows its own message, and reports text that matches no pattern.

**Not this player.** `lib/pages/audio/controller.dart` (the audio page), `lib/common/widgets/image_viewer/gallery_viewer.dart` (live photos) and `lib/plugin/pl_player/widgets/mpv_convert_webp.dart` each make an mpv player of their own. `lib/main.dart` 187 reads a static. None of them is touched.

### How the Controller Is Shared, and the Rule

* **One controller, one player.** `PlPlayerController.getInstance` returns one instance and counts the pages that use it (`Ctl` 691–696). The player is made on the first data source and reused by every later one (`Ctl` 916–919), until the count reaches zero (`Ctl` 1720–1777). A related video, a quality switch, the next part and 重载视频 all reuse it.
* **So a player's kind is fixed when it's made**, by the page that made it. A live room opened over a video page, and a video opened over a live room, get the player that's already there.
* **The rule**:
  1. No player yet: ExoPlayer when the setting is on and the source isn't live; mpv otherwise. Local files count as videos.
  2. An mpv player already there, asked for a video (it was made by a live room, or before the setting was turned on): it plays what `main` lets mpv play today, up to 1080P60 in SDR, and refuses anything above with a message. This is M16's rule on the variant.
  3. An ExoPlayer already there, asked for a live room: refused with a message.
* **Why refuse, and not swap the player.** A swap looks possible, because a video page removes its player widget when another page covers it (`lib/pages/video/view.dart` 387, 1215–1221), so it would build a new one on return. Two things make it unsafe to promise from reading:
  * `_initPlayer` asserts that both fields are null (`Ctl` 856, 879), so a swap leaves `videoController` null across several awaits, and `View` 2036 dereferences it with `!` on any rebuild.
  * The live room page keeps its player widget while it's covered (`lib/pages/live_room/view.dart` 282 gates on a field that isn't observable), so that rebuild can happen.
* **For the gate**: rule 3 means a live room reached from a video page doesn't play while the setting is on, until the user goes back. If that route matters, the swap is a task of its own in the build, with a device check, and `M17.6` decides.

### The Hooks

Measured on a working copy that analyzed clean, then reverted.

| # | File | Hook | Lines |
| :--- | :--- | :--- | :--- |
| 1 | `Ctl` | The import | +1 |
| 2 | `Ctl` 866 | `await TvExoPlayer.createIfWanted(isLive) ?? await Player.create(…)` | +2 −1 |
| 3 | `Ctl` 881 | `TvExoPlayer.videoControllerOf(player) ?? await VideoController.create(…)` | +2 −1 |
| 4 | `Ctl` 916 | `if (TvExoPlayer.refuses(player, isLive, width, height))`: an error state and a return | +4 |
| 5 | `View` | The import, and before `Transform.flip` at 2029: `if (TvExoPlayer.viewOf(…) case final view?) return view;` | +9 |
| 6 | `lib/pages/setting/models/video_settings.dart` | Two imports and the setting's row, as M16 has | +3 |
| 7 | `TvBridge.kt` | Registering the Kotlin player | +1 |
| 8 | `AndroidManifest.xml`, and a new `res/xml/network_security_config.xml` | Cleartext to `127.0.0.1` | +1, and 7 new |
| 9 | `android/app/build.gradle.kts` | Media3 1.11.1 | +3 |
| 10 | `MainActivity.kt` | Only on the transparent-view route: two overrides | about +6 |

* **In upstream's Dart files: 20 lines added and 2 changed**, counted without whitespace. Hooks 2 and 3 wrap an existing call, so the formatter also re-indents the 12 lines of arguments under them, and a sync would conflict if upstream edits those. The other shape is one inserted block that builds the ExoPlayer and returns before upstream's lines: about 8 lines added, none changed and none re-indented, but its four set-up calls repeat upstream's and wouldn't follow a change to them. `M17.9` picks; the block is the safer one for sync.
* M16's hooks on the variant, for comparison: 27 lines in `Ctl`, 3 in `View`, 3 in the settings file.
* **The two fallbacks**, from `M17.1`'s measurements against upstream:
  * A `PlaybackBackend` interface, as PR 2145: +529 −34 in `Ctl` when it was written and +635 −32 as AvalonUltra carries it now, in 20 files or more.
  * A separate native player with its own controls, as yifgu: +271 −19 in `Ctl` and 129 changed lines in the video page, and it gives up danmaku and the HUD.
* Nothing is needed in `header_control.dart`, in the video page's controller or in the error handler: the adapter answers what they ask.

### HUD Entries on ExoPlayer

A first table for `M17.10`. "Same" means the entry needs nothing from the player that the adapter doesn't give. Live-only entries (切换路线, 发弹幕, 屏蔽词, 醒目留言) never see ExoPlayer.

| Entry (`TvHudActionId`) | On ExoPlayer |
| :--- | :--- |
| 画质 (`quality`) | Same. The list is where HDR 真彩, 杜比视界 and HDR Vivid appear or are refused (`M17.9`) |
| 倍速 (`speed`) | Same |
| 画面比例 (`videoFit`) | Only the fits a `SurfaceView` can show. It can't be clipped, so the crop modes go, as on the variant |
| 字幕 (`subtitle`), 翻译 (`aiTranslate`) | Same, through upstream's `SubtitleView` |
| 选集, 分段信息, 片段信息, 播放顺序 | Same. They use position and seek |
| 弹幕开关, 弹幕设置, 高能进度条, 弹幕列表 | Same. Danmaku is Flutter's |
| 点赞, 投币, 收藏, 稍后再看 | Same |
| 音质 (`audioQuality`) | Same list. A track the TV can't play has to be reported, not left silent (`M17.2`, decision 4) |
| 解码格式 (`decodeFormat`) | Same: it picks which stream is asked for. Media3 picks the decoder |
| 超分辨率 (`superResolution`) | Hidden |
| 播放器音量 (`playerVolume`) | Capped at 100 % |
| 定时关闭 (`shutdownTimer`) | Same |
| 重载视频 (`reload`) | Same, through `current` |
| 播放信息 (`playerInfo`) | Upstream's dialog works with what the adapter fills. `M17.10` adds Media3's own facts: decoder, HDR type, dropped frames |
| 完整设置 (`fullSettings`) | Upstream's panel. Its 听视频 is mapped; its flip, rotate and screenshot entries do nothing on this path, so `M17.10` hides them or the panel |
| 编辑按钮 (`editButtons`) | Same |

### For `M17.4`

* The skeleton is the start of the spike's adapter. It has to be written again from the lists above, since it wasn't committed; that's under an hour.
* The first things to see on the device: `state` and the streams driving upstream's controller with no change to it; the `edl://` split; upstream's retry running on `refreshPlayer`; `SubtitleView` showing cues from the adapter.
* Rule 2 and rule 3 with a live room and a video stacked both ways, to see the refusals and that going back leaves a working player.
