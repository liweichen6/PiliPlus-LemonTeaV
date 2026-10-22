package com.example.piliplus

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TvBridge private constructor(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getTvEnvironment" -> {
                val uiModeManager =
                    activity.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val isTelevisionUiMode =
                    uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                val pm = activity.packageManager
                val hasLeanbackFeature = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                val hasTouchscreen = pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
                val smallestScreenWidthDp =
                    activity.resources.configuration.smallestScreenWidthDp
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
                val uiModeManager =
                    activity.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val isTelevisionUiMode =
                    uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                val hasLeanbackFeature =
                    activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                result.success(isTelevisionUiMode || hasLeanbackFeature)
            }

            "showSoftKeyboard" -> {
                val imm =
                    activity.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                val targetView = activity.currentFocus ?: activity.window?.decorView
                if (imm != null && targetView != null) {
                    targetView.post {
                        targetView.requestFocus()
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
                val imm =
                    activity.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                val token = (activity.currentFocus ?: activity.window?.decorView)?.windowToken
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
