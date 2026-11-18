package com.example.piliplus

import androidx.media3.common.C
import androidx.media3.common.MimeTypes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The bridge's pure rules (docs/tv/PLAN.md, M17.11), on the JVM:
 * `./gradlew :app:testDebugUnitTest` in `android/`.
 */
class TvExoRulesTest {
    private val handled = C.FORMAT_HANDLED
    private val exceeds = C.FORMAT_EXCEEDS_CAPABILITIES
    private val subtype = C.FORMAT_UNSUPPORTED_SUBTYPE
    private val type = C.FORMAT_UNSUPPORTED_TYPE

    @Test
    fun dolbyVisionProfileFromCodecs() {
        assertEquals(5, TvExoRules.dolbyVisionProfile("dvhe.05.06"))
        assertEquals(8, TvExoRules.dolbyVisionProfile("dvh1.08.07"))
        assertEquals(10, TvExoRules.dolbyVisionProfile("dav1.10.09"))
        assertEquals(9, TvExoRules.dolbyVisionProfile("dva1.09.05"))
        assertEquals(7, TvExoRules.dolbyVisionProfile("dvav.07.06"))
        assertNull(TvExoRules.dolbyVisionProfile("hev1.2.4.L156.90"))
        assertNull(TvExoRules.dolbyVisionProfile("dvh1"))
        assertNull(TvExoRules.dolbyVisionProfile("dvh1.xx.06"))
        assertNull(TvExoRules.dolbyVisionProfile(null))
    }

    @Test
    fun dolbyVisionPlaysWhereADecoderDeclaresItsProfile() {
        // Profile 5 at 3996 × 2160 fails Android's size check; the declared
        // profile wins.
        for (media3 in listOf(handled, exceeds)) {
            assertEquals(
                handled,
                TvExoRules.videoFormatSupport(media3, dolbyVision = true, profile = 5, declared = true),
            )
        }
        // Not past a missing decoder.
        assertEquals(
            subtype,
            TvExoRules.videoFormatSupport(subtype, dolbyVision = true, profile = 5, declared = true),
        )
    }

    @Test
    fun withNoDolbyVisionDecoderOnlyProfile8PlaysItsBaseLayer() {
        assertEquals(
            handled,
            TvExoRules.videoFormatSupport(handled, dolbyVision = true, profile = 8, declared = false),
        )
        for (profile in listOf(5, 7, 10, null)) {
            assertEquals(
                "profile $profile",
                subtype,
                TvExoRules.videoFormatSupport(handled, dolbyVision = true, profile = profile, declared = false),
            )
        }
        // A base layer past its decoder isn't tried, even when asked.
        assertEquals(
            subtype,
            TvExoRules.videoFormatSupport(
                exceeds,
                dolbyVision = true,
                profile = 8,
                declared = false,
                withinDeclared = true,
                tryAnyway = true,
            ),
        )
    }

    @Test
    fun aStreamPastItsDecoderIsRefusedUnlessTheDeclaredRangesCoverIt() {
        assertEquals(
            subtype,
            TvExoRules.videoFormatSupport(exceeds, dolbyVision = false, profile = null, declared = false),
        )
        // 3996 × 2160 @ 24 past the one performance point, inside the ranges.
        assertEquals(
            handled,
            TvExoRules.videoFormatSupport(
                exceeds,
                dolbyVision = false,
                profile = null,
                declared = false,
                withinDeclared = true,
            ),
        )
        assertEquals(
            handled,
            TvExoRules.videoFormatSupport(handled, dolbyVision = false, profile = null, declared = false),
        )
        // Media3's own refusals pass through.
        assertEquals(type, TvExoRules.videoFormatSupport(type, dolbyVision = false, profile = null, declared = false))
    }

    @Test
    fun theDevCapRefusesEvenAHandledStream() {
        for (dv in listOf(false, true)) {
            assertEquals(
                subtype,
                TvExoRules.videoFormatSupport(handled, dolbyVision = dv, profile = 8, declared = true, fits = false),
            )
        }
    }

    @Test
    fun tryAnywayLetsOnlyExceedsThrough() {
        assertEquals(
            handled,
            TvExoRules.videoFormatSupport(exceeds, dolbyVision = false, profile = null, declared = false, tryAnyway = true),
        )
        assertEquals(
            subtype,
            TvExoRules.videoFormatSupport(subtype, dolbyVision = false, profile = null, declared = false, tryAnyway = true),
        )
        assertTrue(TvExoRules.tryable(exceeds, dolbyVision = false))
        assertFalse(TvExoRules.tryable(exceeds, dolbyVision = true))
        assertFalse(TvExoRules.tryable(subtype, dolbyVision = false))
        assertFalse(TvExoRules.tryable(handled, dolbyVision = false))
    }

    @Test
    fun supportNames() {
        assertEquals("no", TvExoRules.supportName(subtype, dolbyVision = false, declared = false))
        assertEquals("no", TvExoRules.supportName(exceeds, dolbyVision = true, declared = true))
        assertEquals("yes", TvExoRules.supportName(handled, dolbyVision = false, declared = false))
        assertEquals("dolbyVision", TvExoRules.supportName(handled, dolbyVision = true, declared = true))
        assertEquals("baseLayer", TvExoRules.supportName(handled, dolbyVision = true, declared = false))
    }

    @Test
    fun hdrTypes() {
        val dv = MimeTypes.VIDEO_DOLBY_VISION
        val hevc = MimeTypes.VIDEO_H265
        assertEquals("dolbyVision", TvExoRules.hdrType(dv, C.COLOR_TRANSFER_ST2084, dolbyVisionDecoder = true))
        assertEquals("hdr10", TvExoRules.hdrType(dv, C.COLOR_TRANSFER_ST2084, dolbyVisionDecoder = false))
        assertEquals("hlg", TvExoRules.hdrType(dv, C.COLOR_TRANSFER_HLG, dolbyVisionDecoder = false))
        // Profile 8.4's base layer with an SPS that doesn't say HLG.
        assertEquals("hlg", TvExoRules.hdrType(dv, C.COLOR_TRANSFER_SDR, dolbyVisionDecoder = false))
        assertEquals("hdr10", TvExoRules.hdrType(hevc, C.COLOR_TRANSFER_ST2084, dolbyVisionDecoder = false))
        assertEquals("hlg", TvExoRules.hdrType(hevc, C.COLOR_TRANSFER_HLG, dolbyVisionDecoder = false))
        assertEquals("sdr", TvExoRules.hdrType(hevc, C.COLOR_TRANSFER_SDR, dolbyVisionDecoder = false))
        assertEquals("sdr", TvExoRules.hdrType(null, -1, dolbyVisionDecoder = false))
    }

    @Test
    fun errorKindsAndWhichAreRetried() {
        // PlaybackException's codes.
        val cases = mapOf(
            1002 to "behindLiveWindow",
            2001 to "network", // IO_NETWORK_CONNECTION_FAILED
            2002 to "network", // IO_NETWORK_CONNECTION_TIMEOUT
            2004 to "http", // IO_BAD_HTTP_STATUS
            2005 to "network", // IO_FILE_NOT_FOUND
            3001 to "format", // PARSING_CONTAINER_MALFORMED
            4001 to "decoder", // DECODER_INIT_FAILED
            4003 to "decoder", // DECODING_FAILED
            5001 to "audio", // AUDIO_TRACK_INIT_FAILED
            1000 to "other", // UNSPECIFIED
            6000 to "other", // DRM
            7000 to "other", // VIDEO_FRAME_PROCESSOR
        )
        for ((code, kind) in cases) {
            assertEquals("code $code", kind, TvExoRules.errorKind(code))
        }
        for (kind in listOf("http", "network", "behindLiveWindow")) {
            assertTrue(kind, TvExoRules.isRecoverable(kind))
        }
        for (kind in listOf("format", "decoder", "audio", "other", "unsupported", "ended")) {
            assertFalse(kind, TvExoRules.isRecoverable(kind))
        }
    }

    @Test
    fun aDirectVideoRequestFromByteZeroAsksForARange() {
        val unset = C.LENGTH_UNSET.toLong()
        assertTrue(TvExoRules.needsRangeZero("upos-sz-mirrorcosov.bilivideo.com", false, 0, unset))
        // The ripper's proxy, live streams, a later position or a set length:
        // left as Media3 makes them.
        assertFalse(TvExoRules.needsRangeZero(TvExoRules.LOOPBACK, false, 0, unset))
        assertFalse(TvExoRules.needsRangeZero("cn-a.bilivideo.com", true, 0, unset))
        assertFalse(TvExoRules.needsRangeZero("upos.bilivideo.com", false, 1024, unset))
        assertFalse(TvExoRules.needsRangeZero("upos.bilivideo.com", false, 0, 4096))
        assertTrue(TvExoRules.needsRangeZero(null, false, 0, unset))
    }

    @Test
    fun bufferCapsWithZeroForNone() {
        assertEquals(Int.MAX_VALUE, TvExoRules.capBytes(0))
        assertEquals(Int.MAX_VALUE, TvExoRules.capBytes(-1))
        assertEquals(100 * 1024 * 1024, TvExoRules.capBytes(100L * 1024 * 1024))
        // Past Int's range, the most Media3 can take; no other clamp.
        assertEquals(Int.MAX_VALUE, TvExoRules.capBytes(4096L * 1024 * 1024))
        assertEquals(Long.MAX_VALUE, TvExoRules.capUs(0))
        assertEquals(180_000_000L, TvExoRules.capUs(180_000))
    }

    @Test
    fun liveStartTagIsDroppedSoPlaybackStartsAtTheEdge() {
        val playlist = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-START:TIME-OFFSET=0\n" +
            "#EXT-X-MEDIA-SEQUENCE:5\n#EXT-X-TARGETDURATION:1\n#EXTINF:1.00,a|b\n5.m4s\n"
        val out = TvExoRules.withoutStartTag(playlist)
        assertFalse(out.contains("EXT-X-START"))
        assertTrue(out.contains("#EXT-X-MEDIA-SEQUENCE:5\n#EXT-X-TARGETDURATION:1\n#EXTINF:1.00,a|b\n5.m4s"))
        // CRLF lines, and a playlist without the tag is returned as it is.
        assertFalse(TvExoRules.withoutStartTag("#EXTM3U\r\n#EXT-X-START:TIME-OFFSET=-3\r\n1.m4s").contains("EXT-X-START"))
        val plain = "#EXTM3U\n#EXTINF:1.00,\n1.m4s\n"
        assertSame(plain, TvExoRules.withoutStartTag(plain))
    }
}
