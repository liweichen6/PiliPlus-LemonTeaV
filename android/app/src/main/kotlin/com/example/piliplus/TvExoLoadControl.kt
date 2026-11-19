package com.example.piliplus

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.source.TrackGroupArray
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.Allocator
import androidx.media3.exoplayer.upstream.DefaultAllocator

/**
 * Media3's buffer from the app's own settings (M17.6, decision 10): 缓冲大小
 * and 缓冲时长 for a video, 直播缓冲大小 and 直播缓冲时长 for a live room, as a
 * byte cap and a time cap, bytes before time, forward only, and no clamp.
 *
 * One player plays a video and a live room in turn (decision 5), and
 * `DefaultLoadControl` fixes its sizes when it's built, so this one takes new
 * caps at each open. It follows `DefaultLoadControl` otherwise: loading stops
 * at either cap, playback starts after 1 s (2 s after a rebuffer, or half the
 * live offset), or once the byte cap is full. The minimum and maximum are the
 * same, as loneshu7/PiliPlusPlus (GPL-3.0, commit 5bdf4bfd6) maps them, which
 * M17.2 checked against Media3 1.11.1.
 */
@OptIn(UnstableApi::class)
class TvExoLoadControl : LoadControl {
    private val allocator = DefaultAllocator(true, C.DEFAULT_BUFFER_SEGMENT_SIZE)

    @Volatile
    private var capBytes = TvExoRules.capBytes(DEFAULT_BYTES)

    @Volatile
    private var capUs = TvExoRules.capUs(DEFAULT_MS)

    /** New caps for the next media; zero or less means no cap. */
    fun configure(bytes: Long, ms: Long) {
        capBytes = TvExoRules.capBytes(bytes)
        capUs = TvExoRules.capUs(ms)
    }

    val totalBytesAllocated: Int get() = allocator.totalBytesAllocated

    override fun getAllocator(playerId: PlayerId): Allocator = allocator

    override fun onTracksSelected(
        parameters: LoadControl.Parameters,
        trackGroups: TrackGroupArray,
        trackSelections: Array<out ExoTrackSelection?>,
    ) {
        // Freed memory is kept up to the cap, as DefaultLoadControl does. With
        // no byte cap, nothing freed is kept.
        allocator.setTargetBufferSize(if (capBytes == Int.MAX_VALUE) 0 else capBytes)
    }

    // The interface's defaults throw for these, so each is overridden.
    override fun onPrepared(playerId: PlayerId) = allocator.reset()

    override fun onStopped(playerId: PlayerId) = allocator.reset()

    override fun onReleased(playerId: PlayerId) = allocator.reset()

    override fun getBackBufferDurationUs(playerId: PlayerId): Long = 0

    override fun retainBackBufferFromKeyframe(playerId: PlayerId): Boolean = false

    override fun shouldContinueLoading(parameters: LoadControl.Parameters): Boolean {
        if (allocator.totalBytesAllocated >= capBytes) return false
        return playout(parameters) < capUs
    }

    override fun shouldStartPlayback(parameters: LoadControl.Parameters): Boolean {
        var minUs = if (parameters.rebuffering) AFTER_REBUFFER_US else FOR_PLAYBACK_US
        if (parameters.targetLiveOffsetUs != C.TIME_UNSET) {
            minUs = minOf(parameters.targetLiveOffsetUs / 2, minUs)
        }
        return minUs <= 0 ||
            playout(parameters) >= minUs ||
            allocator.totalBytesAllocated >= capBytes
    }

    // The buffer in playing time, so the caps hold at any speed.
    private fun playout(parameters: LoadControl.Parameters): Long =
        Util.getPlayoutDurationForMediaDuration(parameters.bufferedDurationUs, parameters.playbackSpeed)

    private companion object {
        const val DEFAULT_BYTES = 4L * 1024 * 1024
        const val DEFAULT_MS = 16_000L
        const val FOR_PLAYBACK_US = 1_000_000L
        const val AFTER_REBUFFER_US = 2_000_000L
    }
}
