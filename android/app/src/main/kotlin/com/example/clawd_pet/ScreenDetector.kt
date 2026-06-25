package com.example.clawd_pet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper

/**
 * 屏幕检测 - 亮屏/息屏
 */
class ScreenDetector(private val onStateChanged: (String) -> Unit) {
    private val handler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null

    fun start(context: Context) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> handler.post { onStateChanged("screen_off") }
                    Intent.ACTION_SCREEN_ON -> handler.post { onStateChanged("screen_on") }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        context.registerReceiver(receiver, filter)
    }

    fun stop(context: Context) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}
