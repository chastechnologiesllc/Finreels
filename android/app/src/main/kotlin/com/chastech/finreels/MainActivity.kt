package com.chastech.finreels

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val installSourceChannel = "com.chastech.finreels/install_source"

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
    }
}
