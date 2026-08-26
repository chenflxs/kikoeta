package com.kikoeta.kikoeta_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var overlay: LyricsOverlay? = null
    private var audioControlChannel: MethodChannel? = null
    private var earPauseReceiver: BroadcastReceiver? = null

    // 音频焦点丢失 → 通知 Dart 暂停
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
        ) {
            audioControlChannel?.invokeMethod("pause", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerAudioControl(flutterEngine)
        registerMedia3(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kikoeta/lyrics_overlay",
        )
        overlay = LyricsOverlay(this, channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(overlay?.isAvailable())
                "requestPermission" -> {
                    val ok = overlay?.isAvailable() == true
                    if (!ok && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                    }
                    result.success(ok)
                }
                "show" -> {
                    val a = call.arguments as Map<*, *>
                    overlay?.show(
                        a["text"] as String,
                        (a["fontSize"] as Number).toDouble(),
                        (a["color"] as Number).toInt(),
                        (a["outlineColor"] as Number).toInt(),
                        (a["outlineWidth"] as Number).toDouble(),
                        a["locked"] as Boolean,
                        a["portrait"] as Boolean,
                        (a["portraitWidthDp"] as Number).toDouble(),
                    )
                    result.success(null)
                }
                "update" -> {
                    val a = call.arguments as Map<*, *>
                    overlay?.update(a["text"] as String)
                    result.success(null)
                }
                "setLocked" -> {
                    val a = call.arguments as Map<*, *>
                    overlay?.setLocked(a["locked"] as Boolean)
                    result.success(null)
                }
                "setStyle" -> {
                    val a = call.arguments as Map<*, *>
                    overlay?.setStyle(
                        (a["fontSize"] as Number).toDouble(),
                        (a["color"] as Number).toInt(),
                        (a["outlineColor"] as Number).toInt(),
                        (a["outlineWidth"] as Number).toDouble(),
                    )
                    result.success(null)
                }
                "hide" -> {
                    overlay?.hide()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // 电池优化白名单（后台播放不被省电策略中断）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kikoeta/battery_optimization",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                        }
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true) // 低版本无省电优化限制
                    }
                }
                else -> result.notImplemented()
            }
        }
        // 通知权限（Android 13+ 媒体通知/锁屏卡片）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kikoeta/notification",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        result.success(
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED,
                        )
                    } else {
                        result.success(true)
                    }
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            1001,
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---------------- Media3 媒体会话桥接 ----------------
    private fun registerMedia3(flutterEngine: FlutterEngine) {
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kikoeta/media3",
        )
        // 会话控制命令 → Dart（mpv 执行）
        Media3Bridge.commandSender = { action, positionMs ->
            try {
                ch.invokeMethod("command", mapOf("action" to action, "positionMs" to positionMs))
            } catch (_: Exception) {}
        }
        Media3Bridge.player?.onCommand = Media3Bridge.commandSender
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureSession" -> {
                    // 与 Kikoeru 一致：先在前台 Activity 中创建 MediaSessionService，
                    // 再由 Media3 Provider 在真实播放状态到达时提升为前台服务。
                    startService(Intent(this, KikoetaMediaSessionService::class.java))
                    result.success(null)
                }
                "updateState" -> {
                    val a = call.arguments as Map<*, *>
                    val playing = a["isPlaying"] == true
                    val pos = (a["positionMs"] as Number).toLong()
                    val dur = (a["durationMs"] as Number).toLong()
                    val title = a["title"] as String? ?: ""
                    val artist = a["artist"] as String? ?: ""
                    val artworkKey = a["artworkKey"] as String?
                    val mediaId = a["mediaId"] as String? ?: ""
                    val hideCard = a["hideCard"] == true
                    val logoCover = a["logoCover"] == true
                    val state = Media3Bridge.PendingState(
                        playing, pos, dur, title, artist, artworkKey, mediaId, hideCard, logoCover,
                    )
                    // 始终保留最近状态：服务刚创建时需要回放，而异步封面也需要据此丢弃旧结果。
                    Media3Bridge.pendingState = state
                    val p = Media3Bridge.player
                    if (p != null) {
                        // 隐藏卡片时让 Media3 看到空播放列表，由 Provider 自行移除通知。
                        p.updateState(
                            playing, pos, dur,
                            if (hideCard) "" else title,
                            artist, artworkKey, mediaId, logoCover,
                        )
                    }
                    result.success(null)
                }
                "updateArtwork" -> {
                    val a = call.arguments as Map<*, *>
                    val mediaId = a["mediaId"] as String? ?: ""
                    val artworkKey = a["artworkKey"] as String? ?: ""
                    val artworkPath = a["artworkPath"] as String? ?: ""
                    Media3Bridge.onArtworkCached?.invoke(mediaId, artworkKey, artworkPath)
                    result.success(null)
                }
                "clearSession" -> {
                    Media3Bridge.player?.clearSession()
                    Media3Bridge.pendingState = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---------------- 音频控制（拔出耳机暂停 / 音频焦点） ----------------
    private fun registerAudioControl(flutterEngine: FlutterEngine) {
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
                    registerReceiver(earPauseReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(earPauseReceiver, filter)
                }
            }
        } else {
            earPauseReceiver?.let { unregisterReceiver(it) }
            earPauseReceiver = null
        }
    }

    /** 音频焦点：默认响应（被抢占时暂停）；开启「忽略」后不请求、不响应 */
    private fun setIgnoreAudioFocus(ignore: Boolean) {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        if (ignore) {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(audioFocusListener)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
    }
}
