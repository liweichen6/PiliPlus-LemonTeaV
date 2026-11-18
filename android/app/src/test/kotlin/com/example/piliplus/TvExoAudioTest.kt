package com.example.piliplus

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * 音量均衡's two audio processors (docs/tv/PLAN.md, M17.11), driven as
 * Media3's audio sink drives them: configure, flush, then buffers of PCM.
 */
@OptIn(UnstableApi::class)
class TvExoAudioTest {
    private val rate = 48_000

    /** [seconds] of a square wave at [amplitude], interleaved. */
    private fun square(amplitude: Double, seconds: Double, channels: Int = 2): DoubleArray {
        val frames = (rate * seconds).toInt()
        return DoubleArray(frames * channels) { i ->
            val frame = i / channels
            if ((frame / 24) % 2 == 0) amplitude else -amplitude
        }
    }

    /** Runs [samples] through [processor] in 1024-frame buffers. */
    private fun run(
        processor: TvExoNormalizer,
        samples: DoubleArray,
        channels: Int = 2,
        encoding: Int = C.ENCODING_PCM_16BIT,
    ): DoubleArray {
        val float = encoding == C.ENCODING_PCM_FLOAT
        val bytes = if (float) 4 else 2
        val out = ArrayList<Double>(samples.size)
        val chunk = 1024 * channels
        var i = 0
        while (i < samples.size) {
            val end = minOf(samples.size, i + chunk)
            val input = ByteBuffer.allocateDirect((end - i) * bytes).order(ByteOrder.nativeOrder())
            for (j in i until end) {
                if (float) input.putFloat(samples[j].toFloat()) else input.putShort((samples[j] * 32767).toInt().toShort())
            }
            input.flip()
            processor.queueInput(input)
            val output = processor.output
            while (output.hasRemaining()) {
                out += if (float) output.float.toDouble() else output.short / 32768.0
            }
            i = end
        }
        return out.toDoubleArray()
    }

    private fun configure(processor: TvExoNormalizer, channels: Int = 2, encoding: Int = C.ENCODING_PCM_16BIT) {
        processor.configure(AudioProcessor.AudioFormat(rate, channels, encoding))
        processor.flush()
    }

    private fun DoubleArray.tail(seconds: Double, channels: Int = 2) =
        copyOfRange(size - (rate * seconds).toInt() * channels, size)

    private fun DoubleArray.peak() = maxOf { abs(it) }

    private fun DoubleArray.rms() = sqrt(sumOf { it * it } / size)

    private fun db(gain: Double) = 20 * log10(gain)

    @Test
    fun withNothingSetAudioPassesThroughUntouched() {
        for (processor in listOf(TvExoLoudnessProcessor(), TvExoDynamicNormalizer())) {
            configure(processor)
            val input = square(0.3, 0.1)
            val output = run(processor, input)
            assertEquals(input.size, output.size)
            for (k in input.indices) assertEquals(input[k], output[k], 1.0 / 32768)
        }
    }

    @Test
    fun otherAudioPassesThroughInsteadOfFailingTheSink() {
        for (encoding in listOf(C.ENCODING_PCM_24BIT, C.ENCODING_PCM_32BIT, C.ENCODING_E_AC3_JOC)) {
            val processor = TvExoLoudnessProcessor().apply {
                current = TvExoLoudnessProcessor.Settings(gainDb = 6.0, ceilingDb = -1.0)
            }
            assertEquals(
                "encoding $encoding",
                AudioProcessor.AudioFormat.NOT_SET,
                processor.configure(AudioProcessor.AudioFormat(rate, 2, encoding)),
            )
            assertFalse(processor.isActive)
        }
    }

    @Test
    fun loudnessIsOneGainTowardTheTarget() {
        // 标准 for a video measured at -20 LUFS: +6 dB.
        val processor = TvExoLoudnessProcessor().apply {
            current = TvExoLoudnessProcessor.Settings(gainDb = 6.0, ceilingDb = -1.0)
        }
        configure(processor)
        val output = run(processor, square(0.1, 1.0))
        val gain = output.tail(0.5).peak() / 0.1
        assertEquals(6.0, db(gain), 0.05)
    }

    @Test
    fun aCutNeedsNoLimiter() {
        // 高动态 for a video measured at -14 LUFS: -10 dB, at once.
        val processor = TvExoLoudnessProcessor().apply {
            current = TvExoLoudnessProcessor.Settings(gainDb = -10.0, ceilingDb = -1.0)
        }
        configure(processor)
        val output = run(processor, square(0.5, 0.2))
        assertEquals(-10.0, db(output.copyOfRange(0, 96).peak() / 0.5), 0.05)
    }

    @Test
    fun theLimiterHoldsTheCeilingAtOnceAndReleasesIn80Ms() {
        val ceiling = Math.pow(10.0, -1.0 / 20)
        val processor = TvExoLoudnessProcessor().apply {
            current = TvExoLoudnessProcessor.Settings(gainDb = 6.0, ceilingDb = -1.0)
        }
        configure(processor)
        run(processor, square(0.1, 0.5))
        // A loud passage: +6 dB would be 1.2; nothing passes the ceiling,
        // from its first sample.
        val loud = run(processor, square(0.6, 0.5))
        assertTrue("peak ${loud.peak()}", loud.peak() <= ceiling + 1e-3)
        assertEquals(ceiling, loud.peak(), 2e-3)
        // Quiet again: the gain climbs back to +6 dB within the release.
        val quiet = run(processor, square(0.1, 0.5))
        assertTrue(quiet.copyOfRange(0, 2).peak() < 0.16)
        assertEquals(0.2, quiet.copyOfRange((rate * 0.1).toInt() * 2, quiet.size).peak(), 2e-3)
    }

    @Test
    fun aCeilingAboveFullScaleIsFullScale() {
        val settings = TvExoLoudnessProcessor.Settings(gainDb = 0.0, ceilingDb = 3.0)
        assertEquals(1.0, settings.ceiling, 0.0)
        assertEquals(1.0, settings.gain, 1e-12)
    }

    @Test
    fun floatPcmIsBalancedToo() {
        val processor = TvExoLoudnessProcessor().apply {
            current = TvExoLoudnessProcessor.Settings(gainDb = 6.0, ceilingDb = -1.0)
        }
        configure(processor, encoding = C.ENCODING_PCM_FLOAT)
        val output = run(processor, square(0.1, 1.0), encoding = C.ENCODING_PCM_FLOAT)
        assertEquals(6.0, db(output.tail(0.5).peak() / 0.1), 0.01)
    }

    @Test
    fun aNewSettingStartsAfreshOnTheNextBuffer() {
        val processor = TvExoLoudnessProcessor().apply {
            current = TvExoLoudnessProcessor.Settings(gainDb = 6.0, ceilingDb = -1.0)
        }
        configure(processor)
        run(processor, square(0.1, 0.5))
        // The HUD's change, without a flush.
        processor.current = TvExoLoudnessProcessor.Settings(gainDb = -6.0, ceilingDb = -1.0)
        val output = run(processor, square(0.1, 0.2))
        assertEquals(-6.0, db(output.copyOfRange(0, 96).peak() / 0.1), 0.1)
        processor.current = null
        val off = run(processor, square(0.1, 0.1))
        assertEquals(0.1, off.peak(), 1.0 / 32768)
    }

    @Test
    fun theDynamicNormalizerMovesEachFrameTowardTheTargetRms() {
        val processor = TvExoDynamicNormalizer().apply {
            current = TvExoDynamicNormalizer.Settings(
                frameMs = 100,
                window = 1,
                targetRms = 0.2,
                peak = 1.0,
                maxGain = 10.0,
            )
        }
        configure(processor)
        // Quiet: raised fourfold.
        assertEquals(0.2, run(processor, square(0.05, 1.0)).tail(0.3).rms(), 2e-3)
        // Loud: lowered to the same level.
        assertEquals(0.2, run(processor, square(0.8, 1.0)).tail(0.3).rms(), 2e-3)
        // Very quiet: no more than the most gain.
        assertEquals(0.01, run(processor, square(0.001, 1.0)).tail(0.3).rms(), 1e-3)
    }

    @Test
    fun theDynamicGainIsSmoothedOverTheWindow() {
        val processor = TvExoDynamicNormalizer().apply {
            current = TvExoDynamicNormalizer.Settings(
                frameMs = 100,
                window = 5,
                targetRms = 0.2,
                peak = 1.0,
                maxGain = 10.0,
            )
        }
        configure(processor)
        val output = run(processor, square(0.05, 0.25))
        // After one 100 ms frame the gain is a third of the way from 1 to 4.
        val frame2 = output.copyOfRange((rate * 0.15).toInt() * 2, (rate * 0.19).toInt() * 2)
        assertEquals(2.0, frame2.peak() / 0.05, 0.01)
    }

    @Test
    fun theDynamicNormalizerNeverPassesItsPeak() {
        // 动态压缩, upstream's preset.
        val processor = TvExoDynamicNormalizer().apply {
            current = TvExoDynamicNormalizer.Settings(
                frameMs = 250,
                window = 5,
                targetRms = 0.9,
                peak = 0.5,
                maxGain = 10.0,
            )
        }
        configure(processor)
        val output = run(processor, square(0.05, 5.0))
        assertTrue("peak ${output.peak()}", output.peak() <= 0.5 + 1e-3)
        assertTrue("rms ${output.tail(1.0).rms()}", output.tail(1.0).rms() > 0.45)
    }

    @Test
    fun aFlushStartsTheDynamicGainAgain() {
        val processor = TvExoDynamicNormalizer().apply {
            current = TvExoDynamicNormalizer.Settings(
                frameMs = 100,
                window = 1,
                targetRms = 0.2,
                peak = 1.0,
                maxGain = 10.0,
            )
        }
        configure(processor)
        run(processor, square(0.05, 1.0))
        processor.flush()
        val output = run(processor, square(0.05, 0.05))
        // Unity until the first frame is measured.
        assertArrayEquals(square(0.05, 0.05).copyOfRange(0, 8), output.copyOfRange(0, 8), 2.0 / 32768)
    }
}
