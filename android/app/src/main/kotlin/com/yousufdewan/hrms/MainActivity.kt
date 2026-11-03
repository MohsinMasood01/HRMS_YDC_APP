package com.yousufdewan.hrms

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openBatteryOptimizationSettings" ->
                        result.success(openBatteryOptimizationSettings())
                    else -> result.notImplemented()
                }
            }
    }

    // Opens the system "Battery optimisation" list, where the user picks the
    // app and sets "Don't optimise". Unlike ACTION_REQUEST_IGNORE_BATTERY_
    // OPTIMIZATIONS this needs no permission (Play restricts that one).
    private fun openBatteryOptimizationSettings(): Boolean = try {
        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    companion object {
        private const val BATTERY_CHANNEL = "com.yousufdewan.hrms/battery"
    }
}
