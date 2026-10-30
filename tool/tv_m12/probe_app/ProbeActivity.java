package m12;

import android.app.Activity;
import android.graphics.SurfaceTexture;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.TextureView;
import android.view.WindowManager;

/**
 * M12 probe app: shows CodecProbe's decoder output on screen, either through a TextureView (drawn by
 * the GPU into the app's window, as Flutter draws mpv's texture) or a SurfaceView (its own layer, as
 * ExoPlayer would in option F). The player is CodecProbe, or the system's MediaPlayer (player=media),
 * which has its own audio, A/V sync and frame dropping, and is what MiXplorer plays with. Started by
 * tool/tv_m12/run.sh with string extras: view=texture|surface, player=media, plus CodecProbe's arguments
 * (file, secs, lookahead, audio, drop, second, ...). Finishes itself when the run ends.
 */
public class ProbeActivity extends Activity {
  @Override
  protected void onCreate(Bundle state) {
    super.onCreate(state);
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    Bundle extras = getIntent().getExtras();
    if (extras != null) {
      for (String key : extras.keySet()) CodecProbe.ARGS.put(key, String.valueOf(extras.get(key)));
    }
    if ("texture".equals(CodecProbe.ARGS.get("view"))) {
      TextureView view = new TextureView(this);
      view.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
        @Override
        public void onSurfaceTextureAvailable(SurfaceTexture texture, int width, int height) {
          start(new Surface(texture));
        }

        @Override
        public void onSurfaceTextureSizeChanged(SurfaceTexture texture, int width, int height) {}

        @Override
        public boolean onSurfaceTextureDestroyed(SurfaceTexture texture) {
          return true;
        }

        @Override
        public void onSurfaceTextureUpdated(SurfaceTexture texture) {}
      });
      setContentView(view);
    } else {
      SurfaceView view = new SurfaceView(this);
      view.getHolder().addCallback(new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(SurfaceHolder holder) {
          start(holder.getSurface());
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {}

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {}
      });
      setContentView(view);
    }
  }

  private void start(Surface surface) {
    new Thread(() -> {
      try {
        if ("media".equals(CodecProbe.ARGS.get("player"))) {
          playWithMediaPlayer(surface);
        } else {
          CodecProbe.decode(surface);
        }
      } catch (Exception e) {
        System.out.println("END error " + e);
      }
      runOnUiThread(this::finish);
    }, "m12-decode").start();
  }

  /** Plays file= in a loop for secs= seconds, printing the position once a second. */
  private void playWithMediaPlayer(Surface surface) throws Exception {
    int secs = Integer.parseInt(CodecProbe.ARGS.getOrDefault("secs", "20"));
    MediaPlayer player = new MediaPlayer();
    player.setOnErrorListener((mp, what, extra) -> {
      System.out.println("STALL MediaPlayer error " + what + " " + extra);
      return true;
    });
    player.setDataSource(CodecProbe.ARGS.get("file"));
    player.setSurface(surface);
    player.setLooping(true);
    player.prepare();
    player.start();
    long start = SystemClock.elapsedRealtime();
    System.out.println("START MediaPlayer " + player.getVideoWidth() + "x" + player.getVideoHeight()
        + " args=" + CodecProbe.ARGS);
    if (CodecProbe.ARGS.containsKey("second")) CodecProbe.startSecondDecoder();
    for (int t = 1; t <= secs; t++) {
      SystemClock.sleep(start + t * 1000L - SystemClock.elapsedRealtime());
      System.out.println("t=" + t + " pos=" + player.getCurrentPosition() + " playing=" + player.isPlaying());
    }
    player.stop();
    player.release();
    System.out.println("END ok: " + secs + " s");
  }
}
