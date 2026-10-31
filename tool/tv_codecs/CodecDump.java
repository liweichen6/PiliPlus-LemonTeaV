import android.media.MediaCodecInfo;
import android.media.MediaCodecInfo.CodecCapabilities;
import android.media.MediaCodecInfo.CodecProfileLevel;
import android.media.MediaCodecInfo.VideoCapabilities;
import android.media.MediaCodecInfo.VideoCapabilities.PerformancePoint;
import android.media.MediaCodecList;
import android.util.Range;
import java.util.List;

/**
 * Prints the decoders that android.media.MediaCodecList reports on a device,
 * the same list an app sees. Run through app_process by tool/tv_codecs.sh.
 *
 * Arguments: "all" also lists audio decoders (video only by default).
 */
public class CodecDump {
  private static final int[][] SIZES = {{3840, 2160}, {2560, 1440}, {1920, 1080}, {1280, 720}};

  public static void main(String[] args) {
    boolean all = args.length > 0 && args[0].equals("all");
    for (MediaCodecInfo info : new MediaCodecList(MediaCodecList.ALL_CODECS).getCodecInfos()) {
      if (info.isEncoder()) continue;
      for (String type : info.getSupportedTypes()) {
        if (!all && !type.startsWith("video/")) continue;
        printCodec(info, type);
      }
    }
  }

  private static void printCodec(MediaCodecInfo info, String type) {
    CodecCapabilities caps = info.getCapabilitiesForType(type);
    StringBuilder sb = new StringBuilder();
    sb.append(info.getName()).append(' ').append(type)
        .append(" hw=").append(info.isHardwareAccelerated())
        .append(" sw=").append(info.isSoftwareOnly())
        .append(" vendor=").append(info.isVendor());
    if (info.isAlias()) sb.append(" alias-of=").append(info.getCanonicalName());
    sb.append(" maxInstances=").append(caps.getMaxSupportedInstances())
        .append(" secure=").append(caps.isFeatureSupported(CodecCapabilities.FEATURE_SecurePlayback))
        .append(" tunneled=").append(caps.isFeatureSupported(CodecCapabilities.FEATURE_TunneledPlayback))
        .append(" adaptive=").append(caps.isFeatureSupported(CodecCapabilities.FEATURE_AdaptivePlayback));
    System.out.println(sb);

    VideoCapabilities vc = caps.getVideoCapabilities();
    if (vc != null) {
      System.out.println("  widths=" + vc.getSupportedWidths() + " heights=" + vc.getSupportedHeights()
          + " fps=" + vc.getSupportedFrameRates() + " bitrate=" + vc.getBitrateRange());
      List<PerformancePoint> points = vc.getSupportedPerformancePoints();
      for (int[] size : SIZES) {
        System.out.println("  " + size[0] + "x" + size[1] + ": " + describeSize(vc, points, size[0], size[1]));
      }
      if (points != null && !points.isEmpty()) System.out.println("  performancePoints=" + points);
    }

    StringBuilder levels = new StringBuilder("  profile/level=");
    for (CodecProfileLevel pl : caps.profileLevels) {
      levels.append(pl.profile).append('/').append(pl.level).append(' ');
    }
    System.out.println(levels.toString().trim());
  }

  private static String describeSize(VideoCapabilities vc, List<PerformancePoint> points, int w, int h) {
    if (!vc.isSizeSupported(w, h)) return "unsupported";
    StringBuilder sb = new StringBuilder();
    sb.append("maxFps=").append(Math.round(vc.getSupportedFrameRatesFor(w, h).getUpper()))
        .append(" 60fps=").append(vc.areSizeAndRateSupported(w, h, 60));
    try {
      Range<Double> achievable = vc.getAchievableFrameRatesFor(w, h);
      if (achievable != null) sb.append(" achievable=").append(achievable);
    } catch (IllegalArgumentException e) {
      // Not measured for this size.
    }
    if (points != null) {
      PerformancePoint wanted = new PerformancePoint(w, h, 60);
      boolean covered = false;
      for (PerformancePoint p : points) covered |= p.covers(wanted);
      sb.append(" performancePoint60=").append(covered);
    }
    return sb.toString();
  }
}
