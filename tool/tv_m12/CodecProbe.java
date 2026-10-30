import android.graphics.ImageFormat;
import android.graphics.SurfaceTexture;
import android.hardware.HardwareBuffer;
import android.media.Image;
import android.media.ImageReader;
import android.media.MediaCodec;
import android.media.MediaCodecList;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.view.Surface;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.ArrayDeque;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicLong;

/**
 * M12 crash-debug harness: decodes a local video with MediaCodec, without mpv,
 * Flutter or an app, at real-time pace and in a loop, and prints counters once
 * a second. Run through app_process by tool/tv_m12/run.sh (pushed by probe.sh).
 *
 * <p>Arguments (key=value):
 *
 * <ul>
 *   <li>file: the video on the device (required).
 *   <li>out: reader (an ImageReader, PRIVATE and GPU-sampled, like mpv's vo=gpu
 *       interop), texture (a SurfaceTexture drawn by GLES into an offscreen
 *       1920x1080 target, like a Flutter texture, so like vo=mediacodec_embed), or
 *       none (ByteBuffer mode). Default reader.
 *   <li>secs: run time, default 20.
 *   <li>images: the reader's maxImages, default 5 (mpv's value).
 *   <li>hold: reader images kept acquired, default 2.
 *   <li>lookahead: decoded frames held behind the oldest one, which is shown only
 *       once they are there (mpv waits for the next frame), default 2.
 *   <li>size: the texture's default buffer size WxH, default the video's size.
 *   <li>codec: decoder name, default the first that claims the format.
 *   <li>vendor: when present, print the decoder's vendor parameters first.
 *   <li>fmt.KEY=VALUE: set KEY in the format the decoder is configured with (an
 *       integer when VALUE is one, else a string), for example
 *       fmt.low-latency=1 or fmt.vendor.mtk-codec2.render-planar=1.
 * </ul>
 */
public class CodecProbe {
  private static final Map<String, String> ARGS = new TreeMap<>();
  private static final AtomicLong acquired = new AtomicLong();
  private static final AtomicLong acquireFailed = new AtomicLong();
  private static final AtomicLong texUpdates = new AtomicLong();
  private static volatile int heldNow;

  public static void main(String[] args) throws Exception {
    for (String a : args) {
      int i = a.indexOf('=');
      if (i > 0) ARGS.put(a.substring(0, i), a.substring(i + 1));
    }
    String file = ARGS.get("file");
    if (file == null) {
      System.out.println("END error: file= missing");
      System.exit(2);
    }
    String out = arg("out", "reader");
    int secs = num("secs", 20);
    int lookahead = num("lookahead", 2);

    // A codec call stuck in the driver must not outlive the run.
    Thread watchdog = new Thread(() -> {
      SystemClock.sleep((secs + 15) * 1000L);
      System.out.println("END watchdog: halting " + (secs + 15) + " s after the start");
      Runtime.getRuntime().halt(3);
    }, "m12-watchdog");
    watchdog.setDaemon(true);
    watchdog.start();

    MediaExtractor extractor = new MediaExtractor();
    extractor.setDataSource(file);
    MediaFormat format = null;
    for (int i = 0; i < extractor.getTrackCount(); i++) {
      MediaFormat f = extractor.getTrackFormat(i);
      if (f.getString(MediaFormat.KEY_MIME).startsWith("video/")) {
        extractor.selectTrack(i);
        format = f;
        break;
      }
    }
    if (format == null) {
      System.out.println("END error: no video track");
      System.exit(2);
    }
    int width = format.getInteger(MediaFormat.KEY_WIDTH);
    int height = format.getInteger(MediaFormat.KEY_HEIGHT);
    float fps = format.containsKey(MediaFormat.KEY_FRAME_RATE)
        ? format.getNumber(MediaFormat.KEY_FRAME_RATE).floatValue() : 60f;
    long frameUs = (long) (1_000_000 / fps);

    HandlerThread outputThread = new HandlerThread("m12-out");
    outputThread.start();
    Handler handler = new Handler(outputThread.getLooper());
    Surface surface = null;
    switch (out) {
      case "reader":
        surface = startReader(width, height, num("images", 5), num("hold", 2), handler);
        break;
      case "texture":
        surface = TextureSink.start(handler, arg("size", width + "x" + height));
        break;
      case "none":
        break;
      default:
        System.out.println("END error: out must be reader, texture or none");
        System.exit(2);
    }

    String name = ARGS.get("codec");
    if (name == null) {
      name = new MediaCodecList(MediaCodecList.REGULAR_CODECS).findDecoderForFormat(format);
    }
    if (name == null) System.out.println("NOTE no decoder claims this format; using the type's default");
    MediaCodec codec = name != null
        ? MediaCodec.createByCodecName(name)
        : MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME));
    System.out.println("START codec=" + codec.getName() + " " + width + "x" + height + " fps=" + fps
        + " args=" + ARGS);
    for (Map.Entry<String, String> e : ARGS.entrySet()) {
      if (!e.getKey().startsWith("fmt.")) continue;
      String key = e.getKey().substring(4);
      try {
        format.setInteger(key, Integer.parseInt(e.getValue()));
      } catch (NumberFormatException notInt) {
        format.setString(key, e.getValue());
      }
    }
    codec.configure(format, surface, null, 0);
    if (ARGS.containsKey("vendor")) printVendorParameters(codec);
    codec.start();

    boolean render = surface != null;
    MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    ArrayDeque<long[]> pending = new ArrayDeque<>();
    long start = SystemClock.elapsedRealtime();
    long end = start + secs * 1000L;
    long nextReport = start + 1000;
    long ptsOffset = 0, maxInputPts = 0, baseWallUs = -1, basePts = 0;
    long decoded = 0, rendered = 0, late = 0, tryAgain = 0, loops = 0, stalls = 0;
    long lastRendered = 0, lastOutput = start;
    int maxIndex = -1;
    boolean stalled = false;
    String result = "ok";
    try {
      while (true) {
        long now = SystemClock.elapsedRealtime();
        if (now >= end) break;
        boolean busy = false;

        int in = codec.dequeueInputBuffer(0);
        if (in >= 0) {
          ByteBuffer buffer = codec.getInputBuffer(in);
          int size = extractor.readSampleData(buffer, 0);
          if (size < 0) {
            extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
            loops++;
            ptsOffset = maxInputPts + frameUs - extractor.getSampleTime();
            size = extractor.readSampleData(buffer, 0);
          }
          long pts = extractor.getSampleTime() + ptsOffset;
          maxInputPts = Math.max(maxInputPts, pts);
          int flags = (extractor.getSampleFlags() & MediaExtractor.SAMPLE_FLAG_SYNC) != 0
              ? MediaCodec.BUFFER_FLAG_KEY_FRAME : 0;
          codec.queueInputBuffer(in, 0, size, pts, flags);
          extractor.advance();
          busy = true;
        }

        if (pending.size() <= lookahead) {
          int index = codec.dequeueOutputBuffer(info, 2000);
          if (index >= 0) {
            decoded++;
            maxIndex = Math.max(maxIndex, index);
            lastOutput = now;
            pending.addLast(new long[] {index, info.presentationTimeUs});
            busy = true;
          } else if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
            tryAgain++;
          } else if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            System.out.println("FORMAT " + codec.getOutputFormat());
          }
        }

        // The oldest frame is shown at its time, once `lookahead` newer ones are decoded.
        while (pending.size() > lookahead) {
          long[] frame = pending.peekFirst();
          long nowUs = SystemClock.elapsedRealtimeNanos() / 1000;
          if (baseWallUs < 0) {
            baseWallUs = nowUs;
            basePts = frame[1];
          }
          long due = baseWallUs + (frame[1] - basePts);
          if (due > nowUs + 1000) break;
          if (nowUs - due > frameUs) late++;
          codec.releaseOutputBuffer((int) frame[0], render);
          pending.removeFirst();
          rendered++;
          busy = true;
        }

        if (!stalled && now - lastOutput > 3000) {
          stalled = true;
          stalls++;
          System.out.printf("STALL at %.1f s: no decoder output for 3 s; pending=%d held=%d buffers=%d%n",
              (now - start) / 1000.0, pending.size(), heldNow, maxIndex + 1);
        } else if (stalled && lastOutput == now) {
          stalled = false;
          System.out.printf("RESUME at %.1f s%n", (now - start) / 1000.0);
        }

        if (now >= nextReport) {
          System.out.printf("t=%d dec=%d ren=%d fps=%d late=%d try=%d acq=%d acqfail=%d tex=%d pend=%d held=%d"
                  + " buffers=%d loops=%d%n",
              (now - start) / 1000, decoded, rendered, rendered - lastRendered, late, tryAgain,
              acquired.get(), acquireFailed.get(), texUpdates.get(), pending.size(), heldNow, maxIndex + 1,
              loops);
          lastRendered = rendered;
          nextReport += 1000;
        }
        if (!busy) SystemClock.sleep(1);
      }
      if (stalled) result = "stalled";
    } catch (Exception e) {
      result = "error " + e;
    } finally {
      System.out.printf("END %s: %.1f s, decoded=%d rendered=%d late=%d stalls=%d buffers=%d loops=%d%n", result,
          (SystemClock.elapsedRealtime() - start) / 1000.0, decoded, rendered, late, stalls, maxIndex + 1, loops);
    }
    codec.stop();
    codec.release();
    System.exit(0);
  }

  /** The decoder's vendor parameters (MediaCodec.getSupportedVendorParameters) and their types. */
  private static void printVendorParameters(MediaCodec codec) {
    for (String name : codec.getSupportedVendorParameters()) {
      MediaCodec.ParameterDescriptor descriptor = codec.getParameterDescriptor(name);
      System.out.println("VENDOR " + name + " type=" + (descriptor == null ? "?" : descriptor.getType()));
    }
  }

  /** An ImageReader that keeps the newest `hold` images acquired, as mpv's interop does. */
  private static Surface startReader(int width, int height, int images, int hold, Handler handler) {
    if (hold >= images) {
      System.out.println("END error: hold must be smaller than images");
      System.exit(2);
    }
    ImageReader reader = ImageReader.newInstance(width, height, ImageFormat.PRIVATE, images,
        HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE);
    ArrayDeque<Image> held = new ArrayDeque<>();
    reader.setOnImageAvailableListener(r -> {
      Image image;
      try {
        image = r.acquireNextImage();
      } catch (IllegalStateException e) {
        acquireFailed.incrementAndGet();
        return;
      }
      if (image == null) return;
      acquired.incrementAndGet();
      held.addLast(image);
      while (held.size() > hold) held.removeFirst().close();
      heldNow = held.size();
    }, handler);
    return reader.getSurface();
  }

  /** A SurfaceTexture drawn into an offscreen 1920x1080 GLES target on each new frame. */
  private static final class TextureSink {
    private static final String VERTEX =
        "attribute vec2 p; varying vec2 t; void main() { t = (p + 1.0) * 0.5; gl_Position = vec4(p, 0.0, 1.0); }";
    private static final String FRAGMENT = "#extension GL_OES_EGL_image_external : require\n"
        + "precision mediump float; uniform samplerExternalOES s; varying vec2 t;"
        + " void main() { gl_FragColor = texture2D(s, t); }";

    private SurfaceTexture texture;
    private int program;
    private FloatBuffer quad;

    static Surface start(Handler handler, String size) throws InterruptedException {
      Surface[] surface = new Surface[1];
      CountDownLatch ready = new CountDownLatch(1);
      handler.post(() -> {
        surface[0] = new TextureSink().init(handler, size);
        ready.countDown();
      });
      ready.await();
      return surface[0];
    }

    private Surface init(Handler handler, String size) {
      EGLDisplay display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
      int[] version = new int[2];
      EGL14.eglInitialize(display, version, 0, version, 1);
      int[] attributes = {EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
          EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
          EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE};
      EGLConfig[] configs = new EGLConfig[1];
      int[] count = new int[1];
      EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0);
      EGLContext context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
          new int[] {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE}, 0);
      EGLSurface pbuffer = EGL14.eglCreatePbufferSurface(display, configs[0],
          new int[] {EGL14.EGL_WIDTH, 1920, EGL14.EGL_HEIGHT, 1080, EGL14.EGL_NONE}, 0);
      EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context);

      int[] name = new int[1];
      GLES20.glGenTextures(1, name, 0);
      GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, name[0]);
      GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
      GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
      program = GLES20.glCreateProgram();
      GLES20.glAttachShader(program, shader(GLES20.GL_VERTEX_SHADER, VERTEX));
      GLES20.glAttachShader(program, shader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT));
      GLES20.glLinkProgram(program);
      quad = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
      quad.put(new float[] {-1, -1, 1, -1, -1, 1, 1, 1}).position(0);

      texture = new SurfaceTexture(name[0]);
      String[] wh = size.split("x");
      texture.setDefaultBufferSize(Integer.parseInt(wh[0]), Integer.parseInt(wh[1]));
      texture.setOnFrameAvailableListener(st -> draw(), handler);
      return new Surface(texture);
    }

    private void draw() {
      texture.updateTexImage();
      GLES20.glViewport(0, 0, 1920, 1080);
      GLES20.glUseProgram(program);
      int position = GLES20.glGetAttribLocation(program, "p");
      GLES20.glEnableVertexAttribArray(position);
      GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, quad);
      GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
      GLES20.glFinish();
      texUpdates.incrementAndGet();
    }

    private static int shader(int type, String source) {
      int shader = GLES20.glCreateShader(type);
      GLES20.glShaderSource(shader, source);
      GLES20.glCompileShader(shader);
      int[] ok = new int[1];
      GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, ok, 0);
      if (ok[0] == 0) System.out.println("NOTE shader: " + GLES20.glGetShaderInfoLog(shader));
      return shader;
    }
  }

  private static String arg(String key, String fallback) {
    return ARGS.getOrDefault(key, fallback);
  }

  private static int num(String key, int fallback) {
    return Integer.parseInt(arg(key, Integer.toString(fallback)));
  }
}
