package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitLongPressOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.PersonOutline
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import de.leongeorgi.rudolstadt.discovery.ProgramInlineMention
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import kotlin.math.roundToInt

private data class ArtistLink(val start: Int, val end: Int, val artist: ProgramArtist)

private data class ArtistMenuAnchor(val link: ArtistLink, val bounds: Rect)

@Composable
internal fun NewsParagraph(
    text: AnnotatedString,
    mentions: Map<String, ProgramInlineMention>,
    style: TextStyle,
    inlineContent: Map<String, InlineTextContent>,
) {
    val artistLinks =
        remember(text, mentions) {
            text.getLinkAnnotations(0, text.length).mapNotNull { link ->
                val tag = (link.item as? LinkAnnotation.Clickable)?.tag ?: return@mapNotNull null
                val artist = mentions[tag]?.artist ?: return@mapNotNull null
                ArtistLink(link.start, link.end, artist)
            }
        }
    if (artistLinks.isEmpty()) {
        Text(text, style = style, inlineContent = inlineContent)
        return
    }

    var layout by remember(text) { mutableStateOf<TextLayoutResult?>(null) }
    var menu by remember(text) { mutableStateOf<ArtistMenuAnchor?>(null) }
    var expanded by remember(text) { mutableStateOf(false) }
    val highlight = MaterialTheme.colorScheme.secondaryContainer
    val density = LocalDensity.current
    val focusManager = LocalFocusManager.current

    LaunchedEffect(expanded) {
        if (expanded) focusManager.clearFocus(force = true)
    }

    fun showMenu(link: ArtistLink, textLayout: TextLayoutResult, line: Int) {
        val start = maxOf(link.start, textLayout.getLineStart(line))
        val end = minOf(link.end, textLayout.getLineEnd(line))
        menu = ArtistMenuAnchor(link, textLayout.getPathForRange(start, end).getBounds())
        expanded = true
    }

    val actions =
        artistLinks
            .distinctBy { it.artist.artistID }
            .map { link ->
                CustomAccessibilityAction(
                    stringResource(R.string.news_artist_actions, link.artist.name)
                ) {
                    val textLayout = layout ?: return@CustomAccessibilityAction false
                    showMenu(link, textLayout, textLayout.getLineForOffset(link.start))
                    true
                }
            }
    Box {
        Text(
            text,
            modifier =
                Modifier.semantics { customActions = actions }
                    .drawBehind {
                        val selected = menu?.link
                        if (expanded && selected != null) {
                            layout?.getPathForRange(selected.start, selected.end)?.let {
                                drawPath(it, highlight)
                            }
                        }
                    }
                    .pointerInput(artistLinks) {
                        awaitEachGesture {
                            val down = awaitFirstDown(pass = PointerEventPass.Initial)
                            val textLayout = layout ?: return@awaitEachGesture
                            val offset =
                                textLayout.characterAt(down.position) ?: return@awaitEachGesture
                            val link =
                                artistLinks.firstOrNull { offset in it.start until it.end }
                                    ?: return@awaitEachGesture
                            // Let the link handle its down event so taps retain native behavior.
                            awaitPointerEvent(PointerEventPass.Final)
                            awaitLongPressOrCancellation(down.id) ?: return@awaitEachGesture
                            showMenu(link, textLayout, textLayout.getLineForOffset(offset))
                            do {
                                val event = awaitPointerEvent(PointerEventPass.Initial)
                                event.changes.forEach { it.consume() }
                            } while (event.changes.any { it.pressed })
                        }
                    },
            style = style,
            inlineContent = inlineContent,
            onTextLayout = { layout = it },
        )
        menu?.let { anchor ->
            Box(
                Modifier.absoluteOffset {
                        IntOffset(
                            anchor.bounds.left.roundToInt(),
                            anchor.bounds.bottom.roundToInt(),
                        )
                    }
                    .width(with(density) { anchor.bounds.width.toDp() }.coerceAtLeast(1.dp))
                    .height(1.dp)
            ) {
                NewsArtistMenu(
                    anchor.link.artist,
                    expanded = expanded,
                    dismiss = { expanded = false },
                )
            }
        }
    }
}

private fun TextLayoutResult.characterAt(position: Offset): Int? {
    val nearest = getOffsetForPosition(position)
    // The caret can resolve to the next character when touching the right half of a glyph.
    return listOf(nearest, nearest - 1).firstOrNull {
        it in layoutInput.text.indices && getBoundingBox(it).contains(position)
    }
}

@Composable
private fun NewsArtistMenu(artist: ProgramArtist, expanded: Boolean, dismiss: () -> Unit) {
    val app = LocalApp.current
    val context = LocalContext.current
    val url = ArtistPublicLink(app.state.edition.year, artist.artistID).url()
    ExpressiveContextMenu(expanded, dismiss) {
        ExpressiveMenuGroup {
            ExpressiveMenuItem(
                label = stringResource(R.string.news_view_artist),
                icon = Icons.Default.PersonOutline,
                onClick = {
                    dismiss()
                    app.artist(artist.artistID)
                },
            )
            ExpressiveMenuItem(
                label = stringResource(R.string.share_artist),
                icon = Icons.Default.Share,
                onClick = {
                    dismiss()
                    share(context, if (url == null) artist.name else "${artist.name}\n$url")
                },
            )
            ExpressiveMenuItem(
                label = stringResource(R.string.news_copy_artist_name),
                icon = Icons.Default.ContentCopy,
                onClick = {
                    dismiss()
                    copyNewsText(context, artist.name, artist.name)
                },
            )
        }
    }
}
