package com.example.clawd_pet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager

/**
 * 来电检测 - 电话状态
 */
class CallDetector(private val onStateChanged: (String) -> Unit) {
    private val handler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null

    fun start(context: Context) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.getStringExtra(TelephonyManager.EXTRA_STATE)) {
                    TelephonyManager.EXTRA_STATE_RINGING -> handler.post { onStateChanged("call_incoming") }
                    TelephonyManager.EXTRA_STATE_OFFHOOK -> handler.post { onStateChanged("call_active") }
                    TelephonyManager.EXTRA_STATE_IDLE -> handler.post { onStateChanged("call_ended") }
                }
            }
        }
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        context.registerReceiver(receiver, filter)
    }

    fun stop(context: Context) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}
