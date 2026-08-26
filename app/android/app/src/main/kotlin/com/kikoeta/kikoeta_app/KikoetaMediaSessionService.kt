package com.kikoeta.kikoeta_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Media3 媒体会话前台服务。
 *
 * 与 Kikoeru 3.0.9 一样，通知和前台服务均由 MediaSessionService 的 Media3
 * Provider 根据 Player 状态托管。这样最终通知会使用平台 MediaSession token 和
 * Notification.MediaStyle，而不是由应用手工拼装 NotificationCompat 媒体通知。
 * Dart/mpv 仍是实际播放端，BridgePlayer 只负责把同一份状态和控制命令桥接给 Media3。
 */
@UnstableApi
class KikoetaMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        DefaultMediaNotificationProvider(this).also { provider ->
            provider.setSmallIcon(R.drawable.ic_play_arrow)
            setMediaNotificationProvider(provider)
        }
        try {
            val player = BridgePlayer(this).also { Media3Bridge.player = it }
            player.onCommand = Media3Bridge.commandSender
            Media3Bridge.pendingState?.let { state ->
                player.updateState(
                    state.isPlaying,
                    state.positionMs,
                    state.durationMs,
                    if (state.hideCard) "" else state.title,
                    state.artist,
                    state.artworkKey,
                    state.mediaId,
                    state.logoCover,
                )
            }
            val session = MediaSession.Builder(this, player)
                .setSessionActivity(createSessionPendingIntent())
                .build()
            mediaSession = session
            // Provider 只跟踪显式加入服务的会话；仅从 onGetSession 返回不会触发前台媒体通知。
            addSession(session)
        } catch (_: Throwable) {
            Media3Bridge.player = null
            mediaSession = null
        }

        Media3Bridge.onArtworkCached = { mediaId, artworkKey, artworkPath ->
            loadArtworkFromCache(artworkPath) { bitmap ->
                mainHandler.post {
                    val state = Media3Bridge.pendingState
                    if (bitmap == null || state == null || state.hideCard || state.logoCover ||
                        mediaId != state.mediaId || artworkKey != state.artworkKey
                    ) {
                        return@post
                    }
                    Media3Bridge.player?.updateArtwork(artworkKey, bitmap)
                }
            }
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? =
        mediaSession

    /** 只读取 Flutter/Rust 写入的私有缓存，避免原生层重复访问远程封面 URL。 */
    private fun loadArtworkFromCache(path: String, onLoaded: (Bitmap?) -> Unit) {
        Thread {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, options)
            if (options.outWidth <= 0 || options.outHeight <= 0) {
                onLoaded(null)
                return@Thread
            }
            val sampleOptions = BitmapFactory.Options().apply {
                var sample = 1
                while (options.outWidth / sample > 1024 || options.outHeight / sample > 1024) {
                    sample *= 2
                }
                inSampleSize = sample
            }
            onLoaded(BitmapFactory.decodeFile(path, sampleOptions))
        }.start()
    }

    private fun createSessionPendingIntent() = android.app.PendingIntent.getActivity(
        this,
        0,
        packageManager.getLaunchIntentForPackage(packageName)
            ?: android.content.Intent(this, MainActivity::class.java),
        android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT,
    )

    override fun onDestroy() {
        try {
            mediaSession?.run {
                removeSession(this)
                player.release()
                release()
            }
        } catch (_: Throwable) {}
        mediaSession = null
        Media3Bridge.player = null
        Media3Bridge.onArtworkCached = null
        super.onDestroy()
    }
}

/** 会话桥接的静态持有：MainActivity 注入状态与命令回调。 */
object Media3Bridge {
    var player: BridgePlayer? = null

    /** 把 MediaSession 控制命令转发给 Dart（mpv 执行）。 */
    var commandSender: ((String, Long) -> Unit)? = null

    /** Flutter/Rust 写完封面缓存后的本地路径。 */
    var onArtworkCached: ((mediaId: String, artworkKey: String, artworkPath: String) -> Unit)? =
        null

    /** 最近一次状态，既用于服务延迟创建时回放，也用于过滤异步封面结果。 */
    data class PendingState(
        val isPlaying: Boolean,
        val positionMs: Long,
        val durationMs: Long,
        val title: String,
        val artist: String,
        val artworkKey: String?,
        val mediaId: String,
        val hideCard: Boolean,
        val logoCover: Boolean,
    )

    var pendingState: PendingState? = null
}
