@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.*
import kotlin.math.roundToInt

@Composable
internal fun ScheduleScreen() {
    val app = LocalApp.current
    var dayID by rememberSaveable {
        mutableStateOf(
            app.content.days.firstOrNull { now() >= it.start && now() < it.end }?.id
                ?: app.content.days.firstOrNull()?.id.orEmpty()
        )
    }
    val filter =
        app.state.settings.scheduleFilterFor(
            app.state.edition.key,
            app.content.capabilities.planning != null,
        )
    var scale by rememberSaveable { mutableFloatStateOf(1.2f) }
    var columnWidth by rememberSaveable { mutableFloatStateOf(DEFAULT_TIMELINE_COLUMN_WIDTH) }
    val largeText = LocalDensity.current.fontScale >= 1.3f
    val timeline = app.state.settings.scheduleLayout == "timeline" && !largeText
    var filterMenu by remember { mutableStateOf(false) }
    var zoomMenu by remember { mutableStateOf(false) }
    val filters =
        listOf(
                "all" to R.string.all,
                "interesting" to R.string.interesting,
                "optimal" to R.string.optimal,
                "saved" to R.string.saved,
            )
            .filter { it.first != "optimal" || app.content.capabilities.planning != null }
    val recommendations by app.model.recommendations.state.collectAsStateWithLifecycle()
    val shown =
        remember(app.content, filter, app.state.profile, recommendations) {
            SchedulePresentation.shown(
                app.content.program.events,
                filter,
                app.state.profile,
                recommendations,
            )
        }
    val sections = remember(shown, dayID) { ProgramSchedule.sections(shown.events, null, dayID) }
    val facts =
        remember(sections.scheduled, filter, app.content) {
            if (filter in setOf("saved", "optimal"))
                PlanFactsCalculator.calculate(
                    sections.scheduled,
                    sections.scheduled.mapNotNull { event ->
                        event.eventDuration?.let { EventMinutes(event.eventID, it.minutes) }
                    },
                    60,
                    app.content.transfer,
                )
            else null
        }
    Page(
        stringResource(R.string.schedule_title),
        back = false,
        actions = {
            IconButton(
                onClick = { app.navigate("personal-plan?day=${android.net.Uri.encode(dayID)}") }
            ) {
                Icon(Icons.Default.EventAvailable, stringResource(R.string.personal_plan))
            }
            Box {
                IconButton(onClick = { filterMenu = true }) {
                    BadgedBox(badge = { if (filter != "all") Badge() }) {
                        Icon(
                            Icons.Default.FilterList,
                            stringResource(R.string.filters) +
                                ": " +
                                stringResource(filters.first { it.first == filter }.second),
                        )
                    }
                }
                DropdownMenu(filterMenu, { filterMenu = false }) {
                    filters.forEach { (key, title) ->
                        DropdownMenuItem(
                            text = { Text(stringResource(title)) },
                            trailingIcon = { if (filter == key) Icon(Icons.Default.Check, null) },
                            onClick = {
                                app.model.scheduleFilter(key)
                                filterMenu = false
                            },
                        )
                    }
                }
            }
            if (!largeText)
                IconButton(
                    onClick = {
                        app.model.changeSettings {
                            it.copy(scheduleLayout = if (timeline) "list" else "timeline")
                        }
                    }
                ) {
                    Icon(
                        if (timeline) Icons.AutoMirrored.Filled.ViewList
                        else Icons.Default.ViewWeek,
                        stringResource(if (timeline) R.string.list_view else R.string.timeline),
                    )
                }
            if (timeline)
                IconButton(onClick = { zoomMenu = true }) {
                    Icon(Icons.Default.ZoomIn, stringResource(R.string.zoom))
                }
        },
    ) { modifier ->
        Column(modifier) {
            SourceNotice()
            DayTabs(app.content.days, dayID) { dayID = it }
            if (filter != "all")
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        stringResource(filters.first { it.first == filter }.second),
                        Modifier.weight(1f),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    TextButton(onClick = { app.model.scheduleFilter("all") }) {
                        Text(stringResource(R.string.clear))
                    }
                }
            when {
                shown.phase == LoadPhase.LOADING -> Status()
                shown.phase == LoadPhase.FAILED -> Status(stringResource(R.string.planning_error))
                shown.events.isEmpty() ->
                    Status(
                        stringResource(
                            if (filter == "optimal") R.string.no_plan else R.string.empty
                        )
                    )
                timeline && sections.scheduled.isNotEmpty() ->
                    key(dayID) {
                        ScheduleTimeline(
                            sections.scheduled,
                            sections.unknownTime + sections.unknownDate,
                            scale,
                            columnWidth,
                            { width, height ->
                                columnWidth = width
                                scale = height
                            },
                            facts,
                        )
                    }
                else ->
                    LazyColumn {
                        item {
                            Text(
                                stringResource(
                                    R.string.festival_time,
                                    app.state.edition.definition.timeZoneID,
                                ),
                                Modifier.padding(16.dp),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                        eventItems(sections.scheduled, facts)
                        if (sections.unknownTime.isNotEmpty()) {
                            item { Heading(stringResource(R.string.unknown_time)) }
                            eventItems(sections.unknownTime)
                        }
                        if (sections.unknownDate.isNotEmpty()) {
                            item { Heading(stringResource(R.string.unknown_date)) }
                            eventItems(sections.unknownDate)
                        }
                        if (
                            sections.scheduled.isEmpty() &&
                                sections.unknownTime.isEmpty() &&
                                sections.unknownDate.isEmpty()
                        )
                            item { Text(stringResource(R.string.empty), Modifier.padding(24.dp)) }
                    }
            }
        }
    }
    if (zoomMenu)
        AlertDialog(
            onDismissRequest = { zoomMenu = false },
            title = { Text(stringResource(R.string.zoom)) },
            text = {
                Column {
                    Text(
                        stringResource(R.string.stage_width),
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Slider(columnWidth, { columnWidth = it }, valueRange = 72f..192f)
                    Text(
                        stringResource(R.string.time_scale),
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Slider(scale, { scale = it }, valueRange = .7f..2.4f)
                    Text(
                        stringResource(R.string.timeline_gesture_hint),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { zoomMenu = false }) { Text(stringResource(R.string.close)) }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        columnWidth = DEFAULT_TIMELINE_COLUMN_WIDTH
                        scale = 1.2f
                    }
                ) {
                    Text(stringResource(R.string.reset_view))
                }
            },
        )
}

@Composable
internal fun DayTabs(
    days: List<ProgramDay>,
    selected: String,
    highlightSelection: Boolean = false,
    onSelect: (String) -> Unit,
) {
    if (days.isEmpty()) return
    val index = days.indexOfFirst { it.id == selected }.coerceAtLeast(0)
    PrimaryScrollableTabRow(index, edgePadding = 16.dp) {
        days.forEach { day ->
            Tab(
                day.id == selected,
                { onSelect(day.id) },
                text = { Text(dateTime(day.start, "EEE d")) },
                modifier =
                    if (highlightSelection && day.id == selected)
                        Modifier.background(MaterialTheme.colorScheme.primary.copy(alpha = 0.03f))
                    else Modifier,
            )
        }
    }
}

internal fun LazyListScope.eventItems(
    events: List<ProgramOccurrence>,
    facts: PlanFacts? = null,
) {
    items(
        events.sortedWith { a, b ->
            if (ProgramSchedule.precedes(a, b)) -1 else if (ProgramSchedule.precedes(b, a)) 1 else 0
        },
        key = { it.eventID },
    ) { event ->
        val transition = facts?.transitions?.firstOrNull { it.secondEventID == event.eventID }
        if (transition != null) {
            val label =
                when {
                    transition.status == "impossible" -> stringResource(R.string.transition_warning)
                    transition.transfer != null ->
                        stringResource(
                            R.string.walking,
                            transition.transfer!!.walkingMinutes,
                            transition.transfer!!.distanceInMeters.roundToInt(),
                        )
                    transition.status == "unknown" -> stringResource(R.string.walking_unknown)
                    else -> null
                }
            if (label != null)
                Text(
                    label,
                    Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    color =
                        if (transition.status == "impossible") MaterialTheme.colorScheme.error
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                )
        }
        EventRow(event)
    }
}

@Composable
internal fun TagScreen(id: String) {
    val app = LocalApp.current
    val tag = app.content.prepared.tags.firstOrNull { it.tagID == id }
    val events = app.content.program.events.filter { e -> e.tags.any { it.tagID == id } }
    Page(tag?.titles?.text(language) ?: stringResource(R.string.browse)) { modifier ->
        LazyColumn(modifier) {
            item {
                Body(tag?.introductionTexts?.let { ProgramContent(it) })
                Body(tag?.editorialContent?.article)
            }
            tag?.editorialContent?.fields.orEmpty().forEach { field ->
                item {
                    Heading(field.titles.text(language))
                    Text(field.values.text(language), Modifier.padding(horizontal = 16.dp))
                }
            }
            items(tag?.editorialContent?.links.orEmpty()) { WebLink(it) }
            items(events, key = { it.eventID }) { EventRow(it, true) }
        }
    }
}
