# M17 Study: Media3 for the TV Player

**Status**: 🔄 In progress. `M17.1` is done (2026-11-12). `M17.2` and `M17.3` haven't started.

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
