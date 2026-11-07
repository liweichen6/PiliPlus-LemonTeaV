package com.example.piliplus

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import java.lang.ref.WeakReference

class TvBridge private constructor(
    activity: Activity,
) : MethodChannel.MethodCallHandler {
    private val activityRef = WeakReference(activity)
    private val activity: Activity? get() = activityRef.get()
    private var imeProxy: ImeProxyView? = null

    /**
     * Gives Android focus to [ImeProxyView] in place of [flutterView], adding
     * the proxy to the activity's content the first time.
     */
    private fun focusImeProxy(act: Activity, flutterView: View): View {
        val proxy = imeProxy?.takeIf { it.context === act } ?: ImeProxyView(act).also {
            imeProxy?.let { old -> (old.parent as? ViewGroup)?.removeView(old) }
            imeProxy = it
        }
        proxy.target = flutterView
        if (proxy.parent == null) {
            val content = act.findViewById<ViewGroup>(android.R.id.content)
            content?.addView(proxy, ViewGroup.LayoutParams(1, 1))
        }
        if (proxy.parent != null && !proxy.hasFocus()) {
            proxy.requestFocus()
        }
        return if (proxy.hasFocus()) proxy else flutterView
    }

    /** Puts Android focus back on the Flutter view if the proxy has it. */
    private fun releaseImeProxy() {
        val proxy = imeProxy ?: return
        if (proxy.hasFocus()) {
            proxy.target?.requestFocus()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getTvEnvironment" -> {
                val act = activity
                if (act == null) {
                    result.success(
                        mapOf(
                            "isTelevision" to false,
                            "isTelevisionUiMode" to false,
                            "hasLeanbackFeature" to false,
                            "hasTouchscreen" to true,
                            "smallestScreenWidthDp" to 0,
                        ),
                    )
                    return
                }
                val uiModeManager =
                    act.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val isTelevisionUiMode =
                    uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                val pm = act.packageManager
                val hasLeanbackFeature = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                val hasTouchscreen = pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
                val smallestScreenWidthDp =
                    act.resources.configuration.smallestScreenWidthDp
                result.success(
                    mapOf(
                        "isTelevision" to (isTelevisionUiMode || hasLeanbackFeature),
                        "isTelevisionUiMode" to isTelevisionUiMode,
                        "hasLeanbackFeature" to hasLeanbackFeature,
                        "hasTouchscreen" to hasTouchscreen,
                        "smallestScreenWidthDp" to smallestScreenWidthDp,
                    ),
                )
            }

            "isTelevision" -> {
                val act = activity
                if (act == null) {
                    result.success(false)
                    return
                }
                val uiModeManager =
                    act.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val isTelevisionUiMode =
                    uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                val hasLeanbackFeature =
                    act.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                result.success(isTelevisionUiMode || hasLeanbackFeature)
            }

            "showSoftKeyboard" -> {
                val act = activity
                val imm =
                    act?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                // The proxy only stands in for the Flutter view itself: a view
                // above it (the decor view) would send its keys back to it.
                val flutterView = act?.findViewById<View>(FlutterActivity.FLUTTER_VIEW_ID)
                val anchor = flutterView
                    ?: act?.currentFocus?.takeIf { it !is ImeProxyView }
                    ?: act?.window?.decorView
                if (imm != null && act != null && anchor != null) {
                    anchor.post {
                        // Some TVs set config_preventImeStartupUnlessTextEditor:
                        // Android then won't start a keyboard session for a
                        // focused view that isn't a text editor, and the Flutter
                        // view isn't one. The keyboard is still drawn by the
                        // show below, but the app isn't bound to it, so the
                        // remote's keys never reach it and the D-pad moves the
                        // app's focus instead. The proxy is a text editor that
                        // hands everything else to the Flutter view.
                        val targetView = if (flutterView != null) {
                            focusImeProxy(act, flutterView)
                        } else {
                            anchor.also { it.requestFocus() }
                        }
                        val shown = imm.showSoftInput(targetView, InputMethodManager.SHOW_IMPLICIT)
                        if (!shown) {
                            @Suppress("DEPRECATION")
                            imm.toggleSoftInput(
                                InputMethodManager.SHOW_FORCED,
                                InputMethodManager.HIDE_IMPLICIT_ONLY,
                            )
                        }
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "hideSoftKeyboard" -> {
                val act = activity
                val imm =
                    act?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                releaseImeProxy()
                val token = (act?.currentFocus ?: act?.window?.decorView)?.windowToken
                if (imm != null && token != null) {
                    imm.hideSoftInputFromWindow(token, 0)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.example.piliplus/tv"

        fun register(flutterEngine: FlutterEngine, activity: Activity) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL_NAME,
            ).setMethodCallHandler(TvBridge(activity))
        }
    }
}

/**
 * Stands in for the Flutter view as Android's focused view while the soft
 * keyboard is open (see "showSoftKeyboard"). It reports itself as a text
 * editor, and passes the input connection, Flutter's own input-method calls
 * (through [checkInputConnectionProxy]) and every key the keyboard doesn't
 * take to [target]. It's 1 x 1, draws nothing and keeps focus on itself, so
 * leftover D-pad keys don't move Android focus.
 */
private class ImeProxyView(context: Context) : View(context) {
    var target: View? = null

    init {
        id = generateViewId()
        isFocusable = true
        isFocusableInTouchMode = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO
        }
        nextFocusUpId = id
        nextFocusDownId = id
        nextFocusLeftId = id
        nextFocusRightId = id
        nextFocusForwardId = id
    }

    override fun onCheckIsTextEditor(): Boolean = target != null

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? =
        target?.onCreateInputConnection(outAttrs)

    override fun checkInputConnectionProxy(view: View?): Boolean =
        (view != null && view === target) || super.checkInputConnectionProxy(view)

    override fun dispatchKeyEvent(event: KeyEvent): Boolean =
        target?.dispatchKeyEvent(event) ?: super.dispatchKeyEvent(event)
}
