package com.example.clawd_pet

import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.clawd_pet/floating"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "showOverlay" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")))
                        result.error("PERMISSION_DENIED", "需要悬浮窗权限", null)
                    } else {
                        val args = call.arguments as? Map<*, *>
                        val host = args?.get("host") as? String ?: ""
                        val port = (args?.get("port") as? Number)?.toInt() ?: 0
                        getSharedPreferences("clawd_prefs", MODE_PRIVATE).edit()
                            .putString("ws_host", host).putInt("ws_port", port).apply()
                        startService(Intent(this, FloatingPetService::class.java))
                        result.success(true)
                    }
                }
                "hideOverlay" -> {
                    stopService(Intent(this, FloatingPetService::class.java))
                    result.success(true)
                }
                "updateState" -> {
                    val state = call.arguments as? String ?: "idle"
                    FloatingPetService.updateState(state)
                    result.success(true)
                }
                "forceState" -> {
                    val state = call.arguments as? String ?: "idle"
                    FloatingPetService.forceState(state)
                    result.success(true)
                }
                "resizeOverlay" -> {
                    val size = call.arguments as? Int ?: 150
                    FloatingPetService.resize(size)
                    result.success(true)
                }
                "updateAnimConfig" -> {
                    val json = call.arguments as? String ?: "{}"
                    getSharedPreferences("clawd_prefs", MODE_PRIVATE).edit()
                        .putString("anim_config", json).apply()
                    FloatingPetService.updateAnimConfig(json)
                    result.success(true)
                }
                "bindVpnNetwork" -> {
                    // 将 app 的所有 socket 绑定到 VPN（ZeroTier）网络
                    val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                    val networks = cm.allNetworks
                    var vpnNetwork: Network? = null
                    for (n in networks) {
                        val caps = cm.getNetworkCapabilities(n) ?: continue
                        // VPN 网络的 transport 类型包含 TRANSPORT_VPN
                        if (caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_VPN)) {
                            vpnNetwork = n; break
                        }
                    }
                    if (vpnNetwork != null) {
                        val ok = cm.bindProcessToNetwork(vpnNetwork)
                        android.util.Log.d("MainActivity", "绑定 VPN 网络: $ok")
                        result.success(ok)
                    } else {
                        android.util.Log.d("MainActivity", "未找到 VPN 网络")
                        result.success(false)
                    }
                }
                "unbindNetwork" -> {
                    // 恢复默认网络路由
                    val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                    cm.bindProcessToNetwork(null)
                    android.util.Log.d("MainActivity", "已恢复默认网络")
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")))
                    result.success(true)
                }
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")))
                    result.success(true)
                }
                "checkPermissions" -> {
                    val overlayOk = Settings.canDrawOverlays(this)
                    val am = getSystemService(ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
                    val enabledServices = am.getEnabledAccessibilityServiceList(
                        android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC)
                    val accessibilityOk = enabledServices.any {
                        it.resolveInfo.serviceInfo.packageName == packageName
                    }
                    result.success(mapOf("overlay" to overlayOk, "accessibility" to accessibilityOk))
                }
                else -> result.notImplemented()
            }
        }
    }
}
