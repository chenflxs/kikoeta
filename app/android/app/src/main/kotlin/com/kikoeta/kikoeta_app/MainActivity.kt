package com.kikoeta.kikoeta_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var overlay: LyricsOverlay? = null
    private var lyricsFolderImport: LyricsFolderImport? = null

    // Playback outlives the Activity. Reuse its Dart isolate and mpv owner on
    // re-entry instead of leaving the native player behind in a destroyed engine.
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(PLAYBACK_ENGINE)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    companion object {
        private const val PLAYBACK_ENGINE = "kikoeta-playback"
    }

    override fun onDestroy() {
        // Application overlays are independent of the Activity window. Explicitly remove the
        // lyrics view while this Activity still owns its WindowManager; otherwise a process kept
        // alive by the battery-optimization exemption can leave it behind across app restarts.
        overlay?.dispose()
        overlay = null
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Only the UI channels belong to this Activity. Audio + Media3 continue
        // running on the cached engine while it has no attached window.
        for (name in listOf("kikoeta/lyrics_overlay", "kikoeta/battery_optimization",
            "kikoeta/notification", LyricsFolderImport.CHANNEL)) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, name)
                .setMethodCallHandler(null)
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** SAF 文件夹选择结果（歌词库文件夹导入）。 */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (lyricsFolderImport?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(PLAYBACK_ENGINE, flutterEngine)
        PlaybackAudioControl.register(applicationContext, flutterEngine)
        DefaultNetworkObserver.register(applicationContext, flutterEngine)
        registerMedia3(flutterEngine)
        lyricsFolderImport = LyricsFolderImport(this).also { it.register(flutterEngine) }
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
        val appContext = applicationContext
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
        Media3Bridge.playbackRateSender = { rate ->
            try {
                ch.invokeMethod("setPlaybackRate", mapOf("rate" to rate))
            } catch (_: Exception) {}
        }
        Media3Bridge.player?.onPlaybackRateChanged = Media3Bridge.playbackRateSender
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
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
                    val playbackRate = (a["playbackRate"] as? Number)?.toFloat() ?: 1f
                    val playbackSpeedEnabled = a["playbackSpeedEnabled"] == true
                    val state = Media3Bridge.PendingState(
                        playing, pos, dur, title, artist, artworkKey, mediaId, hideCard, logoCover,
                        playbackRate, playbackSpeedEnabled,
                        LyricsMediaState(
                            enabled = a["lyricsEnabled"] == true,
                            locked = a["lyricsLocked"] == true,
                            lockLabel = a["lyricsLockLabel"] as String? ?: "Lock lyrics",
                            toggleLabel = a["lyricsToggleLabel"] as String? ?: "Show lyrics",
                        ),
                    )
                    Media3Bridge.publishState(
                        appContext, state,
                        activityVisible = a["activityVisible"] == true,
                        activityResumed = a["activityResumed"] == true,
                    )
                    result.success(null)
                }
                "updateArtwork" -> {
                    val a = call.arguments as Map<*, *>
                    val artworkKey = a["artworkKey"] as String? ?: ""
                    val artworkPath = a["artworkPath"] as String? ?: ""
                    Media3Bridge.publishArtwork(artworkKey, artworkPath)
                    result.success(null)
                }
                "clearSession" -> {
                    Media3Bridge.clearSession()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
