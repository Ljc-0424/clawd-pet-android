package com.example.clawd_pet

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

/**
 * 打字 + 通知检测 - 通过无障碍服务监听
 * 修复：焦点切换时也重置打字状态
 */
class TypingDetector : AccessibilityService() {

    companion object {
        var instance: TypingDetector? = null
            private set
        var onTypingChanged: ((Boolean) -> Unit)? = null
        var onNotification: ((String) -> Unit)? = null
    }

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var typingTimeout: Runnable? = null
    private var safetyTimeout: Runnable? = null
    private var isTyping = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_FOCUSED or
                    AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> {
                if (!isTyping) {
                    isTyping = true
                    onTypingChanged?.invoke(true)
                }
                // 每次输入重置超时
                typingTimeout?.let { handler.removeCallbacks(it) }
                typingTimeout = Runnable {
                    typingTimeout = null
                    if (isTyping) {
                        isTyping = false
                        onTypingChanged?.invoke(false)
                    }
                }
                handler.postDelayed(typingTimeout!!, 2000)
                // 安全超时：10 秒无输入强制重置
                safetyTimeout?.let { handler.removeCallbacks(it) }
                safetyTimeout = Runnable {
                    safetyTimeout = null
                    if (isTyping) {
                        isTyping = false; onTypingChanged?.invoke(false)
                    }
                }
                handler.postDelayed(safetyTimeout!!, 10000)
            }
            // 焦点变化/窗口切换 → 立即结束打字状态
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (isTyping) {
                    typingTimeout?.let { handler.removeCallbacks(it) }
                    typingTimeout = null
                    isTyping = false
                    onTypingChanged?.invoke(false)
                }
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                val text = event.text?.joinToString(" ") ?: ""
                if (text.isNotEmpty()) {
                    onNotification?.invoke(text)
                }
            }
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        typingTimeout?.let { handler.removeCallbacks(it) }
        safetyTimeout?.let { handler.removeCallbacks(it) }
    }
}
