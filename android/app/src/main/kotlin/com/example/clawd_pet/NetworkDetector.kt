package com.example.clawd_pet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper

/**
 * 网络检测 - WiFi/移动数据连接状态
 */
class NetworkDetector(private val onStateChanged: (String) -> Unit) {
    private val handler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null
    private var wasConnected = true

    fun start(context: Context) {
        // 初始状态
        wasConnected = isNetworkAvailable(context)

        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val connected = isNetworkAvailable(ctx ?: return)
                if (connected != wasConnected) {
                    wasConnected = connected
                    handler.post {
                        onStateChanged(if (connected) "network_ok" else "network_lost")
                    }
                }
            }
        }
        val filter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION)
        context.registerReceiver(receiver, filter)
    }

    fun stop(context: Context) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
    }
}
