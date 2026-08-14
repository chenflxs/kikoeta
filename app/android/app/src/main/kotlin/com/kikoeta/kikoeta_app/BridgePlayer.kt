package com.kikoeta.kikoeta_app

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Media3 桥接播放器（会话门面）：
 * 真实播放由 Dart 侧 mpv 执行；本类只向 MediaSession 提供状态与命令转发。
 */
@UnstableApi
class BridgePlayer(context: Context) : SimpleBasePlayer(context.mainLooper) {
    private var isPlaying = false
    private var positionMs = 0L
    private var bufferedMs = 0L
    private var durationMs = C.TIME_UNSET
    private var title = ""
    private var artist = ""
    private var artworkUrl: String? = null
    private var mediaId = ""
    private var released = false

    /** 控制命令回调（由 MainActivity 注入，转发给 Dart） */
    var onCommand: ((action: String, positionMs: Long) -> Unit)? = null

    private fun sendCommand(action: String, positionMs: Long = -1) {
        onCommand?.invoke(action, positionMs)
    }

    /** Dart 上报播放状态，刷新会话（通知/锁屏卡片） */
    fun updateState(
        playing: Boolean,
        positionMs: Long,
        durationMs: Long,
        title: String,
        artist: String,
        artworkUrl: String?,
        mediaId: String,
    ) {
        this.isPlaying = playing
        this.positionMs = positionMs
        this.bufferedMs = positionMs
        this.durationMs = if (durationMs > 0) durationMs else C.TIME_UNSET
        this.title = title
        this.artist = artist
        this.artworkUrl = artworkUrl
        this.mediaId = mediaId
        if (!released) {
            try {
                invalidateState()
            } catch (_: Throwable) {}
        }
    }

    /** 清空会话（播放结束/停止时） */
    fun clearSession() {
        isPlaying = false
        positionMs = 0
        bufferedMs = 0
        durationMs = C.TIME_UNSET
        title = ""
        artist = ""
        artworkUrl = null
        mediaId = ""
        if (!released) {
            try {
                invalidateState()
            } catch (_: Throwable) {}
        }
    }

    override fun getState(): State {
        try {
            val commands = Player.Commands.Builder()
                .add(Player.COMMAND_PLAY_PAUSE)
                .add(Player.COMMAND_STOP)
                .add(Player.COMMAND_SEEK_TO_PREVIOUS)
                .add(Player.COMMAND_SEEK_TO_NEXT)
                .add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                .add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
                .add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
                .add(Player.COMMAND_SET_SPEED_AND_PITCH)
                .build()
            val builder = State.Builder()
                .setAvailableCommands(commands)
                .setPlayWhenReady(
                    isPlaying,
                    Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST,
                )
                // 有曲目即 READY（暂停时通知/锁屏卡片保持显示，仅状态变暂停）
                .setPlaybackState(if (title.isEmpty()) Player.STATE_IDLE else Player.STATE_READY)
                .setContentPositionMs(positionMs)
                .setTotalBufferedDurationMs(PositionSupplier.getConstant(bufferedMs))
            if (title.isNotEmpty()) {
                val mediaItem = MediaItem.Builder()
                    .setMediaId(mediaId.ifEmpty { title })
                    .setMediaMetadata(
                        MediaMetadata.Builder()
                            .setTitle(title)
                            .setArtist(artist)
                            .setArtworkUri(artworkUrl?.let { Uri.parse(it) })
                            .build(),
                    )
                    .build()
                builder
                    .setPlaylist(
                        listOf(
                            MediaItemData.Builder(Any())
                                .setMediaItem(mediaItem)
                                .setIsSeekable(durationMs != C.TIME_UNSET && durationMs > 0)
                            .setIsDynamic(false)
                            .build(),
                    ),
                )
                .setCurrentMediaItemIndex(0)
            }
            return builder.build()
        } catch (t: Throwable) {
            // 状态构造异常：返回最小可用状态，避免崩溃
            return State.Builder()
                .setAvailableCommands(Player.Commands.Builder().build())
                .setPlaybackState(Player.STATE_IDLE)
                .setPlayWhenReady(false, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
                .build()
        }
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        sendCommand(if (playWhenReady) "play" else "pause")
        return Futures.immediateVoidFuture()
    }

    override fun handleStop(): ListenableFuture<*> {
        sendCommand("stop")
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        seekCommand: Int,
    ): ListenableFuture<*> {
        when (seekCommand) {
            Player.COMMAND_SEEK_TO_NEXT,
            Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> sendCommand("next")
            Player.COMMAND_SEEK_TO_PREVIOUS,
            Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> sendCommand("previous")
            else -> sendCommand("seekTo", positionMs)
        }
        return Futures.immediateVoidFuture()
    }

    override fun handleRelease(): ListenableFuture<*> {
        released = true
        return Futures.immediateVoidFuture()
    }
}
