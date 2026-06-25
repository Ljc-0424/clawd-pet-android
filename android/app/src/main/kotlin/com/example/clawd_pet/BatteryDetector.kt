package com.example.clawd_pet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper

/**
 * 电池检测 - 充电/低电量
 */
class BatteryDetector(private val onStateChanged: (String) -> Unit) {
    private val handler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null
    private var isCharging = false
    private var isLowBattery = false

    fun start(context: Context) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL
                    val low = level <= 20

                    if (charging != isCharging) {
                        isCharging = charging
                        handler.post { onStateChanged(if (charging) "charging" else "not_charging") }
                    }
                    if (low != isLowBattery) {
                        isLowBattery = low
                        handler.post { onStateChanged(if (low) "low_battery" else "battery_ok") }
                    }
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        context.registerReceiver(receiver, filter)
    }

    fun stop(context: Context) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}
