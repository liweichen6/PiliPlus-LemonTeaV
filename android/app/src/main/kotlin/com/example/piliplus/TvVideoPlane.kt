package com.example.piliplus

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * A real SurfaceView for mpv's vo=mediacodec_embed, so the decoder goes straight
 * to the TV's video plane and the GPU stays out of the path.
 *
 * Kotlin only owns the surface and its global reference. Dart decides when mpv
 * attaches to it, and it can't answer before surfaceDestroyed returns, so mpv
 * sees the surface go for a moment. The reference outlives it by 5 s, as in
 * media_kit's VideoOutput.
 */
class TvVideoPlane private constructor(
    private val channel: MethodChannel,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val handler = Handler(Looper.getMainLooper())

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        PlaneView(context)

    private inner class PlaneView(context: Context) : PlatformView, SurfaceHolder.Callback {
        // The surface reference mpv may hold, 0 while there is none.
        private var wid = 0L

        private val surfaceView = SurfaceView(context).apply {
            // D-pad focus stays in Flutter.
            isFocusable = false
            isFocusableInTouchMode = false
            holder.addCallback(this@PlaneView)
        }

        override fun getView(): View = surfaceView

        override fun surfaceCreated(holder: SurfaceHolder) {
            wid = MediaKitAndroidHelper.newGlobalObjectRef(holder.surface)
            channel.invokeMethod("surfaceReady", mapOf("wid" to wid))
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            release()
        }

        override fun dispose() {
            surfaceView.holder.removeCallback(this)
            release()
        }

        private fun release() {
            val ref = wid
            if (ref == 0L) return
            wid = 0L
            channel.invokeMethod("surfaceLost", mapOf("wid" to ref))
            handler.postDelayed({ MediaKitAndroidHelper.deleteGlobalObjectRef(ref) }, 5000)
        }
    }

    companion object {
        private const val VIEW_TYPE = "com.example.piliplus/tv_video_plane"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.platformViewsController.registry.registerViewFactory(
                VIEW_TYPE,
                TvVideoPlane(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIEW_TYPE)),
            )
        }
    }
}
