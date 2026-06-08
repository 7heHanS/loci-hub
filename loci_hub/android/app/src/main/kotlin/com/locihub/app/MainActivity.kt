package com.locihub.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, 
            "com.locihub.app/app_control"
        ).setMethodCallHandler { call, result ->
            if (call.method == "openEdgeGallery") {
                val launchIntent = packageManager.getLaunchIntentForPackage("com.google.ai.edge.gallery")
                if (launchIntent != null) {
                    startActivity(launchIntent)
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Google AI Edge Gallery 앱이 설치되어 있지 않습니다.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "LociHub 위치 추적"
            val descriptionText = "LociHub 위치 추적 백그라운드 서비스 알림"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel("loci_hub_tracking", name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
