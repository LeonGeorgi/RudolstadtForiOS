@file:OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import coil3.compose.AsyncImagePainter
import coil3.request.ImageRequest
import coil3.request.crossfade
import de.leongeorgi.rudolstadt.festival.ProgramArtist

/** Shared image states keep slow or unavailable festival-network images intentional. */
@Composable
internal fun FestivalPhoto(
    url: String?,
    description: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
) {
    var state by
        remember(url) { mutableStateOf<AsyncImagePainter.State>(AsyncImagePainter.State.Empty) }
    val context = LocalContext.current
    val request =
        remember(url, context) {
            ImageRequest.Builder(context).data(url).crossfade(true).build()
        }
    Box(
        modifier.background(MaterialTheme.colorScheme.surfaceContainerHigh),
        contentAlignment = Alignment.Center,
    ) {
        AsyncImage(
            model = request,
            contentDescription = description,
            modifier = Modifier.matchParentSize(),
            contentScale = contentScale,
            onState = { state = it },
        )
        if (url == null || state is AsyncImagePainter.State.Error)
            Icon(
                Icons.Default.Groups,
                null,
                Modifier.size(40.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        else if (state !is AsyncImagePainter.State.Success) LoadingIndicator(Modifier.size(36.dp))
    }
}

@Composable
internal fun ArtistPhoto(
    artist: ProgramArtist,
    modifier: Modifier = Modifier,
    fullSize: Boolean = false,
    description: String? = artist.name,
) {
    FestivalPhoto(
        if (fullSize) artist.content.image ?: artist.content.thumbnail
        else artist.content.thumbnail ?: artist.content.image,
        description,
        modifier,
    )
}

@Composable
internal fun ArtistPhotoViewer(artist: ProgramArtist, dismiss: () -> Unit) {
    Dialog(
        onDismissRequest = dismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(Modifier.fillMaxSize()) {
            var scale by remember { mutableFloatStateOf(1f) }
            var offset by remember { mutableStateOf(Offset.Zero) }
            BoxWithConstraints(Modifier.fillMaxSize().clipToBounds()) {
                val maxX = constraints.maxWidth.toFloat()
                val maxY = constraints.maxHeight.toFloat()
                val transform = rememberTransformableState { zoom, pan, _ ->
                    scale = (scale * zoom).coerceIn(1f, 5f)
                    offset =
                        Offset(
                            (offset.x + pan.x).coerceIn(
                                -maxX * (scale - 1) / 2,
                                maxX * (scale - 1) / 2,
                            ),
                            (offset.y + pan.y).coerceIn(
                                -maxY * (scale - 1) / 2,
                                maxY * (scale - 1) / 2,
                            ),
                        )
                }
                FestivalPhoto(
                    artist.content.image ?: artist.content.thumbnail,
                    artist.name,
                    Modifier.fillMaxSize().transformable(transform).graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        translationX = offset.x
                        translationY = offset.y
                    },
                    ContentScale.Fit,
                )
                Row(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(16.dp)) {
                    FilledTonalIconButton(
                        onClick = {
                            scale = 1f
                            offset = Offset.Zero
                        }
                    ) {
                        Icon(Icons.Default.ZoomOutMap, stringResource(R.string.reset_view))
                    }
                    Spacer(Modifier.width(8.dp))
                    FilledTonalIconButton(onClick = dismiss) {
                        Icon(Icons.Default.Close, stringResource(R.string.close))
                    }
                }
            }
        }
    }
}

internal val FestivalLightColors =
    lightColorScheme(
        primary = Color(0xFF782C74),
        onPrimary = Color.White,
        primaryContainer = Color(0xFFFFD6F4),
        onPrimaryContainer = Color(0xFF31072F),
        secondary = Color(0xFF6E586A),
        onSecondary = Color.White,
        secondaryContainer = Color(0xFFF8DAED),
        onSecondaryContainer = Color(0xFF271624),
        tertiary = Color(0xFF87513C),
        onTertiary = Color.White,
        tertiaryContainer = Color(0xFFFFDBCC),
        onTertiaryContainer = Color(0xFF321206),
    )

internal val FestivalDarkColors =
    darkColorScheme(
        primary = Color(0xFFECB0DF),
        onPrimary = Color(0xFF481342),
        primaryContainer = Color(0xFF62245B),
        onPrimaryContainer = Color(0xFFFFD6F4),
        secondary = Color(0xFFDBBED1),
        onSecondary = Color(0xFF3E2B3A),
        secondaryContainer = Color(0xFF564151),
        onSecondaryContainer = Color(0xFFF8DAED),
        tertiary = Color(0xFFFBB79B),
        onTertiary = Color(0xFF502512),
        tertiaryContainer = Color(0xFF6B3B26),
        onTertiaryContainer = Color(0xFFFFDBCC),
    )
