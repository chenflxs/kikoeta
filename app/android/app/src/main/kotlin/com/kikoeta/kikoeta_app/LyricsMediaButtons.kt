package com.kikoeta.kikoeta_app

import android.content.Context
import android.os.Bundle
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.SessionCommand
import com.google.common.collect.ImmutableList

data class LyricsMediaState(
    val enabled: Boolean = false,
    val locked: Boolean = false,
    val lockLabel: String = "Lock lyrics",
    val toggleLabel: String = "Show lyrics",
)

@UnstableApi
object LyricsMediaButtons {
    val lockCommand = SessionCommand("kikoeta.lyrics.lock", Bundle.EMPTY)
    val toggleCommand = SessionCommand("kikoeta.lyrics.toggle", Bundle.EMPTY)

    fun build(state: LyricsMediaState): ImmutableList<CommandButton> = ImmutableList.of(
        CommandButton.Builder(CommandButton.ICON_UNDEFINED)
            .setCustomIconResId(if (state.locked) R.drawable.ic_lyrics_lock else R.drawable.ic_lyrics_unlock)
            .setDisplayName(state.lockLabel)
            .setSessionCommand(lockCommand)
            .setSlots(CommandButton.SLOT_BACK_SECONDARY, CommandButton.SLOT_OVERFLOW)
            .build(),
        CommandButton.Builder(
            if (state.enabled) CommandButton.ICON_SUBTITLES else CommandButton.ICON_SUBTITLES_OFF,
        )
            .setDisplayName(state.toggleLabel)
            .setSessionCommand(toggleCommand)
            .setSlots(CommandButton.SLOT_FORWARD_SECONDARY, CommandButton.SLOT_OVERFLOW)
            .build(),
    )
}

/** Keep Media3's actions and compact transport controls, ordering the expanded legacy card. */
@UnstableApi
class LyricsMediaNotificationProvider(context: Context) : DefaultMediaNotificationProvider(context) {
    override fun getMediaButtons(
        session: MediaSession,
        playerCommands: Player.Commands,
        mediaButtonPreferences: ImmutableList<CommandButton>,
        showPauseButton: Boolean,
    ): ImmutableList<CommandButton> {
        val defaults = super.getMediaButtons(session, playerCommands, mediaButtonPreferences, showPauseButton)
        val lock = defaults.firstOrNull { it.sessionCommand == LyricsMediaButtons.lockCommand }
        val toggle = defaults.firstOrNull { it.sessionCommand == LyricsMediaButtons.toggleCommand }
        return ImmutableList.builder<CommandButton>().apply {
            lock?.let { add(it) }
            addAll(defaults.filter { it !== lock && it !== toggle })
            toggle?.let { add(it) }
        }.build()
    }
}
