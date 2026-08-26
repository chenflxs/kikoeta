package com.kikoeta.kikoeta_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import androidx.media3.common.AudioAttributes
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
    private val appContext = context.applicationContext
    private var isPlaying = false
    private var positionMs = 0L
    private var bufferedMs = 0L
    private var durationMs = C.TIME_UNSET
    private var title = ""
    private var artist = ""
    private var artworkKey: String? = null
    private var artworkData: ByteArray? = null
    private var logoCover = false
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
        artworkKey: String?,
        mediaId: String,
        logoCover: Boolean,
    ) {
        this.isPlaying = playing
        this.positionMs = positionMs
        this.bufferedMs = positionMs
        this.durationMs = if (durationMs > 0) durationMs else C.TIME_UNSET
        this.title = title
        this.artist = artist
        if (this.mediaId != mediaId || this.artworkKey != artworkKey ||
            this.logoCover != logoCover
        ) {
            artworkData = null
        }
        this.artworkKey = artworkKey
        this.mediaId = mediaId
        this.logoCover = logoCover
        if (logoCover && artworkData == null) {
            artworkData = loadLogoArtwork()
        }
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
        artworkKey = null
        artworkData = null
        logoCover = false
        mediaId = ""
        if (!released) {
            try {
                invalidateState()
            } catch (_: Throwable) {}
        }
    }

    /** 将本地文件解码出的封面写入会话元数据，供不读取通知大图的系统使用。 */
    fun updateArtwork(artworkKey: String, bitmap: Bitmap) {
        if (released || logoCover || artworkKey != this.artworkKey) return
        val maxSide = 512
        val scale = maxOf(bitmap.width, bitmap.height).toFloat() / maxSide
        val scaled = if (scale > 1f) {
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width / scale).toInt().coerceAtLeast(1),
                (bitmap.height / scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            bitmap
        }
        artworkData = try {
            ByteArrayOutputStream().use { output ->
                for (quality in intArrayOf(88, 76, 64, 52)) {
                    output.reset()
                    scaled.compress(Bitmap.CompressFormat.JPEG, quality, output)
                    if (output.size() <= 512 * 1024) break
                }
                output.toByteArray()
            }
        } catch (_: Throwable) {
            null
        } finally {
            if (scaled !== bitmap) scaled.recycle()
        }
        if (artworkData != null) {
            try {
                invalidateState()
            } catch (_: Throwable) {}
        }
    }

    private fun loadLogoArtwork(): ByteArray? {
        val bitmap = runCatching {
            BitmapFactory.decodeResource(appContext.resources, R.mipmap.ic_launcher)
        }.getOrNull() ?: return null
        return try {
            ByteArrayOutputStream().use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                output.toByteArray()
            }
        } catch (_: Throwable) {
            null
        } finally {
            bitmap.recycle()
        }
    }

    override fun getState(): State {
        try {
            val commands = Player.Commands.Builder()
                // 这些读取命令决定 MediaSession 能否把曲目、元数据和播放位置暴露给平台。
                // 缺失时控制命令仍有效，但 AOSP 会话会显示 position=-1、metadata=null。
                .add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
                .add(Player.COMMAND_GET_TIMELINE)
                .add(Player.COMMAND_GET_MEDIA_ITEMS_METADATA)
                .add(Player.COMMAND_GET_METADATA)
                .add(Player.COMMAND_GET_AUDIO_ATTRIBUTES)
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
                .setAudioAttributes(AudioAttributes.DEFAULT)
                .setContentPositionMs(positionMs)
                .setContentBufferedPositionMs(PositionSupplier.getConstant(bufferedMs))
                .setTotalBufferedDurationMs(PositionSupplier.getConstant(bufferedMs))
            if (title.isNotEmpty()) {
                val metadata = MediaMetadata.Builder()
                    .setTitle(title)
                    .setArtist(artist)
                artworkData?.let {
                    metadata.setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
                }
                val mediaItem = MediaItem.Builder()
                    .setMediaId(mediaId.ifEmpty { title })
                    .setMediaMetadata(metadata.build())
                    .build()
                builder
                    .setPlaylist(
                        listOf(
                            MediaItemData.Builder(Any())
                                .setMediaItem(mediaItem)
                                // SimpleBasePlayer 的 Timeline 使用这里的 metadata，而非仅 MediaItem 内部字段。
                                .setMediaMetadata(metadata.build())
                                .setIsSeekable(durationMs != C.TIME_UNSET && durationMs > 0)
                                .setIsDynamic(false)
                                .setDurationUs(
                                    if (durationMs == C.TIME_UNSET) C.TIME_UNSET else durationMs * 1000,
                                )
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
