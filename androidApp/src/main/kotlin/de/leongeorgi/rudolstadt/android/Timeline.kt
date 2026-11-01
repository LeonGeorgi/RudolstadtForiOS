@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.ProgramTimeline
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

@Composable
internal fun ScheduleTimeline(
    events: List<ProgramOccurrence>,
    unplaced: List<ProgramOccurrence>,
    minuteHeight: Float,
    columnWidth: Float,
    changeZoom: (Float, Float) -> Unit,
    facts: PlanFacts?,
) {
    val app = LocalApp.current
    val horizontal = rememberScrollState()
    val vertical = rememberScrollState()
    val density = LocalDensity.current.density
    var unplacedVisible by remember { mutableStateOf(false) }
    var timingInfo by remember { mutableStateOf(false) }
    var viewportTop by remember { mutableFloatStateOf(0f) }
    var pendingOffset by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    val data =
        remember(events, app.language) {
            val order =
                compareBy<ProgramPlace> { it.stageCode?.toIntOrNull() ?: Int.MAX_VALUE }
                    .thenBy { it.stageCode ?: "\uffff" }
                    .thenBy { it.names.text(app.language) }
            ProgramTimeline.build(
                events,
                events.mapNotNull { e ->
                    e.eventDuration?.let { EventMinutes(e.eventID, it.minutes) }
                },
                app.state.edition.definition.timeZoneID,
                true,
                true,
            ) { a, b ->
                order.compare(a, b) < 0
            }
        }
    val start = data.ticks.firstOrNull() ?: return
    val end = data.ticks.lastOrNull() ?: return
    val height = ((end - start) / 60 * minuteHeight).dp + 32.dp
    val columns = remember(events) { events.groupBy { it.stage.placeKey } }
    val clock by
        produceState(now()) {
            while (true) {
                value = now()
                delay(60_000)
            }
        }
    val gutter = TIMELINE_TIME_COLUMN_WIDTH.dp
    val headerHeight = 64.dp
    val currentZoom by rememberUpdatedState(columnWidth to minuteHeight)
    val zoomLatest by rememberUpdatedState {
        old: Pair<Float, Float>,
        next: Pair<Float, Float>,
        focus: Offset ->
        // Accumulate even if input arrives faster than the next layout frame.
        val oldOffset = pendingOffset ?: (horizontal.value to vertical.value)
        pendingOffset =
            anchoredTimelineOffset(
                oldOffset.first,
                (focus.x - gutter.value * density).coerceAtLeast(0f),
                old.first,
                next.first,
            ) to
                anchoredTimelineOffset(
                    oldOffset.second,
                    (focus.y - viewportTop).coerceAtLeast(0f),
                    old.second,
                    next.second,
                )
        changeZoom(next.first, next.second)
    }
    LaunchedEffect(columnWidth, minuteHeight) {
        pendingOffset?.let { (x, y) ->
            // Frame callbacks precede measurement; wait until the new scroll bounds exist.
            withFrameNanos {}
            withFrameNanos {}
            horizontal.scrollTo(x)
            vertical.scrollTo(y)
            pendingOffset = null
        }
    }
    LaunchedEffect(start) {
        val first = events.mapNotNull { it.startTimestamp }.minOrNull() ?: start
        val target = if (clock in start..end) clock - 15 * 60 else first - 15 * 60
        vertical.scrollTo(
            (((target - start).coerceAtLeast(0.0) / 60) * minuteHeight * density).roundToInt()
        )
    }
    Column(
        Modifier.fillMaxSize().pointerInput(density) {
            awaitEachGesture {
                awaitFirstDown(requireUnconsumed = false)
                var gestureZoom = currentZoom
                do {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    val touches = event.changes.filter { it.pressed && it.previousPressed }
                    if (touches.size == 2) {
                        val a = touches[0]
                        val b = touches[1]
                        val oldX = abs(a.previousPosition.x - b.previousPosition.x)
                        val oldY = abs(a.previousPosition.y - b.previousPosition.y)
                        val x =
                            if (oldX > 40 * density) abs(a.position.x - b.position.x) / oldX else 1f
                        val y =
                            if (oldY > 40 * density) abs(a.position.y - b.position.y) / oldY else 1f
                        val focus = event.calculateCentroid(useCurrent = false)
                        val next =
                            timelineZoom(gestureZoom.first, x, 72f, 192f) to
                                timelineZoom(gestureZoom.second, y, .7f, 2.4f)
                        zoomLatest(gestureZoom, next, focus)
                        gestureZoom = next
                        event.changes.forEach { it.consume() }
                    }
                } while (event.changes.any { it.pressed })
            }
        }
    ) {
        if (unplaced.isNotEmpty())
            TextButton(
                onClick = { unplacedVisible = true },
                modifier = Modifier.padding(horizontal = 8.dp),
            ) {
                Icon(Icons.Default.EventBusy, null, Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(pluralStringResource(R.plurals.unplaced_events, unplaced.size, unplaced.size))
            }
        Surface(color = MaterialTheme.colorScheme.surfaceContainer) {
            Row {
                IconButton(
                    onClick = { timingInfo = true },
                    modifier = Modifier.width(gutter).height(headerHeight),
                ) {
                    Icon(Icons.Default.Info, stringResource(R.string.timeline_time_info))
                }
                Row(Modifier.horizontalScroll(horizontal)) {
                    data.columns.forEach { column ->
                        Column(
                            Modifier.width(columnWidth.dp)
                                .height(headerHeight)
                                .clickable { app.place(column.place.placeKey) }
                                .padding(horizontal = 4.dp, vertical = 4.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            StageBadge(column.place, 24.dp)
                            Text(
                                column.place.names.text(app.language),
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
        }
        Row(
            Modifier.weight(1f)
                .onGloballyPositioned { viewportTop = it.positionInParent().y }
                .verticalScroll(vertical)
        ) {
            Box(
                Modifier.width(gutter).height(height).background(MaterialTheme.colorScheme.surface)
            ) {
                data.ticks.forEach { tick ->
                    Text(
                        dateTime(tick, "HH:mm"),
                        Modifier.offset(y = ((tick - start) / 60 * minuteHeight).dp)
                            .padding(start = 4.dp, top = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Row(Modifier.horizontalScroll(horizontal)) {
                data.columns.forEach { column ->
                    Box(Modifier.width(columnWidth.dp).height(height)) {
                        data.ticks.forEach { tick ->
                            HorizontalDivider(
                                Modifier.offset(y = ((tick - start) / 60 * minuteHeight).dp),
                                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .5f),
                            )
                        }
                        columns[column.place.placeKey].orEmpty().forEach { event ->
                            val cellHeight =
                                ((event.eventDuration?.minutes ?: 60) * minuteHeight).dp
                            TimelineConcert(
                                event,
                                columnWidth,
                                cellHeight.value,
                                facts?.transitions?.any {
                                    it.secondEventID == event.eventID && it.status == "impossible"
                                } == true,
                                Modifier.offset(
                                        y =
                                            ((event.startTimestamp!! - start) / 60 * minuteHeight)
                                                .dp
                                    )
                                    .padding(horizontal = 2.dp, vertical = 1.dp)
                                    .width((columnWidth - 4).dp)
                                    .height(cellHeight - 2.dp),
                            )
                        }
                        if (clock in start..end)
                            HorizontalDivider(
                                Modifier.offset {
                                    IntOffset(
                                        0,
                                        (((clock - start) / 60 * minuteHeight) * density)
                                            .roundToInt(),
                                    )
                                },
                                thickness = 2.dp,
                                color = MaterialTheme.colorScheme.error,
                            )
                    }
                }
            }
        }
    }
    if (timingInfo)
        AlertDialog(
            onDismissRequest = { timingInfo = false },
            title = { Text(stringResource(R.string.timeline_time_info)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        stringResource(
                            R.string.festival_time,
                            app.state.edition.definition.timeZoneID,
                        )
                    )
                    Text(stringResource(R.string.timeline_current_time))
                    Text(stringResource(R.string.timeline_gesture_hint))
                }
            },
            confirmButton = {
                TextButton(onClick = { timingInfo = false }) {
                    Text(stringResource(R.string.close))
                }
            },
        )
    if (unplacedVisible)
        ModalBottomSheet(onDismissRequest = { unplacedVisible = false }) {
            androidx.compose.foundation.lazy.LazyColumn(
                Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                item { Heading(stringResource(R.string.unknown_time)) }
                eventItems(unplaced)
            }
        }
}

@Composable
private fun TimelineConcert(
    event: ProgramOccurrence,
    width: Float,
    height: Float,
    warning: Boolean,
    modifier: Modifier,
) {
    val app = LocalApp.current
    val saved = event.eventID in app.state.profile.saved
    val editable = app.state.edition.editable
    var menu by remember(event.eventID) { mutableStateOf(false) }
    var rate by remember(event.eventID) { mutableStateOf(false) }
    val saveLabel = stringResource(if (saved) R.string.unsave_event else R.string.save_event)
    val rateLabel = stringResource(R.string.rating_action)
    val layout = TimelineCellLayout(width, height)
    val color =
        if (saved) MaterialTheme.colorScheme.primaryContainer else stageContainer(event.stage)
    Box(modifier) {
        Surface(
            color = color,
            contentColor = contentColorFor(color),
            shape = MaterialTheme.shapes.small,
            border = if (saved) BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary) else null,
            modifier =
                Modifier.fillMaxSize()
                    .clipToBounds()
                    .combinedClickable(
                        onClick = { app.event(event.eventID) },
                        onLongClickLabel = stringResource(R.string.concert_actions),
                        onLongClick = { menu = true },
                    )
                    .semantics {
                        customActions = buildList {
                            if (editable) {
                                add(
                                    CustomAccessibilityAction(saveLabel) {
                                        app.model.saveEvent(event.eventID)
                                        true
                                    }
                                )
                                if (event.artist.isMetadataAvailable)
                                    add(
                                        CustomAccessibilityAction(rateLabel) {
                                            rate = true
                                            true
                                        }
                                    )
                            }
                        }
                    },
        ) {
            Column(Modifier.padding(6.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (layout.showTime)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                    ) {
                        Text(
                            dateTime(event.startTimestamp!!, "HH:mm", event.zoneID),
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 1,
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        )
                        if (saved)
                            Icon(
                                Icons.Default.Bookmark,
                                stringResource(R.string.saved),
                                Modifier.size(12.dp),
                            )
                        if (warning)
                            Icon(
                                Icons.Default.WarningAmber,
                                stringResource(R.string.transition_warning),
                                Modifier.size(12.dp),
                            )
                    }
                Text(
                    event.artist.name,
                    style = MaterialTheme.typography.labelLarge,
                    maxLines = layout.titleLines,
                    overflow = TextOverflow.Ellipsis,
                )
                if (layout.showTag)
                    event.tags
                        .firstOrNull { it.showsOnTimeline }
                        ?.let {
                            Text(
                                it.titles.text(app.language),
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                color = LocalContentColor.current.copy(alpha = .8f),
                            )
                        }
                if (layout.showOrigin)
                    Text(
                        event.artist.countries(app.language),
                        style = MaterialTheme.typography.bodySmall,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                if (layout.showSummary)
                    event.artist.summaries
                        .firstOrNull { it.language == app.language }
                        ?.let {
                            Text(
                                it.text,
                                style = MaterialTheme.typography.bodySmall,
                                maxLines = 3,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                Spacer(Modifier.weight(1f))
                if (layout.showRating) ArtistRating(event.artist.artistID)
            }
        }
        ConcertActions(event, menu, { menu = false }, { rate = true })
    }
    if (rate) RatingSheet(event.artist) { rate = false }
}
