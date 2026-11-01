@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.input.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.*
import kotlinx.coroutines.flow.distinctUntilChanged

@Composable
internal fun ArtistsScreen() {
    val app = LocalApp.current
    val discovery by app.model.discovery.state.collectAsStateWithLifecycle()
    val search = rememberTextFieldState(discovery.search)
    LaunchedEffect(search) {
        snapshotFlow { search.text.toString() }
            .distinctUntilChanged()
            .collect(app.model.discovery::search)
    }
    var filters by rememberSaveable { mutableStateOf(false) }
    val filterSearch = rememberTextFieldState()
    var layoutMenu by remember { mutableStateOf(false) }
    var searchVisible by rememberSaveable { mutableStateOf(false) }
    val fontScale = LocalDensity.current.fontScale
    val focus = LocalFocusManager.current
    val artists =
        remember(app.content, discovery, app.state.profile.ratings) {
            app.content.index.matching(
                discovery.favoritesOnly,
                app.state.profile.ratings,
                foldText(discovery.search),
                discovery.groups,
            )
        }
    Page(
        stringResource(R.string.artists_title),
        back = false,
        actions = {
            IconButton(
                onClick = {
                    searchVisible = !searchVisible
                    if (!searchVisible) focus.clearFocus()
                }
            ) {
                Icon(Icons.Default.Search, stringResource(R.string.search))
            }
            IconButton(onClick = { filters = true }) {
                BadgedBox(
                    badge = { if (discovery.hasActiveFilters || discovery.favoritesOnly) Badge() }
                ) {
                    Icon(Icons.Default.Tune, stringResource(R.string.filters))
                }
            }
            Box {
                IconButton(onClick = { layoutMenu = true }) {
                    Icon(Icons.Default.MoreVert, stringResource(R.string.display_options))
                }
                DropdownMenu(layoutMenu, { layoutMenu = false }) {
                    listOf(
                            "list" to R.string.list_view,
                            "comfortable" to R.string.grid_comfortable,
                            "compact" to R.string.grid_compact,
                        )
                        .forEach { (layout, title) ->
                            val selected =
                                if (layout == "list") app.state.settings.artistLayout == "list"
                                else
                                    app.state.settings.artistLayout == "grid" &&
                                        app.state.settings.artistGridDensity == layout
                            DropdownMenuItem(
                                text = { Text(stringResource(title)) },
                                leadingIcon = {
                                    Icon(
                                        if (layout == "list") Icons.AutoMirrored.Filled.ViewList
                                        else Icons.Default.GridView,
                                        null,
                                    )
                                },
                                trailingIcon = { if (selected) Icon(Icons.Default.Check, null) },
                                onClick = {
                                    app.model.changeSettings {
                                        it.copy(
                                            artistLayout = if (layout == "list") "list" else "grid",
                                            artistGridDensity =
                                                if (layout == "list") it.artistGridDensity
                                                else layout,
                                        )
                                    }
                                    layoutMenu = false
                                },
                            )
                        }
                }
            }
        },
    ) { modifier ->
        PullToRefreshBox(app.state.refreshing, { app.model.refresh(true) }, modifier) {
            Column(Modifier.fillMaxSize()) {
                SourceNotice()
                AnimatedVisibility(searchVisible || search.text.isNotEmpty()) {
                    TextField(
                        state = search,
                        modifier =
                            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        shape = MaterialTheme.shapes.extraLarge,
                        colors =
                            TextFieldDefaults.colors(
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent,
                            ),
                        placeholder = { Text(stringResource(R.string.search)) },
                        leadingIcon = { Icon(Icons.Default.Search, null) },
                        trailingIcon = {
                            if (search.text.isNotEmpty())
                                IconButton(onClick = { search.clearText() }) {
                                    Icon(Icons.Default.Clear, stringResource(R.string.clear))
                                }
                        },
                        lineLimits = TextFieldLineLimits.SingleLine,
                    )
                }
                if (discovery.hasActiveFilters || discovery.favoritesOnly)
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Row(
                            Modifier.weight(1f).horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            if (discovery.favoritesOnly)
                                InputChip(
                                    selected = true,
                                    onClick = { app.model.discovery.favoritesOnly(false) },
                                    label = { Text(stringResource(R.string.favorites)) },
                                    trailingIcon = {
                                        Icon(
                                            Icons.Default.Close,
                                            stringResource(R.string.remove_filter),
                                            Modifier.size(18.dp),
                                        )
                                    },
                                )
                            discovery.groups.forEach { (groupingID, id) ->
                                val title =
                                    app.content.prepared.groupings
                                        .firstOrNull { it.groupingID == groupingID }
                                        ?.groups
                                        ?.firstOrNull { it.groupID == id }
                                        ?.titles
                                        ?.text(app.language) ?: id
                                InputChip(
                                    selected = true,
                                    onClick = {
                                        app.model.discovery.selectGroups(
                                            discovery.groups - groupingID
                                        )
                                    },
                                    label = { Text(title) },
                                    trailingIcon = {
                                        Icon(
                                            Icons.Default.Close,
                                            stringResource(R.string.remove_filter),
                                            Modifier.size(18.dp),
                                        )
                                    },
                                )
                            }
                        }
                    }
                if (artists.isEmpty()) {
                    Column(
                        Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            Icons.Default.SearchOff,
                            null,
                            Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(stringResource(R.string.empty), Modifier.padding(16.dp))
                        if (
                            discovery.search.isNotEmpty() ||
                                discovery.hasActiveFilters ||
                                discovery.favoritesOnly
                        )
                            TextButton(
                                onClick = {
                                    search.clearText()
                                    app.model.discovery.clearFilters()
                                    app.model.discovery.favoritesOnly(false)
                                }
                            ) {
                                Text(stringResource(R.string.reset_filters))
                            }
                    }
                } else if (app.state.settings.artistLayout == "grid") {
                    LazyVerticalGrid(
                        GridCells.Adaptive(
                            if (fontScale >= 1.3f) 240.dp
                            else if (app.state.settings.artistGridDensity == "compact") 112.dp
                            else 160.dp
                        ),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(20.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            ArtistBrowseHeader(artists.size, discovery.search.isEmpty())
                        }
                        items(artists, key = { it.artistID }) { ArtistTile(it) }
                    }
                } else
                    LazyColumn {
                        item {
                            Box(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                                ArtistBrowseHeader(artists.size, discovery.search.isEmpty())
                            }
                        }
                        items(artists, key = { it.artistID }) { ArtistRow(it) }
                    }
            }
        }
    }
    if (filters)
        ModalBottomSheet(
            onDismissRequest = { filters = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            Column(Modifier.fillMaxWidth().fillMaxHeight(.9f).imePadding()) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        stringResource(R.string.filters),
                        Modifier.weight(1f),
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    TextButton(
                        onClick = {
                            app.model.discovery.clearFilters()
                            app.model.discovery.favoritesOnly(false)
                            filterSearch.clearText()
                        }
                    ) {
                        Text(stringResource(R.string.clear))
                    }
                }
                OutlinedTextField(
                    state = filterSearch,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
                    lineLimits = TextFieldLineLimits.SingleLine,
                    label = { Text(stringResource(R.string.search_filters)) },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    trailingIcon = {
                        if (filterSearch.text.isNotEmpty())
                            IconButton(onClick = { filterSearch.clearText() }) {
                                Icon(Icons.Default.Clear, stringResource(R.string.clear))
                            }
                    },
                )
                FilterChip(
                    selected = discovery.favoritesOnly,
                    onClick = { app.model.discovery.favoritesOnly(!discovery.favoritesOnly) },
                    label = { Text(stringResource(R.string.favorites_only)) },
                    leadingIcon = {
                        if (discovery.favoritesOnly) RatingHeartIcon(1, Modifier.size(18.dp))
                        else Icon(Icons.Default.FavoriteBorder, null, Modifier.size(18.dp))
                    },
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
                val query = foldText(filterSearch.text.toString())
                val groups =
                    app.content.prepared.groupings
                        .map { grouping ->
                            grouping to
                                grouping.groups.filter {
                                    query.isBlank() ||
                                        foldText(it.titles.text(app.language)).contains(query)
                                }
                        }
                        .filter { it.second.isNotEmpty() }
                LazyColumn(Modifier.weight(1f)) {
                    if (groups.isEmpty())
                        item { Text(stringResource(R.string.empty), Modifier.padding(24.dp)) }
                    groups.forEach { (grouping, options) ->
                        item(key = "heading/${grouping.groupingID}") {
                            Heading(grouping.titles.text(app.language))
                        }
                        if (query.isBlank())
                            item(key = "all/${grouping.groupingID}") {
                                FilterOption(
                                    stringResource(R.string.all),
                                    discovery.groups[grouping.groupingID] == null,
                                ) {
                                    app.model.discovery.selectGroups(
                                        discovery.groups - grouping.groupingID
                                    )
                                }
                            }
                        items(options, key = { "${grouping.groupingID}/${it.groupID}" }) { group ->
                            FilterOption(
                                group.titles.text(app.language),
                                discovery.groups[grouping.groupingID] == group.groupID,
                            ) {
                                app.model.discovery.selectGroups(
                                    discovery.groups + (grouping.groupingID to group.groupID)
                                )
                            }
                        }
                    }
                }
                HorizontalDivider()
                Button(
                    onClick = { filters = false },
                    modifier =
                        Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp),
                ) {
                    Text(pluralStringResource(R.plurals.show_artists, artists.size, artists.size))
                }
            }
        }
}

@Composable
private fun ArtistBrowseHeader(count: Int, showWorld: Boolean) {
    val app = LocalApp.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (showWorld)
            FilledTonalButton(onClick = { app.navigate("world") }) {
                Icon(Icons.Default.Public, null, Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.world_title))
            }
        Text(
            pluralStringResource(R.plurals.artist_count, count, count),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ArtistTile(artist: ProgramArtist) {
    val app = LocalApp.current
    var rate by rememberSaveable(artist.artistID) { mutableStateOf(false) }
    val editable = app.state.edition.editable && artist.isMetadataAvailable
    Column(
        Modifier.combinedClickable(
            onClick = { app.artist(artist.artistID) },
            onLongClickLabel = stringResource(R.string.rating_action),
            onLongClick = if (editable) ({ rate = true }) else null,
        )
    ) {
        Box {
            ArtistPhoto(
                artist,
                Modifier.fillMaxWidth().aspectRatio(8f / 7f).clip(MaterialTheme.shapes.large),
                fullSize = true,
            )
            if (editable)
                FilledTonalIconButton(
                    onClick = { rate = true },
                    Modifier.align(Alignment.BottomEnd).padding(4.dp),
                ) {
                    ArtistRating(artist.artistID, showEmpty = true)
                }
            else
                Box(Modifier.align(Alignment.BottomEnd).padding(12.dp)) {
                    ArtistRating(artist.artistID)
                }
        }
        Text(
            artist.name,
            Modifier.padding(top = 8.dp),
            style = MaterialTheme.typography.titleSmall,
            maxLines = if (LocalDensity.current.fontScale >= 1.3f) Int.MAX_VALUE else 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            artist.countries(language),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    if (rate) RatingSheet(artist) { rate = false }
}

@Composable
internal fun CountryScreen(code: String) {
    val app = LocalApp.current
    val artists =
        remember(app.content, code) {
            app.content.program.artists.filter {
                !it.hiddenFromArtistList &&
                    it.content.countryCodes.any { c -> CountryParser.alpha2(c) == code }
            }
        }
    Page(countryName(code, language)) { modifier ->
        LazyColumn(modifier) { items(artists, key = { it.artistID }) { ArtistRow(it) } }
    }
}

@Composable
internal fun GenreScreen(id: String) {
    val app = LocalApp.current
    val title =
        app.content.prepared.groupings
            .firstOrNull { it.groupingID == "genre" }
            ?.groups
            ?.firstOrNull { it.groupID == id }
            ?.titles
            ?.text(language) ?: id
    val artists =
        remember(app.content, id, app.state.profile.ratings) {
            app.content.index.matching(false, app.state.profile.ratings, "", mapOf("genre" to id))
        }
    Page(title) { modifier ->
        LazyColumn(modifier) { items(artists, key = { it.artistID }) { ArtistRow(it) } }
    }
}

internal fun negativeSymbol(name: String?) =
    when (name) {
        "questionmark.circle.fill" -> Icons.AutoMirrored.Filled.HelpOutline
        "exclamationmark.triangle.fill" -> Icons.Default.WarningAmber
        "clock.arrow.trianglehead.counterclockwise.rotate.90" -> Icons.Default.History
        "zzz" -> Icons.Default.Bedtime
        "moon.zzz.fill" -> Icons.Default.NightsStay
        "ear.badge.waveform" -> Icons.AutoMirrored.Filled.VolumeOff
        "face.dashed" -> Icons.Default.SentimentDissatisfied
        else -> Icons.Default.ThumbDown
    }

@Composable
private fun FilterOption(title: String, selected: Boolean, onSelect: () -> Unit) {
    ListItem(
        headlineContent = { Text(title) },
        leadingContent = { RadioButton(selected, null) },
        modifier =
            Modifier.selectable(selected = selected, role = Role.RadioButton, onClick = onSelect),
    )
}
