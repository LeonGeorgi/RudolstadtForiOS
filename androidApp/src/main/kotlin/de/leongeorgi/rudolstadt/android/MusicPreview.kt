package de.leongeorgi.rudolstadt.android

import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.media3.common.*
import androidx.media3.exoplayer.ExoPlayer
import de.leongeorgi.rudolstadt.android.data.text
import de.leongeorgi.rudolstadt.android.data.validWebURL
import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.loading.RemoteAPI
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

internal fun mediaParts(value: String): MediaURLParts? = runCatching {
    val uri = Uri.parse(value)
    MediaURLParts(
        uri.scheme,
        uri.host,
        uri.pathSegments,
        uri.queryParameterNames.flatMap { name ->
            uri.getQueryParameters(name).map { MediaParameter(name, it) }
        },
    )
}
    .getOrNull()

@Stable
internal class MusicPreviewState(val player: ExoPlayer) {
    var attempt by mutableIntStateOf(0)
    var selection by mutableStateOf<MusicPreviewSelection?>(null)
    var failed by mutableStateOf(false)
    var playing by mutableStateOf(false)
    var buffering by mutableStateOf(false)
    var position by mutableLongStateOf(0L)
    var duration by mutableLongStateOf(0L)
    val requested
        get() = attempt > 0

    fun toggle() {
        if (!requested || failed) {
            failed = false
            selection = null
            position = 0L
            duration = 0L
            buffering = false
            player.pause()
            attempt++
        } else if (playing) player.pause()
        else {
            if (player.playbackState == Player.STATE_ENDED) player.seekTo(0)
            player.play()
        }
    }
}

/** Owned by the screen so scrolling the media row offscreen does not stop playback. */
@Composable
internal fun rememberMusicPreview(artist: ProgramArtist): MusicPreviewState? {
    val reference =
        remember(artist) {
            if (artist.content.previewKind == "disabled") null
            else
                (artist.content.previewURL
                        ?: artist.content.links
                            .firstOrNull { it.linkID == "appleMusic" }
                            ?.destination)
                    ?.let(::mediaParts)
                    ?.let(MediaLinks::music)
        } ?: return null
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val state =
        remember(artist.artistID, reference, lifecycle) {
            MusicPreviewState(
                ExoPlayer.Builder(context).build().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(C.USAGE_MEDIA)
                            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                            .build(),
                        true,
                    )
                    setHandleAudioBecomingNoisy(true)
                }
            )
        }
    val player = state.player
    DisposableEffect(state, lifecycle) {
        val listener =
            object : Player.Listener {
                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    state.playing = isPlaying
                }

                override fun onPlayerError(error: PlaybackException) {
                    state.failed = true
                    state.buffering = false
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    state.buffering = playbackState == Player.STATE_BUFFERING
                }
            }
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE) player.pause()
        }
        player.addListener(listener)
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            player.removeListener(listener)
            player.release()
        }
    }
    LaunchedEffect(state, lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (isActive) {
                state.position = player.currentPosition.coerceAtLeast(0)
                state.duration = player.duration.coerceAtLeast(0)
                delay(250)
            }
        }
    }
    LaunchedEffect(state, state.attempt) {
        if (!state.requested) return@LaunchedEffect
        val remote = RemoteAPI()
        try {
            val preview = remote.musicPreview(reference) { validWebURL(it) != null }
            state.selection = preview
            if (preview == null) state.failed = true
            else {
                player.setMediaItem(MediaItem.fromUri(preview.audioURL))
                player.prepare()
                if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) player.play()
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            state.failed = true
        } finally {
            remote.close()
        }
    }
    return state
}

@Composable
internal fun MusicPreview(artist: ProgramArtist, state: MusicPreviewState?) {
    val links =
        remember(artist) {
            artist.content.links
                .filter {
                    mediaParts(it.destination)?.let(MediaLinks::youtube) == null
                }
                .sortedBy {
                    when (it.linkID) {
                        "appleMusic" -> 0
                        "spotify" -> 1
                        else -> 2
                    }
                }
        }
    if (state == null && links.isEmpty()) return
    var expanded by rememberSaveable(artist.artistID) { mutableStateOf(false) }
    var seeking by remember(artist.artistID) { mutableStateOf<Float?>(null) }
    val context = LocalContext.current
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp)) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (state != null) {
                val loading =
                    state.requested && (state.selection == null || state.buffering) && !state.failed
                val position =
                    stringResource(
                        R.string.preview_progress,
                        playbackTime(state.position),
                        playbackTime(state.duration),
                    )
                val label =
                    stringResource(
                        if (loading) R.string.preview_loading
                        else if (state.playing) R.string.pause else R.string.preview
                    )
                Button(
                    onClick = state::toggle,
                    modifier =
                        Modifier.width(
                                if (LocalDensity.current.fontScale >= 1.3f) 140.dp else 112.dp
                            )
                            .heightIn(min = 48.dp)
                            .semantics {
                                contentDescription = label
                                if (state.duration > 0) stateDescription = position
                            },
                    enabled = !state.requested || state.selection != null || state.failed,
                    contentPadding = PaddingValues(horizontal = 16.dp),
                ) {
                    if (loading)
                        CircularProgressIndicator(
                            Modifier.size(18.dp),
                            color = LocalContentColor.current,
                            strokeWidth = 2.dp,
                        )
                    else
                        Icon(
                            if (state.playing) Icons.Default.Pause else Icons.Default.PlayArrow,
                            null,
                            Modifier.size(20.dp),
                        )
                    Spacer(Modifier.width(12.dp))
                    LinearProgressIndicator(
                        progress = {
                            if (state.duration > 0)
                                (state.position.toFloat() / state.duration).coerceIn(0f, 1f)
                            else 0f
                        },
                        modifier = Modifier.weight(1f).height(4.dp).clearAndSetSemantics {},
                        color = LocalContentColor.current,
                        trackColor = LocalContentColor.current.copy(alpha = .28f),
                        drawStopIndicator = {},
                    )
                }
            }
            links.forEach { link ->
                val title =
                    when (link.linkID) {
                        "appleMusic" -> "Apple Music"
                        "spotify" -> "Spotify"
                        "url",
                        "website" -> stringResource(R.string.artist_website)
                        else -> link.titles.text(language).replaceFirstChar { it.titlecase() }
                    }
                FilledTonalIconButton(
                    onClick = { openURL(context, link.destination) },
                    modifier = Modifier.size(48.dp),
                    colors =
                        IconButtonDefaults.filledTonalIconButtonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                            contentColor = MaterialTheme.colorScheme.primary,
                        ),
                ) {
                    Icon(
                        when (link.linkID) {
                            "appleMusic",
                            "soundcloud" -> Icons.Default.MusicNote
                            "spotify" -> Icons.Default.GraphicEq
                            "url",
                            "website" -> Icons.Default.Language
                            "facebook" -> Icons.Default.Facebook
                            "instagram" -> ImageVector.vectorResource(R.drawable.ic_instagram)
                            else -> Icons.AutoMirrored.Filled.OpenInNew
                        },
                        title,
                    )
                }
            }
        }
        if (state != null) {
            Text(
                stringResource(R.string.preview_attribution),
                Modifier.padding(top = 5.dp),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            state.selection?.let { selection ->
                TextButton(onClick = { expanded = !expanded }, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "${selection.trackName} · ${playbackTime(state.position)} / ${playbackTime(state.duration)}",
                        Modifier.weight(1f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Icon(
                        if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        stringResource(
                            if (expanded) R.string.preview_hide_controls
                            else R.string.preview_show_controls
                        ),
                    )
                }
                if (expanded && state.duration > 0) {
                    val progressLabel = stringResource(R.string.preview_position)
                    Slider(
                        value =
                            seeking ?: (state.position.toFloat() / state.duration).coerceIn(0f, 1f),
                        onValueChange = { seeking = it },
                        onValueChangeFinished = {
                            seeking?.let { state.player.seekTo((it * state.duration).toLong()) }
                            seeking = null
                        },
                        modifier = Modifier.semantics { contentDescription = progressLabel },
                    )
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(
                            playbackTime(
                                seeking?.let { (it * state.duration).toLong() } ?: state.position
                            ),
                            style = MaterialTheme.typography.labelSmall,
                        )
                        Text(
                            playbackTime(state.duration),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                }
            }
            if (state.failed)
                Text(
                    stringResource(R.string.preview_error),
                    Modifier.padding(top = 8.dp),
                    color = MaterialTheme.colorScheme.error,
                )
        }
    }
}

internal fun playbackTime(milliseconds: Long): String {
    val seconds = milliseconds.coerceAtLeast(0) / 1000
    return "${seconds / 60}:${(seconds % 60).toString().padStart(2, '0')}"
}
