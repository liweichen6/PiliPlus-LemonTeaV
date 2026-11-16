package com.example.piliplus

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Audio normalization on ExoPlayer (M17.6, decision 13): two audio processors
 * on decoded PCM, in place of mpv's `loudnorm` and `dynaudnorm` filters.
 * Passthrough tracks (杜比全景声, E-AC-3) never reach a processor, so they
 * aren't normalized.
 *
 * Adapted from loneshu7/PiliPlusPlus (GPL-3.0), commit 5bdf4bfd6,
 * `AudioNormalizationProcessor.kt`: the PCM handling, the RMS window and the
 * limiter with an instant attack and a linear release. Its filters and
 * equalizer aren't taken.
 *
 * Both processors stay in the sink's chain for the player's life and pass
 * audio through untouched until Dart configures them, so the preset can
 * change without rebuilding the player.
 */
@OptIn(UnstableApi::class)
abstract class TvExoNormalizer : BaseAudioProcessor() {
    private var limiterGain = 1.0
    private var applied: Any? = null

    /** The settings now in force, or null to pass audio through. */
    protected abstract val settings: Any?

    /** The ceiling for the limiter, as a linear sample peak. */
    protected abstract fun ceiling(settings: Any): Double

    /** The gain wanted for the next frame, before the limiter. */
    protected abstract fun frameGain(settings: Any, frame: DoubleArray, channels: Int, sampleRate: Int): Double

    /** Called when the settings change or the stream is flushed. */
    protected open fun resetState(settings: Any?) {}

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT &&
            inputAudioFormat.encoding != C.ENCODING_PCM_FLOAT
        ) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        return inputAudioFormat
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        if (!inputBuffer.hasRemaining()) return
        val output = replaceOutputBuffer(inputBuffer.remaining()).order(inputBuffer.order())
        val current = settings
        if (current !== applied) reset(current)
        if (current == null) {
            output.put(inputBuffer)
            output.flip()
            return
        }
        val channels = inputAudioFormat.channelCount
        val sampleRate = inputAudioFormat.sampleRate
        val float = inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT
        val frame = DoubleArray(channels)
        val ceiling = ceiling(current)
        val release = RELEASE_PER_SECOND / sampleRate
        while (inputBuffer.remaining() >= channels * (if (float) 4 else 2)) {
            var peak = 0.0
            for (c in 0 until channels) {
                frame[c] = if (float) inputBuffer.float.toDouble() else inputBuffer.short / 32768.0
                peak = maxOf(peak, abs(frame[c]))
            }
            val wanted = frameGain(current, frame, channels, sampleRate)
            val limited = if (peak == 0.0) wanted else min(wanted, ceiling / peak)
            limiterGain = if (limited < limiterGain) limited else min(limited, limiterGain + release)
            for (c in 0 until channels) {
                val sample = frame[c] * limiterGain
                if (float) {
                    output.putFloat(sample.toFloat())
                } else {
                    output.putShort((sample * 32767.0).toInt().coerceIn(-32768, 32767).toShort())
                }
            }
        }
        output.flip()
    }

    override fun onFlush() = reset(settings)

    override fun onReset() = reset(settings)

    private fun reset(current: Any?) {
        applied = current
        limiterGain = 1.0
        resetState(current)
    }

    private companion object {
        // loneshu7's release: back to unity gain in 0.08 s.
        const val RELEASE_PER_SECOND = 1.0 / 0.08
    }
}

/**
 * 预设 loudnorm: one gain for the whole video, from the loudness Bilibili
 * measured (`Volume`: target minus measured integrated loudness), and a
 * limiter at the preset's true-peak target. The limiter reads sample peaks,
 * not oversampled true peaks, so it can let an inter-sample peak through.
 */
class TvExoLoudnessProcessor : TvExoNormalizer() {
    data class Settings(val gainDb: Double, val ceilingDb: Double) {
        val gain: Double = 10.0.pow(gainDb / 20.0)
        val ceiling: Double = 10.0.pow(ceilingDb / 20.0).coerceAtMost(1.0)
    }

    @Volatile
    var current: Settings? = null

    override val settings: Any? get() = current

    override fun ceiling(settings: Any) = (settings as Settings).ceiling

    override fun frameGain(settings: Any, frame: DoubleArray, channels: Int, sampleRate: Int) =
        (settings as Settings).gain
}

/**
 * 预设 dynaudnorm (`dynaudnorm=g=5:f=250:r=0.9:p=0.5`): a gain per frame of
 * [Settings.frameMs], toward [Settings.targetRms] and at most
 * [Settings.maxGain], smoothed over about [Settings.window] frames, and a
 * limiter at [Settings.peak]. ffmpeg smooths with a Gaussian over `g` frames;
 * this smooths exponentially over the same span, as loneshu7 does.
 */
class TvExoDynamicNormalizer : TvExoNormalizer() {
    data class Settings(
        val frameMs: Int,
        val window: Int,
        val targetRms: Double,
        val peak: Double,
        val maxGain: Double,
    )

    @Volatile
    var current: Settings? = null

    override val settings: Any? get() = current

    private var gain = 1.0
    private var sumSquares = 0.0
    private var frames = 0

    override fun resetState(settings: Any?) {
        gain = 1.0
        sumSquares = 0.0
        frames = 0
    }

    override fun ceiling(settings: Any) = (settings as Settings).peak.coerceIn(0.0, 1.0)

    override fun frameGain(settings: Any, frame: DoubleArray, channels: Int, sampleRate: Int): Double {
        val s = settings as Settings
        for (c in 0 until channels) sumSquares += frame[c] * frame[c]
        frames++
        if (frames >= maxOf(1, s.frameMs * sampleRate / 1000)) {
            val rms = sqrt(sumSquares / (frames * channels))
            val wanted = if (rms > 0) (s.targetRms / rms).coerceIn(MIN_GAIN, s.maxGain) else s.maxGain
            gain += (wanted - gain) * (2.0 / (maxOf(1, s.window) + 1))
            sumSquares = 0.0
            frames = 0
        }
        return gain
    }

    private companion object {
        const val MIN_GAIN = 0.01
    }
}
