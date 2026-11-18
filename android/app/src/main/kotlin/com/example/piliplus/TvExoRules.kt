package com.example.piliplus

import androidx.media3.common.C
import androidx.media3.common.MimeTypes

/**
 * The pure parts of the TV's Media3 bridge (docs/tv/PLAN.md, M17.7), kept
 * apart from Android so M17.11 can test them on the JVM.
 */
object TvExoRules {
    /**
     * The Dolby Vision profile in a `codecs` string: `dvhe.05.06` is 5,
     * `dvh1.08.07` is 8, `dav1.10.09` is 10. Null for anything else.
     */
    fun dolbyVisionProfile(codecs: String?): Int? {
        val parts = codecs?.split('.') ?: return null
        if (parts.size < 2 || parts[0] !in DOLBY_VISION_PREFIXES) return null
        return parts[1].toIntOrNull()
    }

    /**
     * Which format support the video renderer reports for a stream
     * (M17.6, decision 9):
     *  - a Dolby Vision stream plays when a Dolby Vision decoder declares its
     *    exact profile, even where Android's size check fails (Profile 5 is
     *    3996 × 2160 on Bilibili);
     *  - with no such decoder, Profile 8 may play its HEVC base layer when an
     *    HEVC decoder takes it; any other profile is refused;
     *  - no other stream plays past what its decoder declares, so Media3's
     *    "exceeds capabilities" becomes "unsupported", and the track selector
     *    never picks it, unless [withinDeclared]: a hardware decoder takes
     *    the stream's profile and level and its declared size and frame-rate
     *    ranges cover it. Media3 on API 29+ asks the decoder's performance
     *    points instead, and a TV whose only point is 3840 × 2160 @ 60 then
     *    refuses Bilibili's 3996 × 2160 @ 24 4K, which its decoders declare
     *    and play (M17.9, the user, 2026-11-16);
     *  - a stream larger than [fits] allows is refused (the dev test page's
     *    1080p cap);
     *  - [tryAnyway] (仍要尝试, M17.10, one open at the user's request):
     *    Media3's "exceeds" is tried instead of refused, for a stream that
     *    [tryable] allows.
     * Refusing here means no decoder ever starts for the stream.
     */
    fun videoFormatSupport(
        media3: Int,
        dolbyVision: Boolean,
        profile: Int?,
        declared: Boolean,
        fits: Boolean = true,
        withinDeclared: Boolean = false,
        tryAnyway: Boolean = false,
    ): Int {
        if (!fits) return C.FORMAT_UNSUPPORTED_SUBTYPE
        if (dolbyVision && declared &&
            (media3 == C.FORMAT_HANDLED || media3 == C.FORMAT_EXCEEDS_CAPABILITIES)
        ) {
            return C.FORMAT_HANDLED
        }
        return when (media3) {
            C.FORMAT_HANDLED -> if (!dolbyVision || profile == 8) {
                C.FORMAT_HANDLED
            } else {
                C.FORMAT_UNSUPPORTED_SUBTYPE
            }
            C.FORMAT_EXCEEDS_CAPABILITIES ->
                if (!dolbyVision && (withinDeclared || tryAnyway)) {
                    C.FORMAT_HANDLED
                } else {
                    C.FORMAT_UNSUPPORTED_SUBTYPE
                }
            else -> media3
        }
    }

    /**
     * Whether a refused stream may be tried once anyway (仍要尝试, M17.10): a
     * decoder for its codec exists and Media3 only finds the stream past what
     * that decoder declares (level, size or rate). Never Dolby Vision, which
     * plays only through a Dolby Vision decoder, and never a stream with no
     * decoder at all.
     */
    fun tryable(media3: Int, dolbyVision: Boolean): Boolean =
        !dolbyVision && media3 == C.FORMAT_EXCEEDS_CAPABILITIES

    /** What [videoFormatSupport] means for the quality list in Dart. */
    fun supportName(support: Int, dolbyVision: Boolean, declared: Boolean): String = when {
        support != C.FORMAT_HANDLED -> "no"
        dolbyVision && declared -> "dolbyVision"
        dolbyVision -> "baseLayer"
        else -> "yes"
    }

    /** The HDR type of a playing stream, for Dart and 播放信息. */
    fun hdrType(mime: String?, colorTransfer: Int, dolbyVisionDecoder: Boolean): String = when {
        mime == MimeTypes.VIDEO_DOLBY_VISION && dolbyVisionDecoder -> "dolbyVision"
        colorTransfer == C.COLOR_TRANSFER_ST2084 -> "hdr10"
        colorTransfer == C.COLOR_TRANSFER_HLG -> "hlg"
        // Profile 8.4's base layer is HLG; its SPS may not say so.
        mime == MimeTypes.VIDEO_DOLBY_VISION -> "hlg"
        else -> "sdr"
    }

    /**
     * A small set of error kinds from Media3's error code, for Dart's retry
     * and messages. `recoverable` kinds are worth a bounded retry; a live
     * room reconnects on them.
     */
    fun errorKind(errorCode: Int): String = when (errorCode) {
        ERROR_CODE_BEHIND_LIVE_WINDOW -> "behindLiveWindow"
        ERROR_CODE_IO_BAD_HTTP_STATUS -> "http"
        in 2000..2999 -> "network"
        in 3000..3999 -> "format"
        in 4000..4999 -> "decoder"
        in 5000..5999 -> "audio"
        else -> "other"
    }

    fun isRecoverable(kind: String): Boolean =
        kind == "http" || kind == "network" || kind == "behindLiveWindow"

    /**
     * A live room's HLS playlist without `#EXT-X-START`. Bilibili's start
     * with `#EXT-X-START:TIME-OFFSET=0` over a window of about seven
     * one-second segments, and Media3 honours it: playback starts at the
     * oldest segment, and any delay drops it out of the window
     * (BEHIND_LIVE_WINDOW; M17.12 on `<physical-tv>`). Without the tag Media3
     * starts three target durations from the live edge, as mpv's demuxer does.
     */
    fun withoutStartTag(playlist: String): String {
        if (!playlist.contains("#EXT-X-START:")) return playlist
        return playlist.lineSequence()
            .filterNot { it.trimStart().startsWith("#EXT-X-START:") }
            .joinToString("\n")
    }

    /**
     * Bilibili's `upos-sz-mirrorcosov` answers 567 to a request with no Range
     * header (the1812/Bilibili-Evolved#5857), and Media3 sends none when it
     * reads from byte 0. So a direct video request from byte 0 asks for
     * `bytes=0-`. The ripper's loopback proxy and live streams are left as
     * they are.
     */
    fun needsRangeZero(host: String?, live: Boolean, position: Long, length: Long): Boolean =
        !live && host != LOOPBACK && position == 0L && length == C.LENGTH_UNSET.toLong()

    /** The byte cap: none for zero or less. No other clamp (M17.6, decision 10). */
    fun capBytes(bytes: Long): Int = if (bytes <= 0) Int.MAX_VALUE else bytes.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

    /** The time cap in microseconds: none for zero or less. */
    fun capUs(ms: Long): Long = if (ms <= 0) Long.MAX_VALUE else ms * 1000

    const val LOOPBACK = "127.0.0.1"

    // PlaybackException's codes, as plain numbers so the JVM tests need no
    // Android classes.
    const val ERROR_CODE_BEHIND_LIVE_WINDOW = 1002
    const val ERROR_CODE_IO_BAD_HTTP_STATUS = 2004

    private val DOLBY_VISION_PREFIXES = setOf("dvhe", "dvh1", "dvav", "dva1", "dav1")
}
