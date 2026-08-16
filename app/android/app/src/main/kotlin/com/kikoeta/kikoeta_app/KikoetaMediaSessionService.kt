package com.kikoeta.kikoeta_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Media3 媒体会话前台服务：
 * 提供锁屏媒体卡片与通知栏控制，播放状态由 BridgePlayer 桥接 mpv。
 * 通知由本服务手动构建并 startForeground（不依赖 media3 自动 Provider 的 controller 激活机制）。
 */
@UnstableApi
class KikoetaMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private var lastTitle = ""
    // 「通知栏封面显示项目 logo」开关的上次状态（异步封面加载完成时据此放弃替换）
    private var lastLogoCover = false

    companion object {
        private const val NOTIF_ID = 1001
        private const val CHANNEL_ID = "kikoeta_media"
        const val ACTION_PLAY = "com.kikoeta.action.PLAY"
        const val ACTION_PAUSE = "com.kikoeta.action.PAUSE"
        const val ACTION_NEXT = "com.kikoeta.action.NEXT"
        const val ACTION_PREV = "com.kikoeta.action.PREV"
        const val ACTION_STOP = "com.kikoeta.action.STOP"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // 会话在服务创建时立即建立
        try {
            val player = BridgePlayer(this).also { Media3Bridge.player = it }
            player.onCommand = Media3Bridge.commandSender
            Media3Bridge.pendingState?.let { s ->
                player.updateState(
                    s.isPlaying, s.positionMs, s.durationMs,
                    s.title, s.artist, s.artworkUrl, s.mediaId,
                )
            }
            mediaSession = MediaSession.Builder(this, player)
                .setSessionActivity(createSessionPendingIntent())
                .build()
        } catch (t: Throwable) {
            Media3Bridge.player = null
            mediaSession = null
        }
        // Dart 状态上报 → 更新/隐藏通知
        Media3Bridge.onStateChanged = { playing, title, artist, artworkUrl, hideCard, logoCover ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                if (title.isEmpty() || hideCard) {
                    hideMediaNotification()
                } else {
                    showMediaNotification(playing, title, artist, artworkUrl, logoCover)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> Media3Bridge.commandSender?.invoke("play", -1)
            ACTION_PAUSE -> Media3Bridge.commandSender?.invoke("pause", -1)
            ACTION_NEXT -> Media3Bridge.commandSender?.invoke("next", -1)
            ACTION_PREV -> Media3Bridge.commandSender?.invoke("previous", -1)
            ACTION_STOP -> Media3Bridge.commandSender?.invoke("stop", -1)
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? =
        mediaSession

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "媒体播放",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    /** 构建媒体通知并进入前台（关联 MediaSession → 系统标准媒体卡片 + 控制中心/锁屏） */
    private fun showMediaNotification(
        playing: Boolean,
        title: String,
        artist: String,
        artworkUrl: String?,
        logoCover: Boolean,
    ) {
        lastTitle = title
        lastLogoCover = logoCover
        val contentIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val prev = mediaAction(ACTION_PREV, R.drawable.ic_skip_previous, "上一首")
        val pp = mediaAction(
            if (playing) ACTION_PAUSE else ACTION_PLAY,
            if (playing) R.drawable.ic_pause else R.drawable.ic_play_arrow,
            if (playing) "暂停" else "播放",
        )
        val next = mediaAction(ACTION_NEXT, R.drawable.ic_skip_next, "下一首")
        val style = androidx.media.app.NotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
        // 关联 MediaSession：系统识别为标准媒体卡片（控制中心/锁屏/进度条）
        try {
            mediaSession?.sessionCompatToken?.let { style.setMediaSession(it) }
        } catch (_: Throwable) {}
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_play_arrow)
            .setContentTitle(title)
            .setContentText(artist)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setStyle(style)
            .addAction(prev)
            .addAction(pp)
            .addAction(next)
        // 封面：开启「通知栏封面显示项目 logo」时封面位置固定显示项目 logo
        //（项目暂无 logo，暂用 ic_launcher 占位图代替）；
        // 关闭时显示真实封面——先以 logo 占位保证必定显示，
        // 真实封面异步加载成功后替换（加载失败则保留占位）
        val logo = runCatching {
            android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        }.getOrNull()
        if (logo != null) builder.setLargeIcon(logo)
        if (!logoCover && artworkUrl != null && artworkUrl.isNotEmpty()) {
            // 真实封面（异步加载，加载完更新通知；期间开关若被打开则放弃替换）
            loadArtwork(artworkUrl) { bmp ->
                if (bmp != null && lastTitle == title && !lastLogoCover) {
                    val updated = builder.setLargeIcon(bmp).build()
                    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                        .notify(NOTIF_ID, updated)
                }
            }
        }
        startForeground(NOTIF_ID, builder.build())
    }

    /** 后台线程下载封面 */
    private fun loadArtwork(url: String, onLoaded: (android.graphics.Bitmap?) -> Unit) {
        Thread {
            var bmp: android.graphics.Bitmap? = null
            try {
                val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.instanceFollowRedirects = true
                val stream = conn.inputStream
                bmp = android.graphics.BitmapFactory.decodeStream(stream)
                stream.close()
                conn.disconnect()
            } catch (_: Exception) {}
            onLoaded(bmp)
        }.start()
    }

    private fun hideMediaNotification() {
        lastTitle = ""
        stopForeground(STOP_FOREGROUND_REMOVE)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(NOTIF_ID)
    }

    private fun mediaAction(action: String, iconRes: Int, label: String): NotificationCompat.Action {
        val pi = PendingIntent.getService(
            this, action.hashCode(),
            Intent(this, KikoetaMediaSessionService::class.java).setAction(action),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Action(iconRes, label, pi)
    }

    private fun createSessionPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    override fun onDestroy() {
        try {
            mediaSession?.run {
                player.release()
                release()
            }
        } catch (_: Throwable) {}
        mediaSession = null
        Media3Bridge.player = null
        Media3Bridge.onStateChanged = null
        super.onDestroy()
    }
}

/** 会话桥接的静态持有：MainActivity 注入状态与命令回调 */
object Media3Bridge {
    var player: BridgePlayer? = null

    /** 把 MediaSession 控制命令转发给 Dart（mpv 执行） */
    var commandSender: ((String, Long) -> Unit)? = null

    /** 状态上报回调（Service 注册：更新/隐藏媒体通知） */
    var onStateChanged:
        ((playing: Boolean, title: String, artist: String, artworkUrl: String?, hideCard: Boolean, logoCover: Boolean) -> Unit)? =
        null

    /** Service 尚未创建时的待同步状态（Dart 先于 Service 上报） */
    data class PendingState(
        val isPlaying: Boolean,
        val positionMs: Long,
        val durationMs: Long,
        val title: String,
        val artist: String,
        val artworkUrl: String?,
        val mediaId: String,
        val hideCard: Boolean,
        val logoCover: Boolean,
    )

    var pendingState: PendingState? = null
}
