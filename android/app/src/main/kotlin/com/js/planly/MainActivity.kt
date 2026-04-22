package com.js.planly

import android.app.AlarmManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "planly/device_controls"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			channelName
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getBatteryOptimizationStatus" -> {
					result.success(getBatteryOptimizationStatus())
				}

				"openBatteryOptimizationSettings" -> {
					result.success(openBatteryOptimizationSettings())
				}

				"openAutoStartSettings" -> {
					result.success(openAutoStartSettings())
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun getBatteryOptimizationStatus(): Map<String, Any> {
		val powerManager = getSystemService(POWER_SERVICE) as PowerManager
		val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager

		val isIgnoringOptimizations =
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				powerManager.isIgnoringBatteryOptimizations(packageName)
			} else {
				true
			}

		val isPowerSaveModeEnabled =
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
				powerManager.isPowerSaveMode
			} else {
				false
			}

		val canScheduleExactAlarms =
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
				alarmManager.canScheduleExactAlarms()
			} else {
				true
			}

		return mapOf(
			"isIgnoringBatteryOptimizations" to isIgnoringOptimizations,
			"isPowerSaveModeEnabled" to isPowerSaveModeEnabled,
			"canScheduleExactAlarms" to canScheduleExactAlarms,
			"manufacturer" to Build.MANUFACTURER,
			"brand" to Build.BRAND,
			"model" to Build.MODEL,
		)
	}

	private fun openBatteryOptimizationSettings(): Boolean {
		val intents = mutableListOf<Intent>()

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			intents.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
		}

		intents.add(
			Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
				data = Uri.parse("package:$packageName")
			}
		)

		return launchFirstAvailableIntent(intents)
	}

	private fun openAutoStartSettings(): Boolean {
		val candidates = listOf(
			Intent().setComponent(
				ComponentName(
					"com.vivo.permissionmanager",
					"com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
				)
			),
			Intent().setComponent(
				ComponentName(
					"com.iqoo.secure",
					"com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
				)
			),
			Intent().setComponent(
				ComponentName(
					"com.iqoo.secure",
					"com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
				)
			),
			Intent().setComponent(
				ComponentName(
					"com.vivo.permissionmanager",
					"com.vivo.permissionmanager.activity.PurviewTabActivity"
				)
			),
			Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
				data = Uri.parse("package:$packageName")
			}
		)

		return launchFirstAvailableIntent(candidates)
	}

	private fun launchFirstAvailableIntent(candidates: List<Intent>): Boolean {
		for (intent in candidates) {
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			val canResolve = intent.resolveActivity(packageManager) != null
			if (!canResolve) continue

			try {
				startActivity(intent)
				return true
			} catch (_: Exception) {
			}
		}

		return false
	}
}
