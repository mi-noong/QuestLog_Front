package com.example.questlog

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.net.Uri
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val channelName = "questlog/permissions"
    private val notificationServiceChannelName = "questlog/notification_service"
    private val requestCodePostNotifications = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "requestPostNotificationsPermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    if (!granted) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            requestCodePostNotifications
                        )
                    }
                }
                result.success(null)
            } else if (call.method == "openExactAlarmSettings") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val intent = android.content.Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (_: Exception) {
                        // ignore
                    }
                }
                result.success(null)
            } else if (call.method == "canScheduleExactAlarms") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val can = getSystemService(android.app.AlarmManager::class.java)
                            .canScheduleExactAlarms()
                        result.success(can)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            } else if (call.method == "requestIgnoreBatteryOptimizations") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    } catch (e: Exception) {
                        // ignore
                    }
                }
                result.success(null)
            } else if (call.method == "requestBackgroundUsagePermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                        } catch (e2: Exception) {
                            // ignore
                        }
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        
        // 백그라운드 서비스 제어 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationServiceChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startNotificationService" -> {
                    val startHour = call.argument<Int>("startHour") ?: 0
                    val startMinute = call.argument<Int>("startMinute") ?: 0
                    val endHour = call.argument<Int>("endHour") ?: 0
                    val endMinute = call.argument<Int>("endMinute") ?: 0
                    val startTimeText = call.argument<String>("startTimeText") ?: ""
                    val endTimeText = call.argument<String>("endTimeText") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val startMessage = call.argument<String>("startMessage") ?: ""
                    val endMessage = call.argument<String>("endMessage") ?: ""
                    
                    val intent = Intent(this, NotificationService::class.java).apply {
                        putExtra("action", "schedule")
                        putExtra("startHour", startHour)
                        putExtra("startMinute", startMinute)
                        putExtra("endHour", endHour)
                        putExtra("endMinute", endMinute)
                        putExtra("startTimeText", startTimeText)
                        putExtra("endTimeText", endTimeText)
                        putExtra("title", title)
                        putExtra("startMessage", startMessage)
                        putExtra("endMessage", endMessage)
                    }
                    
                    startService(intent)
                    
                    result.success(null)
                }
                "stopNotificationService" -> {
                    val intent = Intent(this, NotificationService::class.java).apply {
                        putExtra("action", "stop")
                    }
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
