package com.example.clawd_pet

import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/**
 * 通知检测 - 通过广播监听通知
 * 使用 NotificationListenerService 的替代方案
 */
class NotificationDetector {

    companion object {
        var instance: NotificationDetector? = null
            private set
        var onNotification: ((String) -> Unit)? = null
    }

    private val handler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null

    fun start(context: Context) {
        instance = this
        // 使用通知监听服务的广播机制
        // 当用户在设置中开启通知监听权限后，系统会发送广播
        // 但由于限制，我们改用轮询检测
    }

    fun stop() {
        instance = null
    }

    fun onNotificationPosted(title: String, text: String) {
        val summary = if (title.isNotEmpty()) title else text
        if (summary.isNotEmpty()) {
            handler.post { onNotification?.invoke(summary) }
        }
    }
}
