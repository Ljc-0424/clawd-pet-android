package com.example.clawd_pet

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.view.*
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebSettings
import android.widget.FrameLayout
import kotlin.random.Random

class FloatingPetService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var webView: WebView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var touchView: View? = null               // 触摸窗口（角色区域）
    private var touchLayoutParams: WindowManager.LayoutParams? = null
    private var bubbleView: android.widget.TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())

    // ── 状态 ──
    private var currentState = "idle"
    private var preDragState = "idle"
    private var preScreenState = "idle"
    private var preMiniState = "idle"        // 进入 mini 前的状态
    private var isDragging = false
    private var isMiniMode = false
    private var miniEdge = "right"
    private var miniEntryX = 0               // 进入 mini 时的窗口 x 坐标
    private var lastDragX = 0                   // 上一次拖拽 X 坐标（判断方向）
    private var dragStartedFromMini = false   // 拖拽是否从 mini 模式开始
    private var edgeTriggered = false
    private var edgePeeked = false
    private var currentSvgFile = ""
    private var isMusicPlaying = false
    private var isTyping = false
    private var chargingShown = false  // 充电动画已播放标记

    // ── 触摸 ──
    private var initWinX = 0; private var initWinY = 0
    private var downX = 0f; private var downY = 0f
    private var isTapping = false
    private var lastTapTime = 0L
    private var tapCount = 0
    private var tapResetRunnable: Runnable? = null

    // ── 定时器（全部可取消）──
    private var autoReturnRunnable: Runnable? = null
    private var idleAnimTimer: Runnable? = null
    private var idleTimer: Runnable? = null
    private var sleepTimer: Runnable? = null
    // 睡眠序列各步骤独立 Runnable，可被干净取消
    private var yawnTimer: Runnable? = null
    private var dozeTimer: Runnable? = null
    private var collapseTimer: Runnable? = null

    companion object {
        private const val WINDOW_SIZE_DP = 35
        private const val DRAG_THRESHOLD = 10
        private const val SLEEP_TIMEOUT = 300000L      // 5 分钟无操作进入睡眠
        private const val YAWN_DURATION = 3000L
        private const val DEEP_SLEEP_TIMEOUT = 600000L  // 10 分钟打盹
        private const val WAKE_DURATION = 1500L
        private const val MOUSE_IDLE_TIMEOUT = 6000L    // 首次进入空闲后的等待
        private const val IDLE_CYCLE_DELAY = 1500L      // 动画间隔（短暂停顿后播下一个）

        private val IDLE_ANIMS = arrayOf("clawd-idle-living.svg","clawd-idle-look.svg","clawd-idle-bubble.svg","clawd-working-wizard.svg","clawd-idle-reading.svg")
        private val ANIM_DURATIONS = mapOf("clawd-idle-living.svg" to 12000L,"clawd-idle-look.svg" to 14000L,"clawd-idle-bubble.svg" to 14000L,"clawd-idle-reading.svg" to 14000L,"clawd-working-wizard.svg" to 12000L)
        private val SLEEP_STATES = setOf("yawning","dozing","collapsing","sleeping","waking")

        // oneshot 状态自动回 idle 的超时（与原版一致）
        private val AUTO_RETURN_MS = mapOf(
            "attention" to 4000L, "error" to 5000L, "notification" to 5000L,
            "low_battery" to 8000L, "network_error" to 8000L,
            "charging" to 6000L, "call_incoming" to 8000L
        )

        // 与原版 Clawd on Desk 完全一致的优先级
        private val STATE_PRIORITY = mapOf(
            "error" to 8, "notification" to 7, "sweeping" to 6,
            "attention" to 5, "carrying" to 4, "juggling" to 4,
            "working" to 3, "thinking" to 2, "idle" to 1, "sleeping" to 0
        )
        // 检测器状态优先级（本地，不来自 bridge）
        private val DETECTOR_PRIORITY = mapOf(
            "notification" to 7, "network_error" to 5, "low_battery" to 4,
            "call_incoming" to 5, "call_active" to 4,
            "charging" to 1, "idle_groove" to 0, "idle_typing" to 0
        )

        // 角色触摸热区比例
        private const val CHAR_LEFT_RATIO = 0.33f
        private const val CHAR_TOP_RATIO = 0.69f
        private const val CHAR_W_RATIO = 0.33f
        private const val CHAR_H_RATIO = 0.22f

        private var instance: FloatingPetService? = null
        // 动画配置：stateId → SVG 文件名列表
        private var animConfig: Map<String, List<String>> = emptyMap()
        // animationId → SVG 文件名映射
        private val animIdToSvg = mapOf(
            "idle_follow" to "clawd-idle-follow.svg", "idle_living" to "clawd-idle-living.svg",
            "idle_look" to "clawd-idle-look.svg", "idle_bubble" to "clawd-idle-bubble.svg",
            "idle_reading" to "clawd-idle-reading.svg", "idle_wizard" to "clawd-working-wizard.svg",
            "working_typing" to "clawd-working-typing.svg", "working_thinking" to "clawd-working-thinking.svg",
            "working_ultrathink" to "clawd-working-ultrathink.svg", "working_building" to "clawd-working-building.svg",
            "working_debugger" to "clawd-working-debugger.svg", "working_typing_boss" to "clawd-working-typing-boss.svg",
            "working_sweeping" to "clawd-working-sweeping.svg", "working_juggling" to "clawd-working-juggling.svg",
            "working_carrying" to "clawd-working-carrying.svg",
            "happy" to "clawd-happy.svg", "error" to "clawd-error.svg",
            "notification" to "clawd-notification.svg", "annoyed" to "clawd-react-annoyed.svg",
            "yawn" to "clawd-idle-yawn.svg", "doze" to "clawd-idle-doze.svg",
            "collapse" to "clawd-collapse-sleep.svg", "sleeping" to "clawd-sleeping.svg", "wake" to "clawd-wake.svg",
            "react_left" to "clawd-react-left.svg", "react_right" to "clawd-react-right.svg",
            "react_double" to "clawd-react-double.svg", "react_double_jump" to "clawd-react-double-jump.svg",
            "react_drag" to "clawd-react-drag.svg",
            "mini_peek" to "clawd-mini-peek.svg", "mini_idle" to "clawd-mini-idle.svg",
            "mini_sleep" to "clawd-mini-sleep.svg", "mini_happy" to "clawd-mini-happy.svg",
            "mini_typing" to "clawd-mini-typing.svg", "mini_alert" to "clawd-mini-alert.svg",
            "mini_crabwalk" to "clawd-mini-crabwalk.svg", "mini_enter" to "clawd-mini-enter.svg",
            "mini_enter_sleep" to "clawd-mini-enter-sleep.svg",
            "headphones_groove" to "clawd-headphones-groove.svg",
            "idle_reading_old" to "clawd-idle-reading-old.svg",
            "notification_retired" to "clawd-notification-retired-2026-05-12.svg",
            "working_building_boxes" to "clawd-working-building-boxes.svg",
            "working_conducting" to "clawd-working-conducting-retired-2026-05-12.svg",
            "working_typing_old" to "clawd-working-typing-old.svg"
        )

        fun updateState(state: String) { instance?.onStateChanged(state) }
        fun resize(sizeDp: Int) { instance?.resizeWindow(sizeDp) }
        fun forceState(state: String) { instance?.applyState(state, force = true) }
        fun updateAnimConfig(json: String) {
            try {
                // 先加载默认映射
                val merged = mutableMapOf<String, List<String>>()
                merged["idle"] = listOf("clawd-idle-follow.svg")
                merged["idle_groove"] = listOf("clawd-headphones-groove.svg")
                merged["idle_typing"] = listOf("clawd-working-typing.svg")
                merged["thinking"] = listOf("clawd-working-thinking.svg")
                merged["working"] = listOf("clawd-working-typing.svg")
                merged["sweeping"] = listOf("clawd-working-sweeping.svg")
                merged["juggling"] = listOf("clawd-working-juggling.svg")
                merged["carrying"] = listOf("clawd-working-carrying.svg")
                merged["attention"] = listOf("clawd-happy.svg")
                merged["error"] = listOf("clawd-error.svg")
                merged["notification"] = listOf("clawd-notification.svg")
                merged["low_battery"] = listOf("clawd-idle-yawn.svg")
                merged["charging"] = listOf("clawd-happy.svg")
                merged["call_incoming"] = listOf("clawd-notification.svg")
                merged["call_active"] = listOf("clawd-working-typing.svg")
                merged["double"] = listOf("clawd-react-double.svg", "clawd-react-double-jump.svg")
                merged["drag"] = listOf("clawd-react-drag.svg")
                merged["clickLeft"] = listOf("clawd-react-left.svg")
                merged["clickRight"] = listOf("clawd-react-right.svg")
                merged["annoyed"] = listOf("clawd-react-annoyed.svg")
                merged["edge_peek"] = listOf("clawd-mini-peek.svg")
                merged["mini_idle"] = listOf("clawd-mini-idle.svg")
                merged["mini_typing"] = listOf("clawd-mini-typing.svg")
                merged["mini_happy"] = listOf("clawd-mini-happy.svg")
                merged["mini_alert"] = listOf("clawd-mini-alert.svg")
                merged["mini_sleep"] = listOf("clawd-mini-sleep.svg")
                // 合并用户配置（覆盖默认）
                val org = org.json.JSONObject(json)
                for (key in org.keys()) {
                    val arr = org.getJSONArray(key)
                    val svgs = (0 until arr.length()).mapNotNull { animIdToSvg[arr.getString(it)] }
                    if (svgs.isNotEmpty()) merged[key] = svgs
                }
                animConfig = merged
                android.util.Log.d("FloatingPet", "动画配置已更新: ${animConfig.size} 个状态")
            } catch (e: Exception) {
                android.util.Log.e("FloatingPet", "动画配置解析失败: $e")
            }
        }
    }

    // ══════════════════════════════════════════════════
    //  SVG 映射（支持配置随机选择）
    // ══════════════════════════════════════════════════
    private fun svgForState(s: String): String {
        if (isMiniMode) {
            val mini = miniSvgForState(s)
            if (mini != null) return mini
        }
        val configSvgs = animConfig[s]
        if (!configSvgs.isNullOrEmpty()) return configSvgs.random()
        return defaultSvgForState(s)
    }

    /** mini 模式下的 SVG 映射（返回 null 表示不转换，用默认） */
    private fun miniSvgForState(s: String): String? {
        val configKey = when (s) {
            "idle" -> "mini_idle"
            "idle_groove","idle_typing" -> "mini_idle"
            "idle_living","idle_look","idle_bubble","idle_reading","idle_wizard" -> "mini_idle"
            "thinking","working","sweeping","juggling","carrying" -> "mini_typing"
            "attention","charging","call_ended" -> "mini_happy"
            "notification","call_incoming","low_battery","network_error" -> "mini_alert"
            "yawning","dozing","collapsing","sleeping" -> "mini_sleep"
            else -> return null
        }
        val configSvgs = animConfig[configKey]
        if (!configSvgs.isNullOrEmpty()) return configSvgs.random()
        return when (s) {
            "idle","idle_groove","idle_typing","idle_living","idle_look","idle_bubble","idle_reading","idle_wizard" -> "clawd-mini-idle.svg"
            "thinking","working","sweeping","juggling","carrying" -> "clawd-mini-typing.svg"
            "attention","charging","call_ended" -> "clawd-mini-happy.svg"
            "notification","call_incoming","low_battery","network_error" -> "clawd-mini-alert.svg"
            "yawning","dozing","collapsing","sleeping" -> "clawd-mini-sleep.svg"
            else -> null
        }
    }

    private fun defaultSvgForState(s: String) = when (s) {
            "idle" -> "clawd-idle-follow.svg"
            "idle_groove" -> "clawd-headphones-groove.svg"
            "idle_typing" -> "clawd-working-typing.svg"
            "thinking" -> "clawd-working-thinking.svg"
            "working" -> "clawd-working-typing.svg"
            "sweeping" -> "clawd-working-sweeping.svg"
            "juggling" -> "clawd-working-juggling.svg"
            "carrying" -> "clawd-working-carrying.svg"
            "attention" -> "clawd-happy.svg"
            "error","network_error" -> "clawd-error.svg"
            "notification","call_incoming" -> "clawd-notification.svg"
            "low_battery" -> "clawd-idle-yawn.svg"
            "charging" -> "clawd-happy.svg"
            "call_active" -> "clawd-working-typing.svg"
            "yawning" -> "clawd-idle-yawn.svg"
            "dozing" -> "clawd-idle-doze.svg"
        "collapsing" -> "clawd-collapse-sleep.svg"
        "sleeping" -> "clawd-sleeping.svg"
        "waking" -> "clawd-wake.svg"
        "drag" -> "clawd-react-drag.svg"
        "clickLeft" -> "clawd-react-left.svg"
        "clickRight" -> "clawd-react-right.svg"
        "annoyed" -> "clawd-react-annoyed.svg"
        "double" -> pickRandom("clawd-react-double.svg","clawd-react-double-jump.svg")
        "edge_peek" -> "clawd-mini-peek.svg"
        else -> "clawd-idle-follow.svg"
    }

    // ══════════════════════════════════════════════════
    //  生命周期
    // ══════════════════════════════════════════════════
    override fun onBind(i: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate(); instance = this; startFg()
        // 从 SharedPreferences 加载动画配置
        val savedConfig = getSharedPreferences("clawd_prefs", MODE_PRIVATE).getString("anim_config", null)
        if (savedConfig != null) updateAnimConfig(savedConfig)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createWindow(); startDetectors()
    }
    override fun onDestroy() {
        super.onDestroy(); cancelAllTimers(); instance = null
        touchView?.let { try { windowManager?.removeView(it) } catch (_: Exception) {} }
        floatingView?.let { windowManager?.removeView(it) }; webView?.destroy()
    }

    private fun startFg() {
        val ch = "c"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService("notification") as NotificationManager
            nm.createNotificationChannel(NotificationChannel(ch, "Clawd", NotificationManager.IMPORTANCE_LOW))
        }
        startForeground(1, Notification.Builder(this, ch)
            .setContentTitle("Clawd Desktop Pet").setContentText("Running")
            .setSmallIcon(android.R.drawable.ic_dialog_info).setOngoing(true).build())
    }

    private fun dpToPx(dp: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics).toInt()
    private fun pickRandom(vararg c: String) = c[Random.nextInt(c.size)]

    // ══════════════════════════════════════════════════
    //  检测器（直接 applyState，不走优先级系统）
    // ══════════════════════════════════════════════════
    private val bridgeStates = setOf("thinking","working","sweeping","juggling","carrying","attention","error","notification")

    private fun startDetectors() {
        MusicDetector { playing -> handler.post {
            isMusicPlaying = playing
            if (playing) { if (currentState in setOf("idle","idle_groove")) applyState("idle_groove", force = true) }
            else if (currentState == "idle_groove") { currentState = "idle"; resolveAndApply() }
        }}.start(this)

        TypingDetector.onTypingChanged = { typing -> handler.post {
            isTyping = typing
            if (typing) { if (currentState !in bridgeStates) applyState("idle_typing", force = true) }
            else if (currentState == "idle_typing") { currentState = "idle"; resolveAndApply() }
        }}

        TypingDetector.onNotification = { _ -> handler.post {
            if (currentState !in bridgeStates) applyState("notification")
            showBubble("收到通知")
        }}

        BatteryDetector { st -> handler.post {
            when (st) {
                "charging" -> { if (!chargingShown) { chargingShown = true; applyState("charging"); showBubble("充电中") } }
                "not_charging" -> { chargingShown = false; if (currentState == "charging") { currentState = "idle"; resolveAndApply() } }
                "low_battery" -> { if (currentState == "idle") { applyState("low_battery"); showBubble("电量低") } }
            }
        }}.start(this)

        NetworkDetector { st -> handler.post {
            when (st) {
                "network_lost" -> { if (currentState == "idle") { applyState("network_error"); showBubble("网络断开") } }
                "network_ok" -> { if (currentState == "network_error") { currentState = "idle"; resolveAndApply() } }
            }
        }}.start(this)

        ScreenDetector { st -> handler.post {
            when (st) {
                "screen_off" -> { if (currentState !in SLEEP_STATES) preScreenState = currentState; floatingView?.visibility = View.INVISIBLE; cancelAllTimers() }
                "screen_on" -> { floatingView?.visibility = View.VISIBLE; if (preScreenState in SLEEP_STATES || preScreenState == "idle") wakeUp() else { currentState = preScreenState; applyState(preScreenState, force = true) } }
            }
        }}.start(this)

        CallDetector { st -> handler.post {
            when (st) {
                "call_incoming" -> { applyState("call_incoming"); showBubble("来电") }
                "call_active" -> { if (currentState == "call_incoming") { applyState("call_active"); showBubble("通话中") } }
                "call_ended" -> { if (currentState == "call_active") { showBubble("通话结束"); currentState = "idle"; resolveAndApply() } }
            }
        }}.start(this)
    }

    /** 检测器状态结束后按优先级恢复 */
    private fun resolveAndApply() {
        when {
            currentState in bridgeStates -> {}
            isTyping -> applyState("idle_typing", force = true)
            isMusicPlaying -> applyState("idle_groove", force = true)
            else -> applyState("idle")
        }
    }

    // ══════════════════════════════════════════════════
    //  状态机核心
    // ══════════════════════════════════════════════════
    private fun onStateChanged(state: String) {
        if (isDragging) { currentState = state; return }

        // 本地交互（点击/拖拽）→ 反应动画
        val reactionStates = setOf("clickLeft", "clickRight", "annoyed", "double", "drag")
        if (state in reactionStates) { triggerReaction(state); return }

        if (state == "waking") { wakeUp(); return }
        // attention 是 oneshot，始终允许（applyState 内有自动回 idle）
        if (state == "attention") { applyState("attention"); return }

        // 优先级检查：获取新状态和当前状态的优先级
        val newPri = STATE_PRIORITY[state] ?: DETECTOR_PRIORITY[state] ?: 0
        val curPri = STATE_PRIORITY[currentState] ?: DETECTOR_PRIORITY[currentState] ?: 0
        if (newPri < curPri && currentState != "idle") return

        // 睡眠中被唤醒
        if (SLEEP_STATES.contains(currentState) && state !in SLEEP_STATES && state != "idle") {
            stopSleepSequence()
            currentState = "waking"; currentSvgFile = svgForState("waking"); loadSvg()
            handler.postDelayed({ applyState(state) }, WAKE_DURATION); return
        }
        applyState(state)
    }

    private fun applyState(s: String, force: Boolean = false) {
        if (!force && s == currentState && currentSvgFile.isNotEmpty()) return
        android.util.Log.d("State", "applyState: $s (was $currentState) force=$force svg=${svgForState(s)}")
        currentState = s
        cancelAR(); stopIdleTimers(); stopSleepSequence()

        currentSvgFile = svgForState(s)
        loadSvg()

        // oneshot 状态自动回 idle
        val ar = AUTO_RETURN_MS[s] ?: 0
        if (ar > 0) {
            autoReturnRunnable = Runnable { autoReturnRunnable = null; resolveAndApply() }
            handler.postDelayed(autoReturnRunnable!!, ar)
        }
        // idle → 启动空闲定时器
        else if (s == "idle") startIdleTimers()
        // dozing → 睡眠序列后续步骤
        else if (s == "dozing") startDozingSequence()
    }

    // ══════════════════════════════════════════════════
    //  空闲动画
    // ══════════════════════════════════════════════════
    private fun startIdleTimers() {
        android.util.Log.d("Idle", "startIdleTimers called state=$currentState")
        stopIdleTimers()
        // 睡眠定时器独立管理（5分钟无操作触发）
        startSleepTimer()
        // 首次等待后开始动画循环
        scheduleNextIdleAnim(MOUSE_IDLE_TIMEOUT)
    }

    /** 调度下一次空闲随机动画 */
    private fun scheduleNextIdleAnim(delay: Long) {
        idleAnimTimer?.let { handler.removeCallbacks(it) }
        idleAnimTimer = Runnable {
            idleAnimTimer = null
            if (isDragging) return@Runnable  // 拖拽中不切换动画
            if (isMusicPlaying) {
                // 音乐播放中 → 等音乐结束后再循环
                idleAnimTimer = Runnable { idleAnimTimer = null; if (!isMusicPlaying && currentState == "idle") scheduleNextIdleAnim(0) }
                handler.postDelayed(idleAnimTimer!!, MOUSE_IDLE_TIMEOUT); return@Runnable
            }
            if (currentState == "idle") {
                currentSvgFile = pickNextAnim(); loadSvg()
                val d = ANIM_DURATIONS[currentSvgFile] ?: 12000L
                // 动画播放完毕 → 短暂停顿 → 播下一个（不回 follow）
                idleTimer = Runnable { idleTimer = null; if (currentState == "idle") scheduleNextIdleAnim(IDLE_CYCLE_DELAY) }
                handler.postDelayed(idleTimer!!, d)
            }
        }
        handler.postDelayed(idleAnimTimer!!, delay)
    }

    private val playedAnims = mutableSetOf<String>()
    private fun pickNextAnim(): String {
        val a = IDLE_ANIMS.filter { it !in playedAnims }
        if (a.isEmpty()) { playedAnims.clear(); return IDLE_ANIMS.random() }
        val p = a.random(); playedAnims.add(p); return p
    }

    // ══════════════════════════════════════════════════
    //  睡眠序列（每步独立 Runnable，可干净取消）
    // ══════════════════════════════════════════════════
    private fun startSleepTimer() {
        sleepTimer?.let { handler.removeCallbacks(it) }
        sleepTimer = Runnable {
            sleepTimer = null
            if (currentState == "idle") {
                stopIdleTimers()
                currentState = "yawning"; currentSvgFile = svgForState("yawning"); loadSvg()
                yawnTimer = Runnable {
                    yawnTimer = null
                    if (currentState == "yawning") {
                        currentState = "dozing"; currentSvgFile = svgForState("dozing"); loadSvg()
                        startDozingSequence()
                    }
                }
                handler.postDelayed(yawnTimer!!, YAWN_DURATION)
            }
        }
        handler.postDelayed(sleepTimer!!, SLEEP_TIMEOUT)
    }

    /** 打盹 → 瘫倒 → 熟睡（每步独立 Runnable） */
    private fun startDozingSequence() {
        dozeTimer?.let { handler.removeCallbacks(it) }
        dozeTimer = Runnable {
            dozeTimer = null
            if (currentState == "dozing") {
                currentState = "collapsing"; currentSvgFile = svgForState("collapsing"); loadSvg()
                collapseTimer = Runnable {
                    collapseTimer = null
                    if (currentState == "collapsing") {
                        currentState = "sleeping"; currentSvgFile = svgForState("sleeping"); loadSvg()
                    }
                }
                handler.postDelayed(collapseTimer!!, 6000)
            }
        }
        handler.postDelayed(dozeTimer!!, DEEP_SLEEP_TIMEOUT)
    }

    private fun stopSleepSequence() {
        yawnTimer?.let { handler.removeCallbacks(it); yawnTimer = null }
        dozeTimer?.let { handler.removeCallbacks(it); dozeTimer = null }
        collapseTimer?.let { handler.removeCallbacks(it); collapseTimer = null }
    }

    private fun stopIdleTimers() {
        idleAnimTimer?.let { handler.removeCallbacks(it); idleAnimTimer = null }
        idleTimer?.let { handler.removeCallbacks(it); idleTimer = null }
        sleepTimer?.let { handler.removeCallbacks(it); sleepTimer = null }
    }

    private fun cancelAR() { autoReturnRunnable?.let { handler.removeCallbacks(it); autoReturnRunnable = null } }

    private fun cancelAllTimers() { cancelAR(); stopIdleTimers(); stopSleepSequence() }

    // ══════════════════════════════════════════════════
    //  唤醒 / 反应
    // ══════════════════════════════════════════════════
    private fun wakeUp() {
        cancelAllTimers()
        currentState = "waking"; currentSvgFile = svgForState("waking"); loadSvg()
        handler.postDelayed({ resolveAndApply() }, WAKE_DURATION)
    }

    private fun triggerReaction(state: String, dur: Long = 0L) {
        val svg = svgForState(state)
        val delay = if (dur > 0) dur else when (state) {
            "clickLeft","clickRight" -> 2500L; "double","annoyed" -> 5000L; else -> 2500L
        }
        playReaction(svg, delay)
    }

    private fun playReaction(svg: String, dur: Long) {
        cancelAR(); stopIdleTimers()
        currentSvgFile = svg; loadSvg()
        autoReturnRunnable = Runnable {
            autoReturnRunnable = null
            resolveAndApply()
        }
        handler.postDelayed(autoReturnRunnable!!, dur)
    }

    private fun onForceState(state: String) { applyState(state, force = true) }

    // ══════════════════════════════════════════════════
    //  交互：点击 / 拖拽 / 边缘
    // ══════════════════════════════════════════════════
    private var miniSlideInProgress = false   // 横移动画进行中

    private fun enterMiniMode(edge: String) {
        if (isMiniMode) return
        isMiniMode = true; miniEdge = edge
        preMiniState = currentState
        cancelAllTimers()
        val m = resources.displayMetrics
        val w = layoutParams?.width ?: dpToPx(WINDOW_SIZE_DP)
        // 退出位置：角色边缘刚好贴着屏幕边缘
        val charLeftOff = (w * CHAR_LEFT_RATIO).toInt()
        val charW = (w * CHAR_W_RATIO).toInt()
        val x = if (edge == "right") m.widthPixels - charLeftOff - charW
                else -charLeftOff
        miniEntryX = x
        layoutParams?.let { p -> p.x = x; windowManager?.updateViewLayout(floatingView, p) }
        updateTouchWindowPosition()
        currentState = "idle"; currentSvgFile = "clawd-mini-enter.svg"; loadSvg()
        handler.postDelayed({ if (isMiniMode) { currentState = "idle"; applyState("idle") } }, 2000)
    }

    private fun exitMiniMode() {
        if (!isMiniMode || miniSlideInProgress) return
        miniSlideInProgress = true; isMiniMode = false; isDragging = false; isTapping = false; cancelAllTimers()
        currentSvgFile = "clawd-mini-crabwalk.svg"; loadSvg()
        val m = resources.displayMetrics
        val w = layoutParams?.width ?: dpToPx(WINDOW_SIZE_DP)
        val startX = layoutParams?.x ?: 0
        // 目标：边缘位置，确保角色区域完全可见
        val margin = (w * (CHAR_LEFT_RATIO + CHAR_W_RATIO)).toInt()  // 角色右边缘到窗口左边的距离
        val targetX = if (miniEdge == "right") m.widthPixels - margin else margin - w
        val duration = 400L; val startTime = System.currentTimeMillis()
        val animRunnable = object : Runnable {
            override fun run() {
                val elapsed = System.currentTimeMillis() - startTime
                val t = (elapsed.toFloat() / duration).coerceIn(0f, 1f)
                val ease = t * (2 - t)
                layoutParams?.let { p ->
                    p.x = (startX + (targetX - startX) * ease).toInt()
                    windowManager?.updateViewLayout(floatingView, p)
                }
                updateTouchWindowPosition()
                if (t < 1f) handler.postDelayed(this, 16)
                else {
                    miniSlideInProgress = false
                    // 播完横移，直接设为空闲，不启动定时器（等下次交互再启动）
                    currentState = "idle"; currentSvgFile = svgForState("idle"); loadSvg()
                }
            }
        }
        handler.post(animRunnable)
    }

    private fun checkEdge(p: WindowManager.LayoutParams) {
        val m = resources.displayMetrics
        val w = p.width
        val charW = (w * CHAR_W_RATIO).toInt()
        val thresh = -charW / 2  // 角色半遮挡时触发（负值=角色需要越过屏幕边缘）
        val charRight = p.x + (w * (CHAR_LEFT_RATIO + CHAR_W_RATIO)).toInt()
        val charLeft = p.x + (w * CHAR_LEFT_RATIO).toInt()
        // 只有往边缘方向拖才触发吸附
        val draggingRight = p.x > lastDragX
        val draggingLeft = p.x < lastDragX
        lastDragX = p.x
        val atRight = charRight >= m.widthPixels - thresh && draggingRight
        val atLeft = charLeft <= thresh && draggingLeft
        if ((atRight || atLeft) && !isMiniMode) {
            enterMiniMode(if (atRight) "right" else "left")
        }
    }

    private fun handleTap() {
        android.util.Log.d("Touch", "handleTap: state=$currentState svg=$currentSvgFile isDragging=$isDragging")
        if (miniSlideInProgress) return
        if (isMiniMode) { exitMiniMode(); return }
        val now = System.currentTimeMillis()
        if (currentState in SLEEP_STATES) { wakeUp(); return }
        if (now - lastTapTime < 300) { lastTapTime = 0; tapCount = 0; playReaction(svgForState("double"), 3500L); return }
        tapCount++
        tapResetRunnable?.let { handler.removeCallbacks(it) }
        tapResetRunnable = Runnable { tapCount = 0 }; handler.postDelayed(tapResetRunnable!!, 1500)
        if (tapCount >= 3) { tapCount = 0; playReaction(svgForState("annoyed"), 5000L) }
        else playReaction(svgForState(if (Random.nextBoolean()) "clickLeft" else "clickRight"), 2500L)
        lastTapTime = now
    }

    // ══════════════════════════════════════════════════
    //  气泡（跟随触摸窗口）
    // ══════════════════════════════════════════════════
    private fun createBubble() {
        bubbleView = android.widget.TextView(this).apply {
            setPadding(dpToPx(12), dpToPx(5), dpToPx(12), dpToPx(5))
            setTextColor(android.graphics.Color.WHITE); textSize = 10f
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(android.graphics.Color.argb(230, 45, 45, 55))
                cornerRadius = dpToPx(8).toFloat()
                setStroke(dpToPx(1), android.graphics.Color.argb(60, 255, 255, 255))
            }
            visibility = View.GONE
        }
        bubbleParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }
        windowManager?.addView(bubbleView, bubbleParams)
    }

    private fun showBubble(t: String, ms: Long = 3000) {
        bubbleView?.text = t; bubbleView?.visibility = View.VISIBLE
        updateBubblePosition()
        handler.postDelayed({ bubbleView?.visibility = View.GONE }, ms)
    }

    private fun updateBubblePosition() {
        val tlp = touchLayoutParams ?: return
        // 气泡居中显示在触摸窗口下方
        bubbleParams?.x = tlp.x + tlp.width / 2 - dpToPx(30)
        bubbleParams?.y = tlp.y + tlp.height + dpToPx(2)
        try { windowManager?.updateViewLayout(bubbleView, bubbleParams) } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════
    //  悬浮窗
    // ══════════════════════════════════════════════════
    @SuppressLint("SetJavaScriptEnabled")
    private fun createWindow() {
        val wp = dpToPx(WINDOW_SIZE_DP); val tp = dpToPx(DRAG_THRESHOLD)
        // ── 渲染窗口（不拦截触摸，让事件穿透到触摸窗口）──
        val container = FrameLayout(this).apply { setBackgroundColor(0); isClickable = false; isFocusable = false }
        layoutParams = WindowManager.LayoutParams(wp, wp,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.RGBA_8888).apply { gravity = Gravity.TOP or Gravity.START; x = 100; y = 300 }
        floatingView = container; windowManager?.addView(container, layoutParams)
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true; settings.domStorageEnabled = true
            settings.allowFileAccess = true; settings.allowContentAccess = true
            settings.cacheMode = WebSettings.LOAD_NO_CACHE
            webViewClient = WebViewClient(); setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setLayerType(android.view.View.LAYER_TYPE_HARDWARE, null)
            isClickable = false; isFocusable = false
        }
        container.addView(webView, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        loadSvg("clawd-idle-follow.svg"); startIdleTimers(); createBubble()

        // ── 触摸窗口（角色区域，处理所有交互）──
        val tw = dpToPx(WINDOW_SIZE_DP)
        val touchContainer = object : FrameLayout(this) {
            override fun onTouchEvent(ev: MotionEvent): Boolean {
                when (ev.action) {
                    MotionEvent.ACTION_DOWN -> {
                        downX = ev.rawX; downY = ev.rawY
                        initWinX = this@FloatingPetService.layoutParams?.x ?: 0; initWinY = this@FloatingPetService.layoutParams?.y ?: 0
                        isTapping = true
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        if (!isDragging && isTapping) {
                            val dx = ev.rawX - downX; val dy = ev.rawY - downY
                            if (dx * dx + dy * dy > tp * tp) {
                                isDragging = true; edgeTriggered = false; edgePeeked = false
                                preDragState = currentState; cancelAllTimers()
                                dragStartedFromMini = isMiniMode
                                lastDragX = this@FloatingPetService.layoutParams?.x ?: 0
                                currentSvgFile = svgForState("drag"); loadSvg()
                            }
                        }
                        if (isDragging) {
                            this@FloatingPetService.layoutParams?.let { p ->
                                p.x = initWinX + (ev.rawX - downX).toInt()
                                p.y = initWinY + (ev.rawY - downY).toInt()
                                windowManager?.updateViewLayout(floatingView, p)
                                updateTouchWindowPosition()
                                if (!dragStartedFromMini) checkEdge(p)
                                updateBubblePosition()
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        if (isDragging) {
                            isDragging = false; edgeTriggered = false; edgePeeked = false
                            if (dragStartedFromMini) {
                                val m = resources.displayMetrics; val w = this@FloatingPetService.layoutParams?.width ?: tw
                                val curX = this@FloatingPetService.layoutParams?.x ?: 0
                                val charW = (w * CHAR_W_RATIO).toInt()
                                val thresh = -charW / 2
                                val charRight = curX + (w * (CHAR_LEFT_RATIO + CHAR_W_RATIO)).toInt()
                                val charLeft = curX + (w * CHAR_LEFT_RATIO).toInt()
                                val atRight = charRight >= m.widthPixels - thresh
                                val atLeft = charLeft <= thresh
                                if (atRight || atLeft) {
                                    isMiniMode = false; cancelAllTimers()
                                    enterMiniMode(if (atRight) "right" else "left")
                                } else {
                                    isMiniMode = false; cancelAllTimers(); miniSlideInProgress = false
                                    currentState = ""; applyState("idle")
                                }
                            } else {
                                // oneshot 状态（attention/error 等）拖拽后直接回空闲
                                val oneshot = setOf("attention","error","notification","charging","low_battery","network_error","call_incoming")
                                if (preDragState in oneshot) { currentState = ""; applyState("idle") }
                                else { currentState = ""; applyState(preDragState) }
                            }
                            dragStartedFromMini = false
                        } else if (isTapping) handleTap()
                        isTapping = false; return true
                    }
                }
                return super.onTouchEvent(ev)
            }
        }
        touchContainer.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        touchLayoutParams = WindowManager.LayoutParams(
            (tw * CHAR_W_RATIO).toInt(), (tw * CHAR_H_RATIO).toInt(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 100 + (tw * CHAR_LEFT_RATIO).toInt(); y = 300 + (tw * CHAR_TOP_RATIO).toInt() }
        touchView = touchContainer; windowManager?.addView(touchContainer, touchLayoutParams)

        loadSvg("clawd-idle-follow.svg"); startIdleTimers(); createBubble()
    }

    /** 同步触摸窗口位置到角色区域 */
    private fun updateTouchWindowPosition() {
        val lp = layoutParams ?: return; val tlp = touchLayoutParams ?: return
        val w = lp.width
        tlp.x = lp.x + (w * CHAR_LEFT_RATIO).toInt()
        tlp.y = lp.y + (w * CHAR_TOP_RATIO).toInt()
        tlp.width = (w * CHAR_W_RATIO).toInt(); tlp.height = (w * CHAR_H_RATIO).toInt()
        try { windowManager?.updateViewLayout(touchView, tlp) } catch (_: Exception) {}
    }

    private fun loadSvg(f: String = currentSvgFile) {
        android.util.Log.d("Svg", "loadSvg: $f state=$currentState dragging=$isDragging")
        try {
            val s = assets.open("svg/$f").bufferedReader().readText()
            val flip = if (isMiniMode && miniEdge == "left") "svg{transform:scaleX(-1)}" else ""
            webView?.loadDataWithBaseURL(null,
                "<!DOCTYPE html><html style='background:transparent'><head><meta name='viewport' content='width=device-width,initial-scale=1.0'>" +
                "<style>*{margin:0;padding:0}html,body{background:transparent!important;display:flex;justify-content:center;align-items:center;height:100vh;width:100vw;overflow:hidden}svg{width:100%;height:100%}$flip</style></head>" +
                "<body>$s</body></html>", "text/html", "UTF-8", null)
        } catch (_: Exception) {}
    }

    private fun resizeWindow(dp: Int) {
        val p = layoutParams ?: return; p.width = dpToPx(dp); p.height = dpToPx(dp)
        try { windowManager?.updateViewLayout(floatingView, p) } catch (_: Exception) {}
        updateTouchWindowPosition()
    }
}
