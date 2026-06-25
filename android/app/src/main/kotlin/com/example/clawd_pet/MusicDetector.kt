package com.example.clawd_pet

import android.content.Context
import android.media.AudioManager
import android.os.Build

/**
 * 音乐检测 - 回调 + 轮询双重保障
 * 回调检测播放/暂停，轮询兜底确认暂停
 */
class MusicDetector(private val onMusicChanged: (Boolean) -> Unit) {

    private var audioManager: AudioManager? = null
    private var isPlaying = false
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var callback: AudioManager.AudioPlaybackCallback? = null
    private var pauseConfirmRunnable: Runnable? = null
    private var pollRunnable: Runnable? = null

    fun start(context: Context) {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 实时回调
            callback = object : AudioManager.AudioPlaybackCallback() {
                override fun onPlaybackConfigChanged(configs: MutableList<android.media.AudioPlaybackConfiguration>?) {
                    checkAndNotify()
                }
            }
            audioManager?.registerAudioPlaybackCallback(callback!!, handler)
        }

        // 轮询兜底：每 2 秒检查一次，确保暂停不会被遗漏
        pollRunnable = object : Runnable {
            override fun run() {
                checkAndNotify()
                handler.postDelayed(this, 2000)
            }
        }
        handler.postDelayed(pollRunnable!!, 2000)

        isPlaying = audioManager?.isMusicActive == true
    }

    fun stop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            callback?.let { audioManager?.unregisterAudioPlaybackCallback(it) }
            callback = null
        }
        pollRunnable?.let { handler.removeCallbacks(it); pollRunnable = null }
        pauseConfirmRunnable?.let { handler.removeCallbacks(it); pauseConfirmRunnable = null }
    }

    private fun checkAndNotify() {
        val am = audioManager ?: return
        val nowPlaying = am.isMusicActive

        if (nowPlaying) {
            // 确认在播放 → 取消暂停确认
            pauseConfirmRunnable?.let { handler.removeCallbacks(it); pauseConfirmRunnable = null }
            if (!isPlaying) {
                isPlaying = true
                handler.post { onMusicChanged(true) }
            }
        } else {
            // 可能暂停 → 延迟 1 秒再确认（避免瞬间误判）
            if (isPlaying && pauseConfirmRunnable == null) {
                pauseConfirmRunnable = Runnable {
                    pauseConfirmRunnable = null
                    val am2 = audioManager ?: return@Runnable
                    if (!am2.isMusicActive && isPlaying) {
                        isPlaying = false
                        handler.post { onMusicChanged(false) }
                    }
                }
                handler.postDelayed(pauseConfirmRunnable!!, 1000)
            }
        }
    }
}
