// 注意：此文件当前未被使用。
// App 实际使用的是 FloatingPetService（WebView + SVG 方案）。
// 此文件保留作为备选方案参考（使用原生 TextView + Emoji 方案，更轻量）。

package com.example.clawd_pet

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/// 悬浮窗服务
class FloatingWindowService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var currentState = "idle"

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createFloatingWindow()
    }

    private fun createFloatingWindow() {
        // 创建悬浮窗布局
        val inflater = LayoutInflater.from(this)
        floatingView = inflater.inflate(R.layout.floating_window, null)

        // 设置窗口参数
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        // 初始位置：右下角
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 200

        // 添加悬浮窗
        windowManager?.addView(floatingView, params)

        // 设置拖动
        setupDrag(params)

        // 设置点击事件
        floatingView?.setOnClickListener {
            // 发送广播打开主界面
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }

        // 设置长按事件
        floatingView?.setOnLongClickListener {
            // 显示菜单
            showMenu()
            true
        }
    }

    private fun setupDrag(params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        floatingView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(floatingView, params)
                    true
                }
                else -> false
            }
        }
    }

    private fun showMenu() {
        // TODO: 显示菜单（设置、退出等）
    }

    fun updateState(state: String) {
        currentState = state
        val iconView = floatingView?.findViewById<TextView>(R.id.pet_icon)
        val textView = floatingView?.findViewById<TextView>(R.id.pet_text)
        val bodyView = floatingView?.findViewById<LinearLayout>(R.id.pet_body)

        when (state) {
            "idle" -> {
                iconView?.text = "🦀"
                textView?.text = "IDLE"
                bodyView?.setBackgroundResource(R.drawable.pet_body_background)
            }
            "thinking" -> {
                iconView?.text = "🤔"
                textView?.text = "THINK"
                bodyView?.setBackgroundResource(R.drawable.pet_body_thinking)
            }
            "tool_call" -> {
                iconView?.text = "🔧"
                textView?.text = "WORK"
                bodyView?.setBackgroundResource(R.drawable.pet_body_thinking)
            }
            "success" -> {
                iconView?.text = "🎉"
                textView?.text = "DONE"
                bodyView?.setBackgroundResource(R.drawable.pet_body_success)
            }
            "error" -> {
                iconView?.text = "❌"
                textView?.text = "ERROR"
                bodyView?.setBackgroundResource(R.drawable.pet_body_error)
            }
            "user_message" -> {
                iconView?.text = "👀"
                textView?.text = "MSG"
                bodyView?.setBackgroundResource(R.drawable.pet_body_background)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingView?.let { windowManager?.removeView(it) }
    }
}
