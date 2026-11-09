@file:OptIn(
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class,
)

package de.leongeorgi.rudolstadt.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.material3.adaptive.navigationsuite.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.fromHtml
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.*
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import de.leongeorgi.rudolstadt.festival.*
import java.time.*
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class AppUI(
    val model: AppModel,
    val state: AppState,
    val content: FestivalContent,
    val nav: NavHostController,
    val language: String,
    val onAccountLoginVisibilityChanged: (Boolean) -> Unit,
) {
    fun navigate(destination: String) = nav.navigate("${nav.currentSection()}/$destination")

    fun artist(id: Long, event: Long? = null, scrollToHighlightedEvent: Boolean = false) {
        val query =
            listOfNotNull(
                event?.let { "event=$it" },
                "focus=true".takeIf { scrollToHighlightedEvent },
            )
        navigate("artist/$id" + if (query.isEmpty()) "" else "?${query.joinToString("&")}")
    }

    val showsEventDetails: Boolean
        get() = content.capabilities.eventDetails != null || state.settings.alwaysShowEventDetails

    fun event(id: Long) {
        content.events[id]?.let {
            if (showsEventDetails) navigate("event/$id") else artist(it.artist.artistID, id)
        }
    }

    fun showPlaceOnMap(id: String) {
        navigate("stage-map/${Uri.encode(id)}")
    }

    fun place(id: String, event: Long? = null) =
        navigate("place/${Uri.encode(id)}" + (event?.let { "?event=$it" } ?: ""))
}

internal val LocalApp = staticCompositionLocalOf<AppUI> { error("App missing") }
internal val language: String
    @Composable get() = if (LocalConfiguration.current.locales[0].language == "de") "de" else "en"

@Composable
internal fun AppRoot(model: AppModel, state: AppState, incoming: Intent?, handled: () -> Unit) {
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current
    val error = stringResource(R.string.storage_error)
    LaunchedEffect(model, error) { model.storageErrors.collect { snackbar.showSnackbar(error) } }
    Surface(Modifier.fillMaxSize()) {
        if (state.settingsFailed || !state.settingsReady || state.content == null)
            AppStatusBar(overPhoto = false)
        if (state.settingsFailed) {
            Status(stringResource(R.string.storage_read_error), model::readSettings)
        } else if (!state.settingsReady) Status()
        else
            key(state.edition.key) {
                val nav = rememberNavController()
                val content = state.content
                if (content == null) {
                    Status(
                        if (state.loadFailed) stringResource(R.string.load_error) else null,
                        if (state.loadFailed) ({ model.refresh(true) }) else null,
                    )
                } else {
                    var accountLoginVisible by remember { mutableStateOf(false) }
                    val ui = AppUI(model, state, content, nav, language) {
                        accountLoginVisible = it
                    }
                    CompositionLocalProvider(LocalApp provides ui) {
                        LaunchedEffect(incoming, content) {
                            incoming ?: return@LaunchedEffect
                            if (
                                incoming.data?.toString()?.let(model.friends.controller::receive) ==
                                    true
                            ) {
                                if (!state.edition.supportsFirebaseFriends)
                                    model.selectEdition(Edition.current.key)
                                else {
                                    nav.selectSection("more")
                                    nav.navigate("more/friends") { launchSingleTop = true }
                                    handled()
                                }
                                return@LaunchedEffect
                            }
                            val link = incoming.data?.toString()?.let(ArtistPublicLink::parse)
                            if (link != null) {
                                val target =
                                    Edition.all.firstOrNull {
                                        it.year == link.year &&
                                            it.definition.identity.festivalID == "rudolstadt"
                                    }
                                if (target == null) {
                                    Toast.makeText(context, R.string.not_found, Toast.LENGTH_LONG)
                                        .show()
                                    handled()
                                } else if (target.key != state.edition.key)
                                    model.selectEdition(target.key)
                                else {
                                    if (content.artists[link.artistID] != null)
                                        ui.artist(
                                            link.artistID,
                                            link.selectedEventID(content.events.values.toList()),
                                            scrollToHighlightedEvent = true,
                                        )
                                    else
                                        Toast.makeText(
                                                context,
                                                R.string.not_found,
                                                Toast.LENGTH_LONG,
                                            )
                                            .show()
                                    handled()
                                }
                            } else if (incoming.hasExtra("newsID")) {
                                if (!state.edition.live) model.selectEdition(Edition.current.key)
                                else {
                                    nav.selectSection("news")
                                    ui.navigate("news/${incoming.getLongExtra("newsID", 0)}")
                                    handled()
                                }
                            } else handled()
                        }
                        val entry by nav.currentBackStackEntryAsState()
                        val route = entry?.destination?.route ?: "program"
                        if (!route.contains("/artist/")) AppStatusBar(overPhoto = false)
                        val destinations = appSections
                        val selectedSection = nav.currentSection()
                        val labels =
                            listOf(
                                R.string.locations_title,
                                R.string.schedule_title,
                                R.string.artists_title,
                                R.string.news_title,
                                R.string.more_title,
                            )
                        val icons =
                            listOf(
                                Icons.Default.Map,
                                Icons.AutoMirrored.Filled.EventNote,
                                Icons.Default.Groups,
                                Icons.Default.Newspaper,
                                Icons.Default.MoreHoriz,
                            )
                        val news by model.news.state.collectAsStateWithLifecycle()
                        val unread =
                            news.items.count {
                                it.languageCode == language && it.newsID !in state.settings.readNews
                            }
                        val navigationType =
                            if (accountLoginVisible || route.contains("/stage-map/")) NavigationSuiteType.None
                            else
                                NavigationSuiteScaffoldDefaults.navigationSuiteType(
                                    currentWindowAdaptiveInfo()
                                )
                        val body: @Composable () -> Unit = {
                            Box(Modifier.fillMaxSize()) {
                                FestivalNavHost(nav)
                                SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
                            }
                        }
                        NavigationSuiteScaffold(
                            navigationSuiteType = navigationType,
                            navigationItems = {
                                destinations.forEachIndexed { i, item ->
                                    NavigationSuiteItem(
                                        navigationSuiteType = navigationType,
                                        selected = selectedSection == item,
                                        onClick = {
                                            nav.selectSection(item)
                                        },
                                        icon = {
                                            BadgedBox(
                                                badge = {
                                                    if (
                                                        item == "news" &&
                                                            unread > 0 &&
                                                            state.edition.live
                                                    )
                                                        Badge { Text(unread.toString()) }
                                                }
                                            ) {
                                                Icon(icons[i], stringResource(labels[i]))
                                            }
                                        },
                                        label = {
                                            Text(
                                                stringResource(labels[i]),
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                            )
                                        },
                                    )
                                }
                            },
                            content = body,
                        )
                    }
                }
            }
    }
}

@Composable
internal fun Page(
    title: String,
    back: Boolean = true,
    actions: @Composable RowScope.() -> Unit = {},
    onBack: (() -> Unit)? = null,
    content: @Composable (Modifier) -> Unit,
) {
    val app = LocalApp.current
    var sourceDetails by remember { mutableStateOf(false) }
    if (sourceDetails) SourceDetails { sourceDetails = false }
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column(
                        Modifier.then(
                            if (!back) Modifier.clickable { sourceDetails = true } else Modifier
                        )
                    ) {
                        Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (!back)
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Text(
                                    "${editionName(app.state.edition, app.language)} ${app.state.edition.year}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Icon(
                                    Icons.Default.Info,
                                    stringResource(R.string.data_status),
                                    Modifier.size(12.dp),
                                )
                            }
                    }
                },
                navigationIcon = {
                    if (back)
                        IconButton(
                            onClick = { if (onBack != null) onBack() else app.nav.popBackStack() }
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                        }
                },
                actions = actions,
            )
        }
    ) { padding ->
        content(Modifier.fillMaxSize().padding(padding))
    }
}

@Composable
internal fun Status(message: String? = null, retry: (() -> Unit)? = null) {
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (message == null) CircularProgressIndicator() else Text(message)
            retry?.let { Button(onClick = it) { Text(stringResource(R.string.retry)) } }
        }
    }
}

@Composable
private fun sourceLabel(): String {
    val s = LocalApp.current.state
    return when {
        s.edition.archive -> stringResource(R.string.archive)
        s.edition.experimental -> stringResource(R.string.experiment)
        s.source == "remote" ->
            stringResource(
                R.string.source_remote,
                s.updatedAt?.let { dateTime(it, "d MMM HH:mm") }.orEmpty(),
            )
        s.source == "cache" -> stringResource(R.string.source_cache)
        s.source == "staleCache" -> stringResource(R.string.source_stale)
        else -> stringResource(R.string.source_bundle)
    }
}

@Composable
private fun SourceDetails(dismiss: () -> Unit) {
    val app = LocalApp.current
    AlertDialog(
        onDismissRequest = dismiss,
        icon = { Icon(Icons.Default.Info, null) },
        title = { Text(stringResource(R.string.data_status)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("${editionName(app.state.edition, app.language)} ${app.state.edition.year}")
                Text(sourceLabel())
                if (app.state.refreshFailed)
                    Text(
                        stringResource(R.string.refresh_failed),
                        color = MaterialTheme.colorScheme.error,
                    )
                Text(
                    stringResource(R.string.festival_time, app.state.edition.definition.timeZoneID)
                )
            }
        },
        confirmButton = { TextButton(onClick = dismiss) { Text(stringResource(R.string.close)) } },
        dismissButton = {
            TextButton(
                onClick = {
                    app.model.refresh(true)
                    dismiss()
                }
            ) {
                Text(stringResource(R.string.refresh))
            }
        },
    )
}

@Composable
internal fun SourceNotice() {
    val s = LocalApp.current.state
    var details by remember { mutableStateOf(false) }
    val needsNotice =
        s.refreshFailed ||
            s.edition.archive ||
            s.edition.experimental ||
            s.source !in setOf("remote", "cache")
    if (needsNotice) {
        Surface(
            onClick = { details = true },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
            color =
                if (s.refreshFailed) MaterialTheme.colorScheme.errorContainer
                else MaterialTheme.colorScheme.surfaceContainer,
            shape = MaterialTheme.shapes.medium,
        ) {
            Row(
                Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    if (s.refreshFailed) Icons.Default.CloudOff else Icons.Default.Info,
                    null,
                    Modifier.size(18.dp),
                )
                Text(
                    if (s.refreshFailed) stringResource(R.string.refresh_failed)
                    else "${s.edition.year} · ${sourceLabel()}",
                    Modifier.weight(1f),
                    style = MaterialTheme.typography.labelMedium,
                )
                Icon(
                    Icons.Default.ChevronRight,
                    stringResource(R.string.data_status),
                    Modifier.size(18.dp),
                )
            }
        }
    }
    if (s.refreshing) LinearProgressIndicator(Modifier.fillMaxWidth())
    if (details) SourceDetails { details = false }
}

@Composable
internal fun Heading(text: String) {
    Text(
        text,
        Modifier.padding(start = 16.dp, end = 16.dp, top = 20.dp, bottom = 8.dp),
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
internal fun Body(content: ProgramContent?) {
    val text = content?.texts?.text(language).orEmpty()
    if (text.isNotBlank())
        SelectionContainer {
            Text(
                if (content?.html == true) AnnotatedString.fromHtml(text)
                else AnnotatedString(text),
                Modifier.padding(16.dp),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
}

@Composable
internal fun ArtistRow(
    artist: ProgramArtist,
    modifier: Modifier = Modifier,
    colors: ListItemColors = ListItemDefaults.colors(),
    onClick: (() -> Unit)? = null,
) {
    val app = LocalApp.current
    var rating by remember(artist.artistID) { mutableStateOf(false) }
    ListItem(
        colors = colors,
        modifier =
            modifier.combinedClickable(
                onClick = { onClick?.invoke() ?: app.artist(artist.artistID) },
                onLongClick = {
                    if (app.state.edition.editable && artist.isMetadataAvailable) rating = true
                },
            ),
        headlineContent = { Text(artist.name) },
        supportingContent = { Text(artist.countries(language)) },
        leadingContent = {
            ArtistPhoto(artist, Modifier.size(56.dp).clip(MaterialTheme.shapes.medium))
        },
        trailingContent = {
            if (app.state.edition.editable && artist.isMetadataAvailable)
                IconButton(onClick = { rating = true }) { ArtistRating(artist.artistID, true) }
            else ArtistRating(artist.artistID)
        },
    )
    if (rating) RatingSheet(artist) { rating = false }
}

internal fun segmentedListShape(first: Boolean, last: Boolean): RoundedCornerShape {
    val top = if (first) 20.dp else 5.dp
    val bottom = if (last) 20.dp else 5.dp
    return RoundedCornerShape(topStart = top, topEnd = top, bottomStart = bottom, bottomEnd = bottom)
}

internal fun Modifier.detailListSegment(index: Int, count: Int, verticalPadding: Dp = 0.dp): Modifier =
    padding(
        start = 16.dp,
        end = 16.dp,
        top = if (index == 0) verticalPadding else 2.dp,
        bottom = if (index == count - 1) verticalPadding else 0.dp,
    ).clip(segmentedListShape(first = index == 0, last = index == count - 1))

@Composable
internal fun ArtistRating(id: Long, showEmpty: Boolean = false) {
    val app = LocalApp.current
    val rating = (app.state.profile.ratings[id.toString()] ?: 0).coerceIn(-1, 3)
    val description =
        when {
            rating > 0 -> stringResource(R.string.rating_value, rating)
            rating < 0 ->
                stringResource(
                    alternativeRatings
                        .firstOrNull { it.first == app.state.profile.icons[id.toString()] }
                        ?.second ?: R.string.not_interested
                )
            else -> stringResource(R.string.rating_action)
        }
    Row(
        Modifier.semantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        if (rating > 0 && !app.state.settings.flames)
            RatingHeartIcon(rating, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary)
        else if (rating > 0)
            repeat(rating) {
                Icon(
                    Icons.Default.LocalFireDepartment,
                    null,
                    Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        else if (rating < 0)
            Icon(negativeSymbol(app.state.profile.icons[id.toString()]), null, Modifier.size(20.dp))
        else if (showEmpty)
            Icon(
                Icons.Default.FavoriteBorder,
                null,
                Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
    }
}

internal fun stageSymbol(place: ProgramPlace): ImageVector =
    when {
        place.placeKey.startsWith("t:parking") || place.mapGrouping?.categoryID == "parking" ->
            Icons.Default.LocalParking
        place.mapGrouping?.categoryID == "food" -> Icons.Default.Restaurant
        place.mapGrouping?.categoryID == "entrance" -> Icons.AutoMirrored.Filled.Login
        place.mapGrouping?.categoryID == "toilets" -> Icons.Default.Wc
        place.mapGrouping?.categoryID == "firstAid" -> Icons.Default.MedicalServices
        place.typeCode in 1..3 || place.stageCode != null -> Icons.Default.MusicNote
        else -> Icons.Default.Info
    }

@Composable
internal fun stageContainer(place: ProgramPlace) =
    when (place.typeCode) {
        1 -> MaterialTheme.colorScheme.primaryContainer
        2 -> MaterialTheme.colorScheme.secondaryContainer
        3 -> MaterialTheme.colorScheme.tertiaryContainer
        else -> MaterialTheme.colorScheme.surfaceContainerHighest
    }

@Composable
internal fun StageBadge(place: ProgramPlace, size: Dp = 36.dp) {
    val title = place.names.text(language)
    Surface(
        Modifier.size(size).semantics { contentDescription = title },
        shape = MaterialTheme.shapes.small,
        color = stageContainer(place),
    ) {
        Box(contentAlignment = Alignment.Center) {
            if (!place.stageCode.isNullOrBlank())
                Text(
                    place.stageCode.orEmpty(),
                    style = MaterialTheme.typography.labelLarge,
                    // This is an icon glyph; the adjacent place name scales with the system font.
                    fontSize = (size.value * .45f / LocalDensity.current.fontScale).sp,
                    lineHeight = (size.value * .6f / LocalDensity.current.fontScale).sp,
                    maxLines = 1,
                )
            else Icon(stageSymbol(place), null, Modifier.size(size * .55f))
        }
    }
}

@Composable
internal fun EventRow(
    event: ProgramOccurrence,
    showDate: Boolean = false,
    warning: String? = null,
    highlighted: Boolean = false,
    showArtist: Boolean = true,
    showStage: Boolean = true,
    modifier: Modifier = Modifier,
    containerColor: Color = MaterialTheme.colorScheme.surface,
    onClick: (() -> Unit)? = null,
) {
    val app = LocalApp.current
    var menu by remember(event.eventID) { mutableStateOf(false) }
    var rate by remember(event.eventID) { mutableStateOf(false) }
    val saved = event.eventID in app.state.profile.saved
    val saveLabel = stringResource(if (saved) R.string.unsave_event else R.string.save_event)
    val rateLabel = stringResource(R.string.rating_action)
    val isStageProgram = showArtist && !showStage
    val hasArtistRating =
        showArtist &&
            (app.state.profile.ratings[event.artist.artistID.toString()] ?: 0).coerceIn(-1, 3) != 0
    val showsSelectionLabel = highlighted && !isStageProgram
    val hasSupportingContent =
        hasArtistRating ||
            (showArtist && showStage) ||
            showDate ||
            showsSelectionLabel ||
            warning != null
    val background =
        if (highlighted) MaterialTheme.colorScheme.secondaryContainer
        else containerColor
    Box {
        ListItem(
            colors = ListItemDefaults.colors(containerColor = background),
            modifier =
                modifier.combinedClickable(
                        onClick = { onClick?.invoke() ?: app.event(event.eventID) },
                        onLongClickLabel = stringResource(R.string.concert_actions),
                        onLongClick = { menu = true },
                    )
                    .semantics {
                        selected = highlighted
                        customActions = buildList {
                            if (app.state.edition.editable) {
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
            headlineContent = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (!showArtist) StageBadge(event.stage, 24.dp)
                    Text(
                        if (showArtist) event.artist.name else event.stage.names.text(language),
                        style = MaterialTheme.typography.titleSmall,
                    )
                }
            },
            overlineContent =
                if (showArtist)
                    ({
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) }
                                    ?: "—",
                                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                            )
                            event.tags
                                .firstOrNull { it.showsOnTimeline }
                                ?.let {
                                    Text(
                                        it.titles.text(language),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                }
                        }
                    })
                else null,
            supportingContent =
                if (hasSupportingContent)
                    ({
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            if (hasArtistRating) ArtistRating(event.artist.artistID)
                            if (showArtist && showStage)
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    StageBadge(event.stage, 22.dp)
                                    Text(
                                        event.stage.names.text(language),
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                }
                            if (showDate)
                                Text(
                                    eventDate(event) +
                                        (event.confirmedDuration?.let {
                                            " · " +
                                                stringResource(
                                                    R.string.duration,
                                                    it.minutes,
                                                )
                                        } ?: ""),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            if (showsSelectionLabel)
                                Text(
                                    stringResource(R.string.selected_concert),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                                )
                            if (warning != null)
                                Text(
                                    warning,
                                    color = MaterialTheme.colorScheme.error,
                                    style = MaterialTheme.typography.bodySmall,
                                )
                        }
                    })
                else null,
            leadingContent = {
                if (showArtist)
                    ArtistPhoto(
                        event.artist,
                        Modifier.size(if (isStageProgram) 48.dp else 56.dp)
                            .clip(MaterialTheme.shapes.medium),
                        description = null,
                    )
                else
                    Text(
                        event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) } ?: "—",
                        style = MaterialTheme.typography.titleSmall,
                    )
            },
            trailingContent = {
                if (app.state.edition.editable)
                    IconToggleButton(saved, { app.model.saveEvent(event.eventID) }) {
                        Icon(
                            if (saved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            stringResource(
                                if (saved) R.string.unsave_event else R.string.save_event
                            ),
                            tint =
                                if (saved) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
            },
        )
        ConcertActions(event, menu, { menu = false }, { rate = true })
    }
    if (rate) RatingSheet(event.artist) { rate = false }
}

@Composable
internal fun WebLink(link: ProgramLink) {
    val context = LocalContext.current
    ListItem(
        headlineContent = { Text(link.titles.text(language).replaceFirstChar { it.titlecase() }) },
        trailingContent = { Icon(Icons.AutoMirrored.Filled.OpenInNew, null) },
        modifier = Modifier.clickable { openURL(context, link.destination) },
    )
}

internal fun openURL(context: Context, value: String) {
    try {
        val action =
            if (value.startsWith("mailto:", ignoreCase = true)) Intent.ACTION_SENDTO
            else Intent.ACTION_VIEW
        context.startActivity(Intent(action, Uri.parse(value)))
    } catch (_: android.content.ActivityNotFoundException) {
        Toast.makeText(context, R.string.open_error, Toast.LENGTH_LONG).show()
    }
}

internal fun share(context: Context, text: String) {
    context.startActivity(
        Intent.createChooser(
            Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text),
            context.getString(R.string.share),
        )
    )
}

@Composable
internal fun eventDate(event: ProgramOccurrence): String =
    (event.startTimestamp ?: event.knownDateTimestamp)?.let {
        dateTime(it, "EEE d MMM", event.zoneID)
    } ?: stringResource(R.string.unknown_date)

internal fun dateTime(
    value: Double,
    pattern: String,
    zone: String = "Europe/Berlin",
    locale: Locale = Locale.getDefault(),
) =
    Instant.ofEpochMilli((value * 1000).toLong())
        .atZone(ZoneId.of(zone))
        .format(DateTimeFormatter.ofPattern(pattern, locale))

internal fun editionName(edition: Edition, lang: String) = edition.definition.name.text(lang)
