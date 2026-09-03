package com.chastechgroup.rumuo

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val installSourceChannel = "com.chastechgroup.rumuo/install_source"
    private val nativeLaunchChannel = "com.chastechgroup.rumuo/native_launch"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var nativeLaunchView: View? = null
    private val removeNativeLaunch = Runnable { hideNativeLaunch() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showNativeLaunch()
    }

    private fun showNativeLaunch() {
        val root = findViewById<FrameLayout>(android.R.id.content)
        if (root == null || nativeLaunchView != null) return
        nativeLaunchView = LayoutInflater.from(this)
            .inflate(com.chastechgroup.rumuo.R.layout.native_launch_screen, root, false)
        root.addView(nativeLaunchView,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT))
        mainHandler.postDelayed(removeNativeLaunch, 6000L)
    }

    private fun hideNativeLaunch() {
        nativeLaunchView?.let { view ->
            (view.parent as? FrameLayout)?.removeView(view)
        }
        nativeLaunchView = null
        mainHandler.removeCallbacks(removeNativeLaunch)
    }

    override fun onDestroy() {
        hideNativeLaunch()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Lets the Dart side (InstallSourceService) tell a Play Store
        // install apart from a sideloaded APK, so it can choose between
        // Google Play Billing and the Paystack fallback for purchases.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installSourceChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstallerPackageName") {
                    try {
                        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            packageManager.getInstallSourceInfo(packageName).installingPackageName
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getInstallerPackageName(packageName)
                        }
                        result.success(installer)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeLaunchChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    hideNativeLaunch()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
