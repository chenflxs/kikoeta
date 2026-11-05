package com.kikoeta.kikoeta_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Process-owned audio focus and headset controls for the persistent playback engine. */
object PlaybackAudioControl {
    private lateinit var appContext: Context
    private var audioControlChannel: MethodChannel? = null
    private var earPauseReceiver: BroadcastReceiver? = null
    private var ignoreAudioFocus = false
    private var playbackActive = false
    private var hasAudioFocus = false

    // 音频焦点丢失 → 通知 Dart 暂停
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (playbackActive && !ignoreAudioFocus &&
            (change == AudioManager.AUDIOFOCUS_LOSS ||
                change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT)
        ) {
            setPlaybackActive(false)
            audioControlChannel?.invokeMethod("pause", null)
        }
    }

    // ---------------- 音频控制（拔出耳机暂停 / 音频焦点） ----------------
    fun register(context: Context, flutterEngine: FlutterEngine) {
        appContext = context.applicationContext
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kikoeta/audio_control",
        )
        audioControlChannel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEarPause" -> {
                    setEarPauseEnabled(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                "setIgnoreAudioFocus" -> {
                    setIgnoreAudioFocus(call.argument<Boolean>("ignore") == true)
                    result.success(null)
                }
                "setPlaybackActive" -> {
                    setPlaybackActive(call.argument<Boolean>("active") == true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 拔出耳机/断开蓝牙自动暂停（动态注册，仅开启时注册） */
    private fun setEarPauseEnabled(enabled: Boolean) {
        if (enabled) {
            if (earPauseReceiver == null) {
                earPauseReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                            audioControlChannel?.invokeMethod("pause", null)
                        }
                    }
                }
                val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                if (Build.VERSION.SDK_INT >= 33) {
                    appContext.registerReceiver(earPauseReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("DEPRECATION")
                    appContext.registerReceiver(earPauseReceiver, filter)
                }
            }
        } else {
            earPauseReceiver?.let { appContext.unregisterReceiver(it) }
            earPauseReceiver = null
        }
    }

    /** 设置仅改变焦点策略；空闲时不申请焦点。 */
    private fun setIgnoreAudioFocus(ignore: Boolean) {
        ignoreAudioFocus = ignore
        updateAudioFocus()
    }

    /** 播放开始前申请焦点，暂停或停止后释放。 */
    private fun setPlaybackActive(active: Boolean) {
        playbackActive = active
        updateAudioFocus()
    }

    private fun updateAudioFocus() {
        val am = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (ignoreAudioFocus || !playbackActive) {
            if (hasAudioFocus) {
                hasAudioFocus = false
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(audioFocusListener)
            }
        } else if (!hasAudioFocus) {
            @Suppress("DEPRECATION")
            hasAudioFocus = am.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }
}
