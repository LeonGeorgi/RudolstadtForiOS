package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.HorizontalAlignmentLine
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.leongeorgi.rudolstadt.android.data.text
import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.LoadPhase
import de.leongeorgi.rudolstadt.presentation.SchedulePresentation

private val PlanTitleCenter = HorizontalAlignmentLine { a, b -> minOf(a, b) }

@Composable
internal fun PersonalPlanScreen(initialDay: String?) {
    val app = LocalApp.current
    var dayID by rememberSaveable {
        mutableStateOf(
            app.content.days.firstOrNull { it.id == initialDay }?.id
                ?: app.content.days.firstOrNull { now() >= it.start && now() < it.end }?.id
                ?: app.content.days.firstOrNull()?.id.orEmpty()
        )
    }
    var showRecommendations by rememberSaveable { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    val recommendations by app.model.recommendations.state.collectAsStateWithLifecycle()
    val canRecommend = app.content.capabilities.planning != null
    val filter =
        if (showRecommendations && canRecommend && recommendations.phase == LoadPhase.READY)
            "optimal"
        else "saved"
    val shown =
        remember(app.content, app.state.profile, recommendations, filter) {
            SchedulePresentation.shown(
                app.content.program.events,
                filter,
                app.state.profile,
                recommendations,
            )
        }
    val sections = remember(shown, dayID) { ProgramSchedule.sections(shown.events, null, dayID) }
    val entries =
        remember(sections.scheduled, app.content) {
            PlanDayTimeline.entries(sections.scheduled, app.content.transfer)
        }
    Page(
        stringResource(R.string.personal_plan),
        actions = {
            if (canRecommend)
                Box {
                    IconButton(onClick = { menu = true }) {
                        Icon(Icons.Default.MoreVert, stringResource(R.string.personal_plan_options))
                    }
                    DropdownMenu(menu, { menu = false }) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.plan_show_recommendations)) },
                            leadingIcon = {
                                Icon(
                                    if (showRecommendations) Icons.Default.CheckBox
                                    else Icons.Default.CheckBoxOutlineBlank,
                                    null,
                                )
                            },
                            onClick = {
                                showRecommendations = !showRecommendations
                                menu = false
                            },
                        )
                    }
                }
        },
    ) { modifier ->
        Column(modifier.semantics { testTagsAsResourceId = true }.testTag("personal-plan-screen")) {
            DayTabs(app.content.days, dayID, highlightSelection = true) { dayID = it }
            if (showRecommendations && canRecommend) {
                when (recommendations.phase) {
                    LoadPhase.LOADING -> LinearProgressIndicator(Modifier.fillMaxWidth())
                    LoadPhase.FAILED ->
                        Text(
                            stringResource(R.string.planning_error),
                            Modifier.padding(16.dp),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    else -> Unit
                }
            }
            if (
                entries.isEmpty() &&
                    sections.unknownTime.isEmpty() &&
                    sections.unknownDate.isEmpty()
            ) {
                Box(
                    Modifier.fillMaxSize().padding(24.dp),
                    contentAlignment = androidx.compose.ui.Alignment.Center,
                ) {
                    Text(
                        stringResource(R.string.plan_empty),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodyLarge,
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                LazyColumn(
                    Modifier.fillMaxSize().testTag("personal-plan-timeline"),
                    contentPadding = PaddingValues(top = 12.dp, bottom = 16.dp),
                ) {
                    entries.forEachIndexed { index, entry ->
                        item(key = entry.id) {
                            Column {
                                if (index > 0) {
                                    if (entry.hasDashedConnectorBefore) {
                                        PlanRow(pause = true) {
                                            PlanLabel(stringResource(R.string.plan_free_time), 32)
                                        }
                                    } else PlanSpacer()
                                }
                                if (entry.incomingWalks.isNotEmpty()) {
                                    if (entry.hasDashedConnectorBefore) PlanSpacer()
                                    PlanRow(
                                        time =
                                            entry.departureTimestamp?.let { dateTime(it, "HH:mm") },
                                        walking = true,
                                    ) {
                                        PlanWalkingContent(entry)
                                    }
                                    PlanSpacer()
                                }
                                PlanRow(
                                    time =
                                        entry.event.startTimestamp?.let { dateTime(it, "HH:mm") },
                                    concert = true,
                                    recommended = entry.id !in app.state.profile.saved,
                                    conflict = entry.hasConflict,
                                ) {
                                    PlanConcertContent(entry)
                                }
                            }
                        }
                    }
                    if (sections.unknownTime.isNotEmpty()) {
                        item { Heading(stringResource(R.string.unknown_time)) }
                        items(sections.unknownTime.size) { EventRow(sections.unknownTime[it]) }
                    }
                    if (sections.unknownDate.isNotEmpty()) {
                        item { Heading(stringResource(R.string.unknown_date)) }
                        items(sections.unknownDate.size) { EventRow(sections.unknownDate[it]) }
                    }
                }
            }
        }
    }
}

/** The baseline and first title line are supplied by the measured content, including large text. */
@Composable
private fun PlanRow(
    time: String? = null,
    concert: Boolean = false,
    recommended: Boolean = false,
    conflict: Boolean = false,
    walking: Boolean = false,
    pause: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val timeStyle =
        MaterialTheme.typography.labelLarge.copy(
            fontSize = 14.sp,
            lineHeight = 20.sp,
            letterSpacing = 0.25.sp,
        )
    val measuredTime =
        rememberTextMeasurer().measure("88:88", timeStyle, maxLines = 1, softWrap = false)
    val timeWidth =
        with(LocalDensity.current) { (measuredTime.size.width.toDp() + 4.dp).coerceAtLeast(48.dp) }
    var anchor by remember { mutableIntStateOf(0) }
    Layout(
        content = {
            Text(
                time.orEmpty(),
                color =
                    if (conflict) colors.error
                    else if (concert && !recommended) colors.onSurface else colors.onSurfaceVariant,
                style = timeStyle,
                maxLines = 1,
                softWrap = false,
            )
            content()
            if (walking)
                Icon(
                    Icons.AutoMirrored.Filled.DirectionsWalk,
                    null,
                    Modifier.size(18.dp),
                    tint = colors.onSurfaceVariant,
                )
        },
        modifier =
            Modifier.fillMaxWidth().drawBehind {
                val x = 16.dp.toPx() + timeWidth.toPx() + 16.dp.toPx()
                if (conflict)
                    drawRoundRect(
                        colors.errorContainer.copy(alpha = 0.55f),
                        topLeft = Offset(x + 12.dp.toPx(), 0f),
                        size = Size((size.width - x - 20.dp.toPx()).coerceAtLeast(0f), size.height),
                        cornerRadius = CornerRadius(16.dp.toPx()),
                    )
                if (pause) {
                    listOf(-3.5f, 3.5f).forEach { offset ->
                        val y = size.height / 2 + offset.dp.toPx()
                        drawLine(
                            colors.outlineVariant,
                            Offset(x - 5.44.dp.toPx(), y + 2.54.dp.toPx()),
                            Offset(x + 5.44.dp.toPx(), y - 2.54.dp.toPx()),
                            1.dp.toPx(),
                        )
                    }
                } else {
                    drawLine(
                        colors.outlineVariant,
                        Offset(x, 0f),
                        Offset(x, size.height),
                        1.dp.toPx(),
                    )
                    if (concert)
                        drawCircle(
                            colors.outline.copy(alpha = 0.8f),
                            3.dp.toPx(),
                            Offset(x, anchor.toFloat()),
                        )
                    if (walking)
                        drawCircle(colors.surface, 12.dp.toPx(), Offset(x, anchor.toFloat()))
                }
            },
    ) { measurables, constraints ->
        val timeColumn = timeWidth.roundToPx()
        val contentX = 16.dp.roundToPx() + timeColumn + 32.dp.roundToPx()
        val body =
            measurables[1].measure(
                Constraints(
                    maxWidth = (constraints.maxWidth - contentX - 4.dp.roundToPx()).coerceAtLeast(0)
                )
            )
        val label = measurables[0].measure(Constraints(maxWidth = timeColumn))
        val center = body[PlanTitleCenter].takeUnless { it == Int.MIN_VALUE } ?: body.height / 2
        anchor = center
        val baseline = body[FirstBaseline].takeUnless { it == Int.MIN_VALUE } ?: body.height / 2
        val marker =
            measurables
                .getOrNull(2)
                ?.measure(Constraints.fixed(18.dp.roundToPx(), 18.dp.roundToPx()))
        layout(constraints.maxWidth, body.height) {
            label.placeRelative(
                16.dp.roundToPx() + timeColumn - label.width,
                baseline - label[FirstBaseline],
            )
            body.placeRelative(contentX, 0)
            marker?.placeRelative(
                16.dp.roundToPx() + timeColumn + 7.dp.roundToPx(),
                center - marker.height / 2,
            )
        }
    }
}

@Composable
private fun PlanSpacer() {
    PlanRow { PlanLabel(null, 8) }
}

@Composable
private fun PlanLabel(label: String?, minimumHeight: Int) {
    Box(
        Modifier.fillMaxWidth()
            .heightIn(min = minimumHeight.dp)
            .padding(
                start = 4.dp,
                top = if (label == null) 0.dp else 8.dp,
                bottom = if (label == null) 0.dp else 8.dp,
            )
    ) {
        if (label != null)
            Text(
                label,
                style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.25.sp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
    }
}

@Composable
private fun PlanConcertContent(entry: PlanTimelineEntry) {
    val app = LocalApp.current
    val saved = entry.id in app.state.profile.saved
    val event = entry.event
    val titleStyle =
        MaterialTheme.typography.bodyLarge.copy(
            fontWeight = if (saved) FontWeight.Medium else FontWeight.Normal,
            letterSpacing = 0.15.sp,
        )
    val titleLine = with(LocalDensity.current) { titleStyle.lineHeight.roundToPx() }
    // The 16/24 title role sits half a point lower in Android's font renderer than in Sketch.
    // Offset its baseline too, so the time follows the title while the supporting line stays put.
    val titleOffset = with(LocalDensity.current) { (-0.5).sp.toDp() }
    val conflictNames = entry.previousConflicts.joinToString(", ") { it.artist.name }
    val conflictText = stringResource(R.string.plan_conflict_with, conflictNames)
    val recommendedDescription = stringResource(R.string.plan_recommended)
    Layout(
        content = {
            Box(
                Modifier.size(48.dp, if (saved) 48.dp else 40.dp),
                contentAlignment = androidx.compose.ui.Alignment.Center,
            ) {
                ArtistPhoto(
                    event.artist,
                    Modifier.size(if (saved) 48.dp else 32.dp)
                        .clip(RoundedCornerShape(if (saved) 8.dp else 6.dp)),
                    description = null,
                )
            }
            Column {
                Text(
                    event.artist.name,
                    modifier = Modifier.offset(y = titleOffset),
                    style = titleStyle,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    event.stage.names.text(app.language),
                    style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.25.sp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (saved) {
                IconButton(
                    onClick = { app.model.saveEvent(entry.id) },
                    enabled = app.state.edition.editable,
                    modifier = Modifier.size(48.dp).testTag("personal-plan-save-${entry.id}"),
                ) {
                    Icon(
                        Icons.Default.Bookmark,
                        stringResource(R.string.unsave_event),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            } else {
                Box(
                    Modifier.size(48.dp).semantics { contentDescription = recommendedDescription },
                    contentAlignment = androidx.compose.ui.Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        null,
                        Modifier.size(24.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (entry.hasConflict)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(
                        Icons.Default.Error,
                        null,
                        Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.error,
                    )
                    Text(
                        conflictText,
                        style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.25.sp),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
        },
        modifier =
            Modifier.fillMaxWidth().testTag("personal-plan-event-${entry.id}").clickable {
                app.event(entry.id)
            },
    ) { measurables, constraints ->
        val photo =
            measurables[0].measure(
                Constraints.fixed(48.dp.roundToPx(), (if (saved) 48.dp else 40.dp).roundToPx())
            )
        val text =
            measurables[1].measure(
                Constraints(maxWidth = (constraints.maxWidth - 116.dp.roundToPx()).coerceAtLeast(0))
            )
        val icon = measurables[2].measure(Constraints.fixed(48.dp.roundToPx(), 48.dp.roundToPx()))
        val top = (if (saved) 12.dp else 8.dp).roundToPx()
        val bodyHeight = maxOf((if (saved) 64.dp else 56.dp).roundToPx(), top * 2 + text.height)
        val caption =
            measurables
                .getOrNull(3)
                ?.measure(
                    Constraints(
                        maxWidth = (constraints.maxWidth - 16.dp.roundToPx()).coerceAtLeast(0)
                    )
                )
        val height = bodyHeight + (caption?.let { it.height + 8.dp.roundToPx() } ?: 0)
        layout(
            constraints.maxWidth,
            height,
            mapOf(
                FirstBaseline to top + text[FirstBaseline],
                PlanTitleCenter to top + titleLine / 2,
            ),
        ) {
            photo.placeRelative(4.dp.roundToPx(), 8.dp.roundToPx())
            text.placeRelative(68.dp.roundToPx(), top)
            icon.placeRelative(
                constraints.maxWidth - icon.width,
                top + titleLine / 2 - icon.height / 2,
            )
            caption?.placeRelative(4.dp.roundToPx(), bodyHeight)
        }
    }
}

@Composable
private fun PlanWalkingContent(entry: PlanTimelineEntry) {
    val app = LocalApp.current
    val context = LocalContext.current
    var routes by remember { mutableStateOf(false) }
    val walkingText =
        when {
            entry.hasUnknownWalkingTime -> stringResource(R.string.plan_walk_unknown)
            entry.minimumWalkingMinutes == entry.maximumWalkingMinutes ->
                stringResource(R.string.plan_walk_minutes, entry.minimumWalkingMinutes ?: 0)
            else ->
                stringResource(
                    R.string.plan_walk_range,
                    entry.minimumWalkingMinutes ?: 0,
                    entry.maximumWalkingMinutes ?: 0,
                )
        }
    fun title(walk: PlanTimelineWalk) =
        context.getString(
            R.string.plan_route_from_to,
            walk.from.names.text(app.language),
            walk.to.names.text(app.language),
        )
    fun open(walk: PlanTimelineWalk) {
        if (walk.from.hasUsableLocation && walk.to.hasUsableLocation)
            openURL(
                context,
                "https://www.google.com/maps/dir/?api=1&origin=${walk.from.latitude},${walk.from.longitude}&destination=${walk.to.latitude},${walk.to.longitude}&travelmode=walking",
            )
    }
    Layout(
        content = {
            Text(
                walkingText,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box {
                Box(
                    Modifier.size(48.dp).testTag("personal-plan-routes-${entry.id}").clickable(
                        enabled =
                            entry.incomingWalks.any {
                                it.from.hasUsableLocation && it.to.hasUsableLocation
                            },
                        onClickLabel = stringResource(R.string.plan_routes),
                    ) {
                        if (entry.incomingWalks.size == 1) open(entry.incomingWalks.first())
                        else routes = true
                    },
                    contentAlignment = androidx.compose.ui.Alignment.Center,
                ) {
                    Box(
                        Modifier.size(40.dp)
                            .background(MaterialTheme.colorScheme.secondaryContainer, CircleShape),
                        contentAlignment = androidx.compose.ui.Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.Route,
                            stringResource(R.string.plan_routes),
                            Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
                DropdownMenu(routes, { routes = false }) {
                    entry.incomingWalks.forEach { walk ->
                        DropdownMenuItem(
                            text = { Text(title(walk)) },
                            enabled = walk.from.hasUsableLocation && walk.to.hasUsableLocation,
                            onClick = {
                                routes = false
                                open(walk)
                            },
                        )
                    }
                }
            }
        },
        modifier = Modifier.fillMaxWidth(),
    ) { measurables, constraints ->
        val text =
            measurables[0].measure(
                Constraints(maxWidth = (constraints.maxWidth - 52.dp.roundToPx()).coerceAtLeast(0))
            )
        val button = measurables[1].measure(Constraints.fixed(48.dp.roundToPx(), 48.dp.roundToPx()))
        val height = maxOf(40.dp.roundToPx(), text.height + 20.dp.roundToPx())
        val textY = (height - text.height) / 2
        layout(
            constraints.maxWidth,
            height,
            mapOf(FirstBaseline to textY + text[FirstBaseline], PlanTitleCenter to height / 2),
        ) {
            text.placeRelative(4.dp.roundToPx(), textY)
            button.placeRelative(constraints.maxWidth - button.width, (height - button.height) / 2)
        }
    }
}
