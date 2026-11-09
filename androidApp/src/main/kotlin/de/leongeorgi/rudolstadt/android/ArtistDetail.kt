@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import android.app.Activity
import android.content.ContextWrapper
import android.net.Uri
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import de.leongeorgi.rudolstadt.discovery.CountryParser
import de.leongeorgi.rudolstadt.discovery.MediaLinks
import de.leongeorgi.rudolstadt.festival.*
import kotlinx.coroutines.launch

@Composable
internal fun ArtistScreen(
    id: Long?,
    highlightedEvent: Long? = null,
    scrollToHighlightedEvent: Boolean = false,
) {
    val app = LocalApp.current
    val artist = app.content.artists[id]
    if (artist == null) {
        AppStatusBar(overPhoto = false)
        Page(stringResource(R.string.artists_title)) { Status(stringResource(R.string.not_found)) }
        return
    }
    val context = LocalContext.current
    val density = LocalDensity.current
    val largeText = density.fontScale >= 1.3f
    val list = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val preview = rememberMusicPreview(artist)
    var editNote by rememberSaveable(id) { mutableStateOf(false) }
    var rate by rememberSaveable(id) { mutableStateOf(false) }
    var photo by rememberSaveable(id) { mutableStateOf(false) }
    val events = remember(app.content, id) { app.content.details.artistEvents(artist.artistID) }
    val selectedEvent = events.firstOrNull { it.eventID == highlightedEvent }
    val conflicts =
        remember(app.content, id, app.state.profile.saved) {
            app.content.details.conflicts(artist.artistID, app.state.profile.saved).associate {
                it.eventID to it.events
            }
        }
    val similar =
        remember(app.content, id) { app.content.details.similarArtists(artist.artistID, 8) }
    val videos =
        remember(artist) {
            artist.content.links.mapNotNull { link ->
                mediaParts(link.destination)?.let(MediaLinks::youtube)?.let { it to link }
            }
        }
    BoxWithConstraints(
        Modifier.fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))
    ) {
        val twoColumns =
            !largeText && (maxWidth >= 840.dp || (maxWidth >= 700.dp && maxHeight < 480.dp))
        val hero =
            !twoColumns &&
                !largeText &&
                maxHeight >= 480.dp &&
                (artist.content.image != null || artist.content.thumbnail != null)
        val heroHeight = with(density) { maxWidth.toPx() }
        val overPhoto by
            remember(hero, heroHeight, list) {
                derivedStateOf {
                    hero &&
                        list.firstVisibleItemIndex == 0 &&
                        list.firstVisibleItemScrollOffset < heroHeight * .55f
                }
            }
        val topPadding = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 64.dp
        LaunchedEffect(id, selectedEvent?.eventID, scrollToHighlightedEvent, twoColumns, hero) {
            if (scrollToHighlightedEvent && selectedEvent != null) {
                list.scrollToItem(
                    (if (twoColumns) 0 else 1) + 2 + events.indexOf(selectedEvent),
                    scrollOffset = if (hero) -with(density) { topPadding.roundToPx() } else 0,
                )
            }
        }
        AppStatusBar(overPhoto)
        Row(Modifier.widthIn(max = 1200.dp).fillMaxSize().align(Alignment.TopCenter)) {
            if (twoColumns) {
                Column(
                    Modifier.width(320.dp)
                        .fillMaxHeight()
                        .verticalScroll(rememberScrollState())
                        .padding(top = topPadding)
                ) {
                    ArtistInsetProfile(artist, { photo = true }, { rate = true })
                }
            }
            LazyColumn(
                Modifier.weight(1f).fillMaxHeight(),
                state = list,
                contentPadding =
                    PaddingValues(top = if (hero) 0.dp else topPadding, bottom = 32.dp),
            ) {
                if (!twoColumns)
                    item(key = "identity") {
                        if (hero) ArtistDetailHero(artist, list, { photo = true }, { rate = true })
                        else ArtistInsetProfile(artist, { photo = true }, { rate = true })
                    }
                item(key = "intro") { ArtistDetailIntro(artist, largeText) { editNote = true } }
                item(key = "media") { MusicPreview(artist, preview) }
                itemsIndexed(events, key = { _, event -> "event${event.eventID}" }) { index, event
                    ->
                    ArtistDetailEvent(
                        event,
                        conflicts[event.eventID].orEmpty(),
                        event.eventID == highlightedEvent,
                        Modifier.detailListSegment(index, events.size, 4.dp),
                    )
                }
                videos.forEach { (video, link) ->
                    item(key = "video${link.linkID}") {
                        Heading(stringResource(R.string.video))
                        YouTubeVideo(video, link.destination)
                    }
                }
                item(key = "description") { Body(artist.content.descriptions) }
                if (artist.groups["genre"].orEmpty().isNotEmpty()) {
                    item(key = "genres") { ArtistDetailGenres(artist) }
                }
                if (similar.isNotEmpty()) {
                    item(key = "similar") { Heading(stringResource(R.string.similar)) }
                    itemsIndexed(similar, key = { _, artist -> "similar${artist.artistID}" }) { index, artist ->
                        ArtistRow(
                            artist,
                            modifier = Modifier.detailListSegment(index, similar.size),
                            colors = ListItemDefaults.colors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            ),
                        )
                    }
                }
            }
        }
        TopAppBar(
            title = {
                if (!overPhoto) Text(artist.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
            },
            navigationIcon = {
                ArtistToolbarButton(overPhoto, { app.nav.popBackStack() }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                }
            },
            actions = {
                if (selectedEvent != null) {
                    ArtistToolbarButton(
                        overPhoto,
                        {
                            scope.launch {
                                list.animateScrollToItem(
                                    (if (twoColumns) 0 else 1) + 2 + events.indexOf(selectedEvent),
                                    scrollOffset =
                                        if (hero) -with(density) { topPadding.roundToPx() } else 0,
                                )
                            }
                        },
                    ) {
                        Icon(
                            Icons.Default.EventAvailable,
                            stringResource(R.string.selected_concert),
                        )
                    }
                }
                if (app.state.edition.definition.identity.festivalID == "rudolstadt") {
                    ArtistToolbarButton(
                        overPhoto,
                        {
                            share(
                                context,
                                "${artist.name}\n${ArtistPublicLink(app.state.edition.year, artist.artistID).url()}",
                            )
                        },
                    ) {
                        Icon(Icons.Default.Share, stringResource(R.string.share_artist))
                    }
                }
            },
            colors =
                TopAppBarDefaults.topAppBarColors(
                    containerColor =
                        if (overPhoto) Color.Transparent
                        else MaterialTheme.colorScheme.surfaceContainer,
                    navigationIconContentColor =
                        if (overPhoto) Color.White else MaterialTheme.colorScheme.onSurface,
                    actionIconContentColor =
                        if (overPhoto) Color.White else MaterialTheme.colorScheme.onSurface,
                ),
        )
    }
    if (rate) RatingSheet(artist) { rate = false }
    if (editNote) NoteEditor(artist) { editNote = false }
    if (photo) ArtistPhotoViewer(artist) { photo = false }
}

@Composable
internal fun AppStatusBar(overPhoto: Boolean) {
    val context = LocalContext.current
    val window =
        remember(context) {
            generateSequence(context) { (it as? ContextWrapper)?.baseContext }
                .filterIsInstance<Activity>()
                .firstOrNull()
                ?.window
        }
    val light = !overPhoto && MaterialTheme.colorScheme.surface.luminance() > .5f
    SideEffect {
        val controller = window?.let { WindowCompat.getInsetsController(it, it.decorView) }
        controller?.isAppearanceLightStatusBars = light
    }
}

@Composable
private fun ArtistToolbarButton(
    overPhoto: Boolean,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier =
            Modifier.padding(horizontal = 4.dp)
                .size(48.dp)
                .background(
                    if (overPhoto) Color.Black.copy(alpha = .55f) else Color.Transparent,
                    CircleShape,
                ),
        content = content,
    )
}

@Composable
private fun ArtistDetailHero(
    artist: ProgramArtist,
    list: LazyListState,
    openPhoto: () -> Unit,
    rate: () -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1f).clipToBounds()) {
        val height = with(LocalDensity.current) { maxWidth.toPx() }
        val identityVisible by
            remember(list, height) {
                derivedStateOf {
                    list.firstVisibleItemIndex == 0 &&
                        list.firstVisibleItemScrollOffset < height * .7f
                }
            }
        ArtistPhoto(
            artist,
            Modifier.fillMaxSize()
                .graphicsLayer {
                    val offset =
                        if (list.firstVisibleItemIndex == 0)
                            list.firstVisibleItemScrollOffset.toFloat()
                        else height
                    translationY = offset.coerceAtMost(height) * .2f
                }
                .clickable(onClickLabel = stringResource(R.string.open_photo), onClick = openPhoto),
            fullSize = true,
            description = null,
        )
        Box(
            Modifier.matchParentSize()
                .background(
                    Brush.verticalGradient(
                        0f to Color.Black.copy(alpha = .12f),
                        .45f to Color.Transparent,
                        1f to Color.Black.copy(alpha = .7f),
                    )
                )
        )
        if (identityVisible) {
            Row(
                Modifier.align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, bottom = 20.dp)
                    .graphicsLayer {
                        val offset = list.firstVisibleItemScrollOffset.toFloat()
                        alpha = (1f - (offset / height - .25f) / .45f).coerceIn(0f, 1f)
                    },
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Column(Modifier.weight(1f)) {
                    ArtistCountryTags(artist, true)
                    Text(
                        artist.name,
                        Modifier.semantics { heading() },
                        style = MaterialTheme.typography.headlineLarge,
                        color = Color.White,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                ArtistDetailRating(artist, rate)
            }
        }
    }
}

@Composable
private fun ArtistInsetProfile(artist: ProgramArtist, openPhoto: () -> Unit, rate: () -> Unit) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (artist.content.image != null || artist.content.thumbnail != null) {
            ArtistPhoto(
                artist,
                Modifier.fillMaxWidth()
                    .aspectRatio(1.6f)
                    .clip(MaterialTheme.shapes.extraLarge)
                    .clickable(
                        onClickLabel = stringResource(R.string.open_photo),
                        onClick = openPhoto,
                    ),
                fullSize = true,
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                artist.name,
                Modifier.weight(1f).semantics { heading() },
                style = MaterialTheme.typography.headlineMedium,
            )
            ArtistDetailRating(artist, rate)
        }
        ArtistCountryTags(artist, false)
    }
}

@Composable
private fun ArtistCountryTags(artist: ProgramArtist, overPhoto: Boolean) {
    val app = LocalApp.current
    val countries =
        remember(artist) {
            artist.content.countryCodes.mapNotNull(CountryParser::alpha2).distinct()
        }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        countries.forEach { code ->
            Box(
                Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) {
                    app.navigate("country/$code")
                },
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    Modifier.background(
                            if (overPhoto) Color.Black.copy(alpha = .6f)
                            else MaterialTheme.colorScheme.surfaceContainerHigh,
                            MaterialTheme.shapes.small,
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        Icons.Default.Public,
                        null,
                        Modifier.size(14.dp),
                        tint =
                            if (overPhoto) Color.White
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        countryName(code, app.language),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (overPhoto) Color.White else MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
        if (countries.isEmpty()) {
            val text = artist.countries(app.language)
            if (text.isNotBlank())
                Text(
                    text,
                    color =
                        if (overPhoto) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                )
        }
    }
}

@Composable
private fun ArtistDetailRating(artist: ProgramArtist, rate: () -> Unit) {
    val app = LocalApp.current
    val rating = (app.state.profile.ratings[artist.artistID.toString()] ?: 0).coerceIn(-1, 3)
    val editable = app.state.edition.editable && artist.isMetadataAvailable
    if (!editable && rating == 0) return
    val description =
        when {
            rating > 0 -> stringResource(R.string.rating_value, rating)
            rating < 0 ->
                stringResource(
                    alternativeRatings
                        .firstOrNull {
                            it.first == app.state.profile.icons[artist.artistID.toString()]
                        }
                        ?.second ?: R.string.not_interested
                )
            else -> stringResource(R.string.rating_action)
        }
    val container =
        if (rating == 0) MaterialTheme.colorScheme.surfaceContainerHighest
        else MaterialTheme.colorScheme.primary
    val tint =
        if (rating == 0) MaterialTheme.colorScheme.onSurfaceVariant
        else MaterialTheme.colorScheme.onPrimary
    val glyphs: @Composable () -> Unit = {
        Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) {
            if (rating >= 0 && !app.state.settings.flames)
                AnimatedRatingHeartIcon(rating, Modifier.size(32.dp), tint = tint)
            else if (rating > 0)
                repeat(rating) { index ->
                    val shift = (index - (rating - 1) / 2f) * 9
                    val symbol = Icons.Default.LocalFireDepartment
                    Box(
                        Modifier.offset(x = shift.dp, y = (-shift).dp).size(28.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(symbol, null, Modifier.size(28.dp), tint = container)
                        Icon(symbol, null, Modifier.size(22.dp), tint = tint)
                    }
                }
            else
                Icon(
                    if (rating < 0)
                        negativeSymbol(app.state.profile.icons[artist.artistID.toString()])
                    else Icons.Default.LocalFireDepartment,
                    null,
                    Modifier.size(24.dp),
                    tint = tint,
                )
        }
    }
    if (editable) {
        FilledIconButton(
            onClick = rate,
            modifier = Modifier.size(56.dp).semantics { contentDescription = description },
            colors =
                IconButtonDefaults.filledIconButtonColors(
                    containerColor = container,
                    contentColor = tint,
                ),
            content = glyphs,
        )
    } else
        Box(
            Modifier.size(56.dp).background(container, CircleShape).semantics {
                contentDescription = description
            },
            contentAlignment = Alignment.Center,
        ) {
            glyphs()
        }
}

@Composable
private fun ArtistDetailIntro(artist: ProgramArtist, largeText: Boolean, editNote: () -> Unit) {
    val app = LocalApp.current
    val summary =
        artist.summaries
            .firstOrNull { it.language == app.language }
            ?.takeIf { app.state.settings.summaries && it.text.isNotBlank() }
    val note = app.state.profile.notes[artist.artistID.toString()].orEmpty().trim()
    val editable = app.state.edition.notesEditable && artist.isMetadataAvailable
    if (summary == null && note.isEmpty() && !editable) return
    val summaryContent: @Composable () -> Unit = {
        if (summary != null) {
            Text(summary.text, style = MaterialTheme.typography.titleLarge)
        }
    }
    val noteContent: @Composable (Modifier) -> Unit = { modifier ->
        if (note.isNotEmpty() || editable) {
            Surface(
                modifier = modifier.heightIn(min = 48.dp),
                onClick = editNote,
                enabled = editable,
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.tertiaryContainer,
                contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
            ) {
                Box(
                    Modifier.padding(if (note.isEmpty()) 12.dp else 10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    if (note.isEmpty())
                        Icon(Icons.Default.EditNote, stringResource(R.string.note_short))
                    else
                        Text(
                            note,
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = if (editable) 5 else Int.MAX_VALUE,
                            overflow = TextOverflow.Ellipsis,
                        )
                }
            }
        }
    }
    if (largeText)
        Column(
            Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            summaryContent()
            noteContent(if (note.isEmpty()) Modifier else Modifier.fillMaxWidth())
        }
    else
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(Modifier.weight(1f)) { summaryContent() }
            noteContent(Modifier.width(if (note.isEmpty()) 48.dp else 140.dp))
        }
}

@Composable
private fun ArtistDetailEvent(
    event: ProgramOccurrence,
    conflicts: List<ProgramOccurrence>,
    highlighted: Boolean,
    modifier: Modifier,
) {
    val app = LocalApp.current
    val saved = event.eventID in app.state.profile.saved
    var menu by rememberSaveable(event.eventID) { mutableStateOf(false) }
    var rate by rememberSaveable(event.eventID) { mutableStateOf(false) }
    val saveLabel = stringResource(if (saved) R.string.unsave_event else R.string.save_event)
    Row(
        modifier.fillMaxWidth()
            .background(
                if (highlighted) MaterialTheme.colorScheme.secondaryContainer
                else MaterialTheme.colorScheme.surfaceContainer
            )
            .combinedClickable(
                onClick = {
                    if (app.showsEventDetails) app.event(event.eventID)
                    else app.place(event.stage.placeKey, event.eventID)
                },
                onLongClickLabel = stringResource(R.string.concert_actions),
                onLongClick = { menu = true },
            )
            .semantics(mergeDescendants = true) {
                selected = highlighted
                if (app.state.edition.editable)
                    customActions =
                        listOf(
                            CustomAccessibilityAction(saveLabel) {
                                app.model.saveEvent(event.eventID)
                                true
                            }
                        )
            }
            .heightIn(min = 64.dp)
            .padding(start = 8.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EventTimeBadge(event)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            event.tags
                .let { tags -> tags.firstOrNull { it.showsOnTimeline } ?: tags.firstOrNull() }
                ?.let { tag ->
                    Text(
                        tag.titles.text(app.language).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            Text(
                event.stage.names.text(app.language),
                style = MaterialTheme.typography.titleSmall,
            )
            conflicts.forEach { conflict ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Default.Info,
                        null,
                        Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        stringResource(R.string.artist_event_conflict, conflict.artist.name),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        if (app.state.edition.editable)
            IconToggleButton(
                checked = saved,
                onCheckedChange = { app.model.saveEvent(event.eventID) },
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    if (saved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                    saveLabel,
                    tint =
                        if (saved) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        else if (saved)
            Icon(Icons.Default.Bookmark, saveLabel, tint = MaterialTheme.colorScheme.primary)
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            null,
            Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    ConcertActions(event, menu, { menu = false }, { rate = true })
    if (rate) RatingSheet(event.artist) { rate = false }
}

@Composable
private fun ArtistDetailGenres(artist: ProgramArtist) {
    val app = LocalApp.current
    FlowRow(
        Modifier.padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        artist.groups["genre"].orEmpty().forEach { genre ->
            val label =
                app.content.prepared.groupings
                    .firstOrNull { it.groupingID == "genre" }
                    ?.groups
                    ?.firstOrNull { it.groupID == genre }
                    ?.titles
                    ?.text(app.language) ?: genre
            AssistChip(
                onClick = { app.navigate("genre/${Uri.encode(genre)}") },
                label = { Text(label) },
            )
        }
    }
}
