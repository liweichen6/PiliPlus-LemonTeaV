package com.example.piliplus

import android.app.Activity
import android.content.Context
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.RendererCapabilities
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoRendererEventListener
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The TV's player (docs/tv/PLAN.md, M17.7): Media3 1.11.1 drawing into a
 * `SurfaceView` under Flutter's view, so the decoder writes to the video plane
 * (`hwRender:1, gdec:0`). It plays every video and every live room on TV
 * (M17.6, decision 5), driven over a method channel by `lib/tv/`.
 *
 * The settings are M17.2's (docs/tv/M17_MEDIA3_STUDY.md): Media3's default
 * codec selector; no decoder fallback; no placeholder surface, so the decoder
 * is released with the surface and never runs on an EGL surface; audio focus
 * and the wake lock left with Dart; no frame-rate request; no tunneling.
 *
 * The surface route (M17.6, decision 7) follows Hunter-Clipper/OpenIPTV
 * (GPL-3.0, commit 73ee38a): a `SurfaceView` behind Flutter's view, placed at
 * the rect Dart sends, with Flutter's surface made see-through while a player
 * view is on screen. The player outlives a lost surface.
 *
 * Events to Dart carry the generation of the open they belong to.
 */
@OptIn(UnstableApi::class)
class TvExoPlayer private constructor(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    private val context: Context = activity.applicationContext
    private val main = Handler(Looper.getMainLooper())

    private var player: ExoPlayer? = null
    private var loadControl: TvExoLoadControl? = null
    private val loudness = TvExoLoudnessProcessor()
    private val dynamic = TvExoDynamicNormalizer()

    private var gen = 0
    private var live = false
    private var openedAt = 0L
    private var videoDecoder: String? = null
    private var audioDecoder: String? = null
    private var dropped = 0
    private var lastPosition = longArrayOf(-1, -1, -1)
    private var rateAt = 0L
    private var rateFrames = -1

    /** Pixels a video may have; 0 for no limit. Read on the playback thread. */
    @Volatile
    private var maxPixels = 0

    // Every live surface, newest last. Two exist for a moment on a route change.
    private val surfaces = ArrayList<Surface>()
    private var bound: Surface? = null
    private var layer: SurfaceView? = null
    private val hideLayer = Runnable { layer?.visibility = View.GONE }

    private val ticker = object : Runnable {
        override fun run() {
            sendPosition()
            measureFrameRate()
            main.postDelayed(this, POSITION_MS)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "create" -> {
                    create()
                    result.success(null)
                }
                "open" -> {
                    open(call)
                    result.success(null)
                }
                "play" -> {
                    player?.play()
                    result.success(null)
                }
                "pause" -> {
                    player?.pause()
                    result.success(null)
                }
                "seek" -> {
                    player?.seekTo(call.argument<Number>("ms")!!.toLong())
                    result.success(null)
                }
                "setRate" -> {
                    player?.setPlaybackSpeed(call.argument<Number>("rate")!!.toFloat())
                    result.success(null)
                }
                "setVolume" -> {
                    player?.volume = call.argument<Number>("volume")!!.toFloat()
                    result.success(null)
                }
                "setNormalization" -> {
                    setNormalization(call)
                    result.success(null)
                }
                "setVideoEnabled" -> {
                    setVideoEnabled(call.arguments as Boolean)
                    result.success(null)
                }
                "stop" -> {
                    player?.stop()
                    player?.clearMediaItems()
                    result.success(null)
                }
                "dispose" -> {
                    release()
                    result.success(null)
                }
                "stats" -> result.success(stats())
                "heapLimit" -> result.success(Runtime.getRuntime().maxMemory())
                "decoders" -> result.success(decoders())
                "supports" -> result.success(supports(call.arguments as List<*>))
                "displayHdr" -> result.success(displayHdrTypes())
                "layerRect" -> {
                    layerRect(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                "setTransparent" -> result.success(setTransparent(call.arguments as Boolean))
                "testRequest" -> result.success(takeTestRequest())
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            Log.e(TAG, "${call.method} failed", e)
            result.error("exo", e.toString(), null)
        }
    }

    // ---- The player ----

    private fun create() {
        release()
        val renderers = object : DefaultRenderersFactory(context) {
            override fun buildVideoRenderers(
                context: Context,
                extensionRendererMode: Int,
                mediaCodecSelector: MediaCodecSelector,
                enableDecoderFallback: Boolean,
                eventHandler: Handler,
                eventListener: VideoRendererEventListener,
                allowedVideoJoiningTimeMs: Long,
                out: ArrayList<Renderer>,
            ) {
                out.add(
                    PlaneVideoRenderer(
                        MediaCodecVideoRenderer.Builder(context)
                            .setMediaCodecSelector(mediaCodecSelector)
                            .setAllowedJoiningTimeMs(allowedVideoJoiningTimeMs)
                            .setEnableDecoderFallback(enableDecoderFallback)
                            .setEventHandler(eventHandler)
                            .setEventListener(eventListener)
                            .setMaxDroppedFramesToNotify(MAX_DROPPED_TO_NOTIFY),
                    ) { maxPixels },
                )
            }

            override fun buildAudioSink(
                context: Context,
                enableFloatOutput: Boolean,
                enableAudioOutputPlaybackParameters: Boolean,
            ): AudioSink = DefaultAudioSink.Builder(context)
                .setEnableFloatOutput(enableFloatOutput)
                .setEnableAudioOutputPlaybackParameters(enableAudioOutputPlaybackParameters)
                .setAudioProcessors(arrayOf(loudness, dynamic))
                .build()
        }
            .setEnableDecoderFallback(false)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)

        val load = TvExoLoadControl()
        loadControl = load
        val p = ExoPlayer.Builder(context, renderers)
            .setLoadControl(load)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                /* handleAudioFocus= */ false,
            )
            .setVideoChangeFrameRateStrategy(C.VIDEO_CHANGE_FRAME_RATE_STRATEGY_OFF)
            .build()
        p.addListener(listener)
        p.addAnalyticsListener(analytics)
        player = p
        bound?.let { p.setVideoSurface(it) }
        main.post(ticker)
        Log.i(TAG, "created surface=${bound != null}")
    }

    /**
     * `video` and an optional `audio` for a video's two tracks, merged; a live
     * room's single URL as FLV (progressive) or HLS. The caps are Dart's
     * resolved buffer settings for this kind of media.
     */
    private fun open(call: MethodCall) {
        val p = player ?: throw IllegalStateException("no player")
        val video = call.argument<String>("video")!!
        val audio = call.argument<String>("audio")
        live = call.argument<Boolean>("live") ?: false
        val hls = call.argument<Boolean>("hls") ?: Uri.parse(video).path.orEmpty().endsWith(".m3u8")
        maxPixels = call.argument<Number>("maxPixels")?.toInt() ?: 0
        loadControl?.configure(
            call.argument<Number>("bufferBytes")!!.toLong(),
            call.argument<Number>("bufferMs")!!.toLong(),
        )

        val headers = HashMap(call.argument<Map<String, String>>("headers") ?: emptyMap())
        val http = DefaultHttpDataSource.Factory().setAllowCrossProtocolRedirects(true)
        headers.remove("User-Agent")?.let { http.setUserAgent(it) }
        http.setDefaultRequestProperties(headers)
        val isLive = live
        val upstream = DataSource.Factory { RangeZeroDataSource(http.createDataSource(), isLive) }
        val data = DefaultDataSource.Factory(context, upstream)

        val source: MediaSource = if (hls) {
            HlsMediaSource.Factory(data).createMediaSource(MediaItem.fromUri(video))
        } else {
            val progressive = ProgressiveMediaSource.Factory(data)
            val videoSource = progressive.createMediaSource(MediaItem.fromUri(video))
            if (audio == null) {
                videoSource
            } else {
                MergingMediaSource(videoSource, progressive.createMediaSource(MediaItem.fromUri(audio)))
            }
        }

        gen = call.argument<Int>("gen")!!
        openedAt = SystemClock.elapsedRealtime()
        videoDecoder = null
        audioDecoder = null
        dropped = 0
        lastPosition = longArrayOf(-1, -1, -1)
        rateFrames = -1
        // 听视频's switch lasts until the next open.
        setVideoEnabled(true)
        if (live) {
            // A live room starts at its live edge.
            p.setMediaSource(source)
        } else {
            p.setMediaSource(source, call.argument<Number>("startMs")?.toLong() ?: 0L)
        }
        p.repeatMode = Player.REPEAT_MODE_OFF
        p.playWhenReady = call.argument<Boolean>("play") ?: true
        p.prepare()
        Log.i(TAG, "open gen=$gen live=$live hls=$hls audio=${audio != null} maxPixels=$maxPixels")
    }

    /**
     * 听视频 during a video: the video track off (audio only) or back on. A
     * video track left out this way isn't a refusal (see onTracksChanged).
     */
    private fun setVideoEnabled(on: Boolean) {
        val p = player ?: return
        p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
            .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, !on)
            .build()
    }

    /** `mode` is `off`, `loudness` (gainDb, ceilingDb) or `dynamic`. */
    private fun setNormalization(call: MethodCall) {
        fun num(key: String) = call.argument<Number>(key)!!.toDouble()
        Log.i(TAG, "normalization ${call.arguments}")
        when (call.argument<String>("mode")) {
            "loudness" -> {
                dynamic.current = null
                loudness.current = TvExoLoudnessProcessor.Settings(num("gainDb"), num("ceilingDb"))
            }
            "dynamic" -> {
                loudness.current = null
                dynamic.current = TvExoDynamicNormalizer.Settings(
                    frameMs = num("frameMs").toInt(),
                    window = num("window").toInt(),
                    targetRms = num("targetRms"),
                    peak = num("peak"),
                    maxGain = num("maxGain"),
                )
            }
            else -> {
                loudness.current = null
                dynamic.current = null
            }
        }
    }

    private fun release() {
        main.removeCallbacks(ticker)
        player?.let {
            it.removeListener(listener)
            it.removeAnalyticsListener(analytics)
            it.release()
            Log.i(TAG, "released")
        }
        player = null
        loadControl = null
    }

    /**
     * A direct video request from byte 0 asks for `bytes=0-` (see
     * [TvExoRules.needsRangeZero]); everything else goes out as Media3 makes it.
     */
    private class RangeZeroDataSource(
        private val inner: HttpDataSource,
        private val live: Boolean,
    ) : DataSource {
        override fun addTransferListener(transferListener: TransferListener) =
            inner.addTransferListener(transferListener)

        override fun open(dataSpec: DataSpec): Long {
            if (TvExoRules.needsRangeZero(dataSpec.uri.host, live, dataSpec.position, dataSpec.length)) {
                inner.setRequestProperty("Range", "bytes=0-")
            } else {
                inner.clearRequestProperty("Range")
            }
            return inner.open(dataSpec)
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
            inner.read(buffer, offset, length)

        override fun getUri(): Uri? = inner.uri

        override fun getResponseHeaders(): Map<String, List<String>> = inner.responseHeaders

        override fun close() = inner.close()
    }

    // ---- Events ----

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) = sendState()

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) = sendState()

        override fun onIsPlayingChanged(isPlaying: Boolean) = sendState()

        // Dart's "caught up" signal for the thread ripper reads `loading`.
        override fun onIsLoadingChanged(isLoading: Boolean) = sendState()

        override fun onVideoSizeChanged(size: VideoSize) {
            send("videoSize", mapOf("w" to size.width, "h" to size.height))
        }

        override fun onRenderedFirstFrame() {
            val ms = (SystemClock.elapsedRealtime() - openedAt).toInt()
            Log.i(TAG, "firstFrame ${ms}ms")
            send("firstFrame", mapOf("ms" to ms))
        }

        override fun onTracksChanged(tracks: Tracks) {
            var videoGroups = 0
            var videoSelected = false
            var refused: Format? = null
            var audioTracks = 0
            var audioSelected = 0
            for (group in tracks.groups) {
                when (group.type) {
                    C.TRACK_TYPE_VIDEO -> {
                        videoGroups++
                        if (group.isSelected) videoSelected = true else refused = refused ?: group.getTrackFormat(0)
                    }
                    C.TRACK_TYPE_AUDIO -> for (i in 0 until group.length) {
                        audioTracks++
                        if (group.isTrackSelected(i)) audioSelected++
                    }
                }
            }
            send(
                "tracks",
                mapOf(
                    "videoTracks" to videoGroups,
                    "videoSelected" to videoSelected,
                    "audioTracks" to audioTracks,
                    "audioSelected" to audioSelected,
                ),
            )
            // Refused during track selection: no decoder has started.
            val f = refused
            val videoOff = player?.trackSelectionParameters
                ?.disabledTrackTypes?.contains(C.TRACK_TYPE_VIDEO) == true
            if (f != null && !videoSelected && !videoOff) {
                val dv = f.sampleMimeType == MimeTypes.VIDEO_DOLBY_VISION
                Log.w(TAG, "refused ${f.sampleMimeType} ${f.codecs} ${f.width}x${f.height}")
                player?.stop()
                send(
                    "error",
                    mapOf(
                        "kind" to "unsupported",
                        "recoverable" to false,
                        "dolbyVision" to dv,
                        "profile" to TvExoRules.dolbyVisionProfile(f.codecs),
                        "codecs" to f.codecs,
                        "width" to f.width,
                        "height" to f.height,
                        "message" to "no decoder takes ${f.codecs ?: f.sampleMimeType} ${f.width}x${f.height}",
                    ),
                )
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            val kind = TvExoRules.errorKind(error.errorCode)
            val causes = generateSequence<Throwable>(error) { it.cause }
            val status = causes.filterIsInstance<HttpDataSource.InvalidResponseCodeException>()
                .firstOrNull()?.responseCode
            val chain = causes.joinToString(" <- ") { "${it.javaClass.simpleName}: ${redact(it.message ?: "")}" }
            Log.e(TAG, "error kind=$kind code=${error.errorCodeName} status=$status $chain")
            send(
                "error",
                mapOf(
                    "kind" to kind,
                    "recoverable" to TvExoRules.isRecoverable(kind),
                    "code" to error.errorCodeName,
                    "status" to status,
                    "renderer" to (error as? ExoPlaybackException)
                        ?.takeIf { it.type == ExoPlaybackException.TYPE_RENDERER }?.rendererName,
                    "message" to chain,
                ),
            )
            sendState()
        }
    }

    private val analytics = object : AnalyticsListener {
        override fun onVideoDecoderInitialized(
            eventTime: AnalyticsListener.EventTime,
            decoderName: String,
            initializedTimestampMs: Long,
            initializationDurationMs: Long,
        ) {
            videoDecoder = decoderName
            sendVideoFormat()
        }

        override fun onVideoInputFormatChanged(
            eventTime: AnalyticsListener.EventTime,
            format: Format,
            decoderReuseEvaluation: androidx.media3.exoplayer.DecoderReuseEvaluation?,
        ) = sendVideoFormat()

        override fun onAudioDecoderInitialized(
            eventTime: AnalyticsListener.EventTime,
            decoderName: String,
            initializedTimestampMs: Long,
            initializationDurationMs: Long,
        ) {
            audioDecoder = decoderName
            sendAudioFormat()
        }

        override fun onAudioInputFormatChanged(
            eventTime: AnalyticsListener.EventTime,
            format: Format,
            decoderReuseEvaluation: androidx.media3.exoplayer.DecoderReuseEvaluation?,
        ) = sendAudioFormat()

        override fun onDroppedVideoFrames(
            eventTime: AnalyticsListener.EventTime,
            droppedFrames: Int,
            elapsedMs: Long,
        ) {
            dropped += droppedFrames
            send("dropped", mapOf("count" to dropped))
        }

        override fun onLoadError(
            eventTime: AnalyticsListener.EventTime,
            loadEventInfo: androidx.media3.exoplayer.source.LoadEventInfo,
            mediaLoadData: androidx.media3.exoplayer.source.MediaLoadData,
            error: java.io.IOException,
            wasCanceled: Boolean,
        ) {
            // Media3 retries these itself; a lasting one ends in onPlayerError.
            val status = (error as? HttpDataSource.InvalidResponseCodeException)?.responseCode
            Log.w(
                TAG,
                "loadError host=${loadEventInfo.uri.host} status=$status " +
                    "${error.javaClass.simpleName}: ${redact(error.message ?: "")}",
            )
        }
    }

    private fun sendVideoFormat() {
        val f = player?.videoFormat ?: return
        val dvDecoder = videoDecoder?.let { name -> dolbyVisionDecoders().any { it.name == name } } ?: false
        val hdr = TvExoRules.hdrType(f.sampleMimeType, f.colorInfo?.colorTransfer ?: Format.NO_VALUE, dvDecoder)
        Log.i(TAG, "videoFormat ${f.sampleMimeType} ${f.codecs} ${f.width}x${f.height}@${f.frameRate} hdr=$hdr decoder=$videoDecoder")
        send(
            "videoFormat",
            mapOf(
                "mime" to f.sampleMimeType,
                "codecs" to f.codecs,
                "width" to f.width,
                "height" to f.height,
                "frameRate" to f.frameRate.toDouble(),
                "hdr" to hdr,
                "profile" to TvExoRules.dolbyVisionProfile(f.codecs),
                "decoder" to videoDecoder,
            ),
        )
    }

    private fun sendAudioFormat() {
        val f = player?.audioFormat ?: return
        send(
            "audioFormat",
            mapOf(
                "mime" to f.sampleMimeType,
                "codecs" to f.codecs,
                "sampleRate" to f.sampleRate,
                "channels" to f.channelCount,
                "decoder" to audioDecoder,
            ),
        )
    }

    /**
     * Frames per second, measured from the decoder's output every 2 s while
     * playing. Live FLV and fMP4 carry no frame rate, so the format says -1.
     */
    private fun measureFrameRate() {
        val p = player ?: return
        val c = p.videoDecoderCounters ?: return
        c.ensureUpdated()
        val frames = c.renderedOutputBufferCount + c.droppedBufferCount + c.skippedOutputBufferCount
        val now = SystemClock.elapsedRealtime()
        if (rateFrames < 0 || frames < rateFrames || !p.isPlaying) {
            rateAt = now
            rateFrames = frames
            return
        }
        if (now - rateAt < RATE_WINDOW_MS) return
        send("frameRate", mapOf("fps" to (frames - rateFrames) * 1000.0 / (now - rateAt)))
        rateAt = now
        rateFrames = frames
    }

    private fun sendState() {
        val p = player ?: return
        send(
            "state",
            mapOf(
                "state" to p.playbackState,
                "playWhenReady" to p.playWhenReady,
                "playing" to p.isPlaying,
                "loading" to p.isLoading,
            ),
        )
        sendPosition()
    }

    private fun sendPosition() {
        val p = player ?: return
        if (p.playbackState == Player.STATE_IDLE) return
        val now = longArrayOf(
            p.currentPosition,
            p.bufferedPosition,
            p.duration.let { if (it == C.TIME_UNSET) 0 else it },
        )
        if (now.contentEquals(lastPosition)) return
        lastPosition = now
        send("position", mapOf("pos" to now[0], "buf" to now[1], "dur" to now[2], "live" to p.isCurrentMediaItemLive))
    }

    private fun send(type: String, args: Map<String, Any?>) {
        channel.invokeMethod(type, args + ("gen" to gen))
    }

    /** For 播放信息 and the device runs. */
    private fun stats(): Map<String, Any?> {
        val p = player ?: return mapOf("player" to false)
        val counters = p.videoDecoderCounters?.also { it.ensureUpdated() }
        val runtime = Runtime.getRuntime()
        return mapOf(
            "player" to true,
            "state" to p.playbackState,
            "pos" to p.currentPosition,
            "bufferedMs" to p.totalBufferedDuration,
            "videoDecoder" to videoDecoder,
            "audioDecoder" to audioDecoder,
            "rendered" to counters?.renderedOutputBufferCount,
            "dropped" to counters?.droppedBufferCount,
            "decoderInits" to counters?.decoderInitCount,
            "bound" to (bound != null),
            "allocatedBytes" to loadControl?.totalBytesAllocated,
            "heapUsedBytes" to runtime.totalMemory() - runtime.freeMemory(),
            "heapLimitBytes" to runtime.maxMemory(),
        )
    }

    // ---- Decoders ----

    private fun dolbyVisionDecoders(): List<MediaCodecInfo> = try {
        MediaCodecUtil.getDecoderInfos(MimeTypes.VIDEO_DOLBY_VISION, false, false)
    } catch (_: MediaCodecUtil.DecoderQueryException) {
        emptyList()
    }

    /** Whether a Dolby Vision decoder declares [format]'s exact profile. */
    private fun dolbyVisionDeclared(format: Format): Boolean {
        val profile = MediaCodecUtil.getCodecProfileAndLevel(format)?.first ?: return false
        return dolbyVisionDecoders().any { d -> d.profileLevels.any { it.profile == profile } }
    }

    /** The video decoders and what each declares, for Dart and 播放信息. */
    private fun decoders(): List<Map<String, Any?>> =
        VIDEO_MIMES.flatMap { mime ->
            val infos = try {
                MediaCodecUtil.getDecoderInfos(mime, false, false)
            } catch (_: MediaCodecUtil.DecoderQueryException) {
                emptyList()
            }
            infos.map { d ->
                val video = d.capabilities?.videoCapabilities
                mapOf(
                    "name" to d.name,
                    "mime" to mime,
                    "hardware" to d.hardwareAccelerated,
                    "maxWidth" to video?.supportedWidths?.upper,
                    "maxHeight" to video?.supportedHeights?.upper,
                    "profileLevels" to d.profileLevels.map { listOf(it.profile, it.level) },
                )
            }
        }

    /**
     * For each stream Dart may pick (`codecs`, `width`, `height`, `frameRate`):
     * `yes`, `dolbyVision`, `baseLayer` (Profile 8's HEVC layer) or `no`, by
     * the same rule the renderer applies, so the quality list never offers a
     * stream past what its decoder declares.
     */
    private fun supports(streams: List<*>): List<String> = streams.map { item ->
        val s = item as Map<*, *>
        val codecs = s["codecs"] as? String
        val mime = MimeTypes.getVideoMediaMimeType(codecs)
        if (mime == null) {
            "no"
        } else {
            val format = Format.Builder()
                .setSampleMimeType(mime)
                .setCodecs(codecs)
                .setWidth((s["width"] as? Number)?.toInt() ?: Format.NO_VALUE)
                .setHeight((s["height"] as? Number)?.toInt() ?: Format.NO_VALUE)
                .setFrameRate((s["frameRate"] as? Number)?.toFloat() ?: Format.NO_VALUE.toFloat())
                .build()
            val dv = mime == MimeTypes.VIDEO_DOLBY_VISION
            val declared = dv && dolbyVisionDeclared(format)
            val media3 = RendererCapabilities.getFormatSupport(
                MediaCodecVideoRenderer.supportsFormat(context, MediaCodecSelector.DEFAULT, format),
            )
            val support = TvExoRules.videoFormatSupport(
                media3,
                dv,
                TvExoRules.dolbyVisionProfile(codecs),
                declared,
            )
            TvExoRules.supportName(support, dv, declared)
        }
    }

    /**
     * The HDR types the display reports, as `Display.HdrCapabilities`
     * numbers (1 Dolby Vision, 2 HDR10, 3 HLG, 4 HDR10+), for the quality
     * list (M17.9). Empty when it reports none or can't be read.
     */
    @Suppress("DEPRECATION")
    private fun displayHdrTypes(): List<Int> = try {
        val display = activity.windowManager.defaultDisplay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            display.mode.supportedHdrTypes.toList()
        } else {
            display.hdrCapabilities?.supportedHdrTypes?.toList() ?: emptyList()
        }
    } catch (_: Throwable) {
        emptyList()
    }

    /**
     * The video renderer: no placeholder surface (M17.2, decision 3), and
     * [TvExoRules.videoFormatSupport] decides during track selection.
     */
    private inner class PlaneVideoRenderer(
        builder: MediaCodecVideoRenderer.Builder,
        private val pixelLimit: () -> Int,
    ) : MediaCodecVideoRenderer(builder) {
        override fun shouldUsePlaceholderSurface(codecInfo: MediaCodecInfo): Boolean = false

        override fun supportsFormat(mediaCodecSelector: MediaCodecSelector, format: Format): Int {
            val support = super.supportsFormat(mediaCodecSelector, format)
            val media3 = RendererCapabilities.getFormatSupport(support)
            val dv = format.sampleMimeType == MimeTypes.VIDEO_DOLBY_VISION
            val declared = dv && dolbyVisionDeclared(format)
            val limit = pixelLimit()
            val fits = limit <= 0 || format.width <= 0 || format.height <= 0 ||
                format.width.toLong() * format.height <= limit
            val decided = TvExoRules.videoFormatSupport(
                media3,
                dv,
                TvExoRules.dolbyVisionProfile(format.codecs),
                declared,
                fits,
            )
            if (decided != media3) {
                Log.i(TAG, "track ${format.codecs} ${format.width}x${format.height}: media3=$media3 decided=$decided")
            }
            return if (decided == media3) {
                support
            } else {
                RendererCapabilities.create(
                    decided,
                    RendererCapabilities.getAdaptiveSupport(support),
                    RendererCapabilities.getTunnelingSupport(support),
                    RendererCapabilities.getHardwareAccelerationSupport(support),
                    RendererCapabilities.getDecoderSupport(support),
                )
            }
        }
    }

    // ---- The surface under Flutter's view ----

    private val surfaceCallback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder) {
            surfaces.add(holder.surface)
            bind(holder.surface)
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            val surface = holder.surface
            surfaces.remove(surface)
            if (bound === surface) {
                // The decoder goes with the surface; the player stays.
                player?.clearVideoSurface(surface)
                bound = null
                surfaces.lastOrNull()?.let(::bind)
            }
            Log.i(TAG, "surfaceDestroyed left=${surfaces.size}")
        }
    }

    private fun bind(surface: Surface) {
        bound = surface
        player?.setVideoSurface(surface)
        Log.i(TAG, "surfaceBound player=${player != null}")
    }

    /** The `SurfaceView` under Flutter's view, at the rect in pixels; null lets it go. */
    private fun layerRect(rect: Map<*, *>?) {
        main.removeCallbacks(hideLayer)
        if (rect == null) {
            // A route change sends null and then a new rect, so wait a moment.
            main.postDelayed(hideLayer, HIDE_DELAY_MS)
            return
        }
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        val view = layer ?: SurfaceView(activity).also {
            // D-pad focus stays in Flutter.
            it.isFocusable = false
            it.isFocusableInTouchMode = false
            it.holder.addCallback(surfaceCallback)
            layer = it
            content.addView(it, 0, FrameLayout.LayoutParams(1, 1))
        }
        view.layoutParams = FrameLayout.LayoutParams(
            (rect["w"] as Number).toInt(),
            (rect["h"] as Number).toInt(),
        ).apply {
            leftMargin = (rect["l"] as Number).toInt()
            topMargin = (rect["t"] as Number).toInt()
        }
        view.visibility = View.VISIBLE
    }

    /** Makes Flutter's own surface see-through, or opaque again, while the app runs. */
    private fun setTransparent(on: Boolean): Boolean {
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        val flutter = findFlutterSurface(content) ?: return false
        flutter.holder.setFormat(if (on) PixelFormat.TRANSPARENT else PixelFormat.OPAQUE)
        flutter.setZOrderOnTop(on)
        return true
    }

    private fun findFlutterSurface(view: View): FlutterSurfaceView? {
        if (view is FlutterSurfaceView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findFlutterSurface(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }

    /** The dev build's test page, asked for with `--es tv_exo_test` at launch. */
    private fun takeTestRequest(): String? {
        if (!activity.packageName.endsWith(".dev")) return null
        val intent = activity.intent ?: return null
        return intent.getStringExtra(TEST_EXTRA).also { intent.removeExtra(TEST_EXTRA) }
    }

    companion object {
        private const val TAG = "TvExoPlayer"
        private const val CHANNEL = "com.example.piliplus/tv_exo"
        private const val TEST_EXTRA = "tv_exo_test"
        private const val POSITION_MS = 250L
        private const val HIDE_DELAY_MS = 500L
        private const val RATE_WINDOW_MS = 2000L
        private const val MAX_DROPPED_TO_NOTIFY = 50

        private val VIDEO_MIMES = listOf(
            MimeTypes.VIDEO_H264,
            MimeTypes.VIDEO_H265,
            MimeTypes.VIDEO_AV1,
            MimeTypes.VIDEO_DOLBY_VISION,
        )

        fun register(flutterEngine: FlutterEngine, activity: Activity) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(TvExoPlayer(activity, channel))
        }

        // Stream URLs carry signed query strings.
        private fun redact(text: String): String = text.replace(Regex("\\?[^ ]*"), "?…")
    }
}
