package com.kikoeta.kikoeta_app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

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
    private var lyricsState: LyricsMediaState? = null
    private var foregroundStartDeferred = false

    override fun onCreate() {
        super.onCreate()
        setListener(object : MediaSessionService.Listener {
            override fun onForegroundServiceStartNotAllowedException() {
                foregroundStartDeferred = true
            }
        })
        LyricsMediaNotificationProvider(this).also { provider ->
            provider.setSmallIcon(R.drawable.ic_play_arrow)
            setMediaNotificationProvider(provider)
        }
        try {
            val player = BridgePlayer(this)
            player.onCommand = Media3Bridge.commandSender
            player.onPlaybackRateChanged = Media3Bridge.playbackRateSender
            Media3Bridge.pendingState?.let(player::updateState)
            val session = MediaSession.Builder(this, player)
                .setSessionActivity(createSessionPendingIntent())
                .setCallback(object : MediaSession.Callback {
                    override fun onConnect(
                        session: MediaSession,
                        controller: MediaSession.ControllerInfo,
                    ): MediaSession.ConnectionResult = MediaSession.ConnectionResult.AcceptedResultBuilder(session)
                        .setAvailableSessionCommands(
                            MediaSession.ConnectionResult.DEFAULT_SESSION_COMMANDS.buildUpon()
                                .add(LyricsMediaButtons.lockCommand)
                                .add(LyricsMediaButtons.toggleCommand)
                                .build(),
                        )
                        .build()

                    override fun onCustomCommand(
                        session: MediaSession,
                        controller: MediaSession.ControllerInfo,
                        customCommand: SessionCommand,
                        args: Bundle,
                    ): ListenableFuture<SessionResult> {
                        val action = when (customCommand.customAction) {
                            LyricsMediaButtons.lockCommand.customAction -> "lyricsLock"
                            LyricsMediaButtons.toggleCommand.customAction -> "lyricsToggle"
                            else -> return Futures.immediateFuture(SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED))
                        }
                        val sender = Media3Bridge.commandSender
                            ?: return Futures.immediateFuture(SessionResult(SessionResult.RESULT_ERROR_INVALID_STATE))
                        sender(action, -1L)
                        return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
                    }
                })
                .setMediaButtonPreferences(LyricsMediaButtons.build(
                    Media3Bridge.pendingState?.lyrics ?: LyricsMediaState(),
                ))
                .build()
            mediaSession = session
            lyricsState = Media3Bridge.pendingState?.lyrics ?: LyricsMediaState()
            Media3Bridge.onLyricsStateChanged = { state ->
                if (state != lyricsState) {
                    lyricsState = state
                    mediaSession?.setMediaButtonPreferences(LyricsMediaButtons.build(state))
                }
            }
            // Provider 只跟踪显式加入服务的会话；仅从 onGetSession 返回不会触发前台媒体通知。
            addSession(session)
            Media3Bridge.player = player
            Media3Bridge.onActivityResumed = {
                if (foregroundStartDeferred && session.player.isPlaying) {
                    try {
                        onUpdateNotification(session, /* startInForegroundRequired = */ true)
                        foregroundStartDeferred = false
                    } catch (e: IllegalStateException) {
                        Log.w("KikoetaMedia3", "Media session foreground promotion deferred", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("KikoetaMedia3", "Could not initialize media session", e)
            mediaSession?.release()
            Media3Bridge.player = null
            mediaSession = null
            stopSelf()
            return
        }

        Media3Bridge.onArtworkCached = { artworkKey, artworkPath ->
            loadArtworkFromCache(artworkPath) { bitmap ->
                mainHandler.post {
                    val state = Media3Bridge.pendingState
                    if (bitmap == null || state == null || state.hideCard || state.logoCover ||
                        artworkKey != state.artworkKey
                    ) {
                        bitmap?.recycle()
                        return@post
                    }
                    try {
                        Media3Bridge.player?.updateArtwork(artworkKey, bitmap)
                    } finally {
                        bitmap.recycle()
                    }
                }
            }
        }
        Media3Bridge.replayArtwork()
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
        Media3Bridge.onLyricsStateChanged = null
        Media3Bridge.onActivityResumed = null
        super.onDestroy()
    }
}

/** 会话桥接的静态持有：MainActivity 注入状态与命令回调。 */
object Media3Bridge {
    var player: BridgePlayer? = null
    private var nextStartAttemptMs = 0L
    private var backgroundStartDeferred = false
    private var cachedArtwork: Pair<String, String>? = null

    /** 把 MediaSession 控制命令转发给 Dart（mpv 执行）。 */
    var commandSender: ((String, Long) -> Unit)? = null

    var playbackRateSender: ((Float) -> Unit)? = null
    var onLyricsStateChanged: ((LyricsMediaState) -> Unit)? = null
    var onActivityResumed: (() -> Unit)? = null

    /** Flutter/Rust 写完封面缓存后的本地路径。 */
    var onArtworkCached: ((artworkKey: String, artworkPath: String) -> Unit)? =
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
        val playbackRate: Float,
        val playbackSpeedEnabled: Boolean,
        val lyrics: LyricsMediaState,
    )

    var pendingState: PendingState? = null
        private set

    fun publishState(
        context: Context,
        state: PendingState,
        activityVisible: Boolean,
        activityResumed: Boolean,
    ) {
        pendingState = state
        if (state.hideCard || state.logoCover || cachedArtwork?.first != state.artworkKey) {
            cachedArtwork = null
        }
        val activePlayer = player
        if (activePlayer != null) {
            onLyricsStateChanged?.invoke(state.lyrics)
            activePlayer.updateState(state)
            if (activityResumed) onActivityResumed?.invoke()
            return
        }
        if (activityVisible) backgroundStartDeferred = false
        if (state.hideCard ||
            (!activityVisible && (!state.isPlaying || backgroundStartDeferred))
        ) return
        // startService is asynchronous. Coalesce requests until onCreate, and allow a fresh
        // attempt on foreground return if Android denied starting from the background.
        val now = SystemClock.elapsedRealtime()
        if (!activityResumed && now < nextStartAttemptMs) return
        nextStartAttemptMs = now + 2000
        try {
            context.startService(Intent(context, KikoetaMediaSessionService::class.java))
        } catch (e: IllegalStateException) {
            backgroundStartDeferred = !activityVisible
            Log.w("KikoetaMedia3", "Media session start deferred", e)
        }
    }

    fun publishArtwork(artworkKey: String, path: String) {
        val state = pendingState ?: return
        if (state.hideCard || state.logoCover || state.artworkKey != artworkKey) return
        cachedArtwork = artworkKey to path
        onArtworkCached?.invoke(artworkKey, path)
    }

    fun replayArtwork() {
        cachedArtwork?.let { (key, path) -> onArtworkCached?.invoke(key, path) }
    }

    fun clearSession() {
        pendingState = null
        cachedArtwork = null
        player?.clearSession()
    }
}
