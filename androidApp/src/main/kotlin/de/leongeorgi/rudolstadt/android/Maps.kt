@file:OptIn(
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.ui.ExperimentalComposeUiApi::class,
)

package de.leongeorgi.rudolstadt.android

import android.Manifest
import android.graphics.BitmapFactory
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.discovery.CountryParser
import de.leongeorgi.rudolstadt.festival.*
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.*
import org.maplibre.android.style.expressions.Expression.*
import org.maplibre.android.style.layers.*
import org.maplibre.android.style.layers.PropertyFactory.*
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.*

@Composable
private fun NativeMap(
    style: String,
    center: LatLng,
    zoom: Double,
    modifier: Modifier = Modifier,
    configure: (MapLibreMap, Style) -> Unit,
    update: (MapLibreMap) -> Unit = {},
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val configureLatest by rememberUpdatedState(configure)
    val updateLatest by rememberUpdatedState(update)
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var failed by remember { mutableStateOf(false) }
    var rendered by remember { mutableStateOf(false) }
    val view = remember {
        CityMap.initialize(context)
        MapView(context).apply {
            onCreate(null)
            addOnDidFailLoadingMapListener { failed = true }
            addOnDidFinishRenderingMapListener { complete ->
                if (complete && map != null) {
                    rendered = true
                    failed = false
                }
            }
            getMapAsync { native ->
                native.cameraPosition = CameraPosition.Builder().target(center).zoom(zoom).build()
                native.uiSettings.isAttributionEnabled = true
                native.setStyle(Style.Builder().fromUri(style)) { loaded ->
                    map = native
                    configureLatest(native, loaded)
                    updateLatest(native)
                }
            }
        }
    }
    LaunchedEffect(view) {
        delay(15_000)
        if (!rendered) failed = true
    }
    DisposableEffect(view, lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> view.onStart()
                Lifecycle.Event.ON_RESUME -> view.onResume()
                Lifecycle.Event.ON_PAUSE -> view.onPause()
                Lifecycle.Event.ON_STOP -> view.onStop()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            view.onPause()
            view.onStop()
            view.onDestroy()
        }
    }
    Box(
        modifier
            .testTag(
                if (rendered) "city-map-ready"
                else if (failed) "city-map-error" else "city-map-loading"
            )
            .semantics { testTagsAsResourceId = true }
    ) {
        AndroidView(
            factory = { view },
            modifier = Modifier.fillMaxSize(),
            update = { map?.let(updateLatest) },
        )
        if (!rendered && !failed) CircularProgressIndicator(Modifier.align(Alignment.Center))
        if (failed)
            Surface(Modifier.align(Alignment.TopCenter)) {
                Text(
                    stringResource(R.string.map_unavailable),
                    Modifier.padding(12.dp),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
    }
}

@Composable
internal fun MapScreen(selected: String = "", back: Boolean = false) {
    val app = LocalApp.current
    var list by rememberSaveable { mutableStateOf(false) }
    var searchVisible by rememberSaveable { mutableStateOf(false) }
    var filters by rememberSaveable { mutableStateOf(false) }
    var offlineMap by rememberSaveable { mutableStateOf(false) }
    var selection by
        rememberSaveable(selected) { mutableStateOf(selected.takeIf { it.isNotEmpty() }) }
    var query by rememberSaveable { mutableStateOf("") }
    var area by rememberSaveable { mutableStateOf<Long?>(null) }
    var admission by rememberSaveable { mutableStateOf<String?>(null) }
    var category by rememberSaveable {
        mutableStateOf(if (app.content.program.sitePlan != null) "stage" else null)
    }
    LaunchedEffect(selected) {
        if (selected.isNotEmpty()) {
            category = app.content.prepared.mapAssignments[selected]
            area = null
            admission = null
        }
    }
    val places =
        app.content.program.places.filter { place ->
            place.isMetadataAvailable &&
                de.leongeorgi.rudolstadt.discovery.TextSearch.any(
                    listOf(
                            place.names.text(app.language),
                            place.area?.names?.text(app.language).orEmpty(),
                            place.stageCode.orEmpty(),
                            place.descriptions?.texts?.text(app.language).orEmpty(),
                        )
                        .map(::foldText),
                    foldText(query),
                ) &&
                (area == null || place.area?.areaID == area) &&
                (admission == null ||
                    admission in
                        app.content.capabilities.places
                            .admission(place.placeKey)
                            ?.categoryIDs
                            .orEmpty()) &&
                (category == null ||
                    app.content.prepared.mapAssignments[place.placeKey] == category)
        }
    val activeFilters = area != null || admission != null || category != null
    LaunchedEffect(places.map { it.placeKey }) {
        if (selection != null && places.none { it.placeKey == selection }) selection = null
    }
    BackHandler(enabled = selection != null && !back) { selection = null }
    Page(
        if (app.content.program.sitePlan != null) stringResource(R.string.site_plan)
        else stringResource(R.string.map_title),
        back = back,
        actions = {
            if (app.state.edition.definition.identity.festivalID == "rudolstadt")
                IconButton(onClick = { offlineMap = true }) {
                    Icon(Icons.Default.DownloadForOffline, stringResource(R.string.offline_map))
                }
            IconButton(onClick = { searchVisible = !searchVisible }) {
                Icon(Icons.Default.Search, stringResource(R.string.search_places))
            }
            IconButton(onClick = { filters = true }) {
                BadgedBox(badge = { if (activeFilters) Badge() }) {
                    Icon(Icons.Default.Tune, stringResource(R.string.filters))
                }
            }
            IconButton(onClick = { list = !list }) {
                Icon(
                    if (list) Icons.Default.Map else Icons.AutoMirrored.Filled.ViewList,
                    stringResource(if (list) R.string.map_title else R.string.list_view),
                )
            }
        },
    ) { modifier ->
        Column(modifier) {
            SourceNotice()
            AnimatedVisibility(searchVisible || query.isNotEmpty()) {
                TextField(
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    shape = MaterialTheme.shapes.extraLarge,
                    colors =
                        TextFieldDefaults.colors(
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                        ),
                    placeholder = { Text(stringResource(R.string.search_places)) },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    trailingIcon = {
                        if (query.isNotEmpty())
                            IconButton(onClick = { query = "" }) {
                                Icon(Icons.Default.Clear, stringResource(R.string.clear))
                            }
                    },
                )
            }
            if (list) LazyColumn { items(places, key = { it.placeKey }) { PlaceRow(it) } }
            else
                BoxWithConstraints(Modifier.weight(1f)) {
                    val panelHeight = maxHeight * .9f
                    val wide = maxWidth >= 840.dp || (maxWidth >= 700.dp && maxHeight < 480.dp)
                    val select: (String) -> Unit = { selection = it }
                    val map: @Composable () -> Unit = {
                        val plan = app.content.program.sitePlan
                        if (plan?.background != null)
                            SitePlanView(plan, places, selection.orEmpty(), onSelectPlace = select)
                        else
                            FestivalMap(
                                places,
                                selection.orEmpty(),
                                Modifier.fillMaxSize(),
                                onSelectPlace = select,
                            )
                    }
                    val detail: @Composable () -> Unit = {
                        MapPlacePanel(places, selection, { selection = null }, select)
                    }
                    if (wide)
                        Row(Modifier.fillMaxSize()) {
                            Box(Modifier.weight(1f)) { map() }
                            Surface(
                                Modifier.width(360.dp).fillMaxHeight(),
                                color = MaterialTheme.colorScheme.surfaceContainerLow,
                            ) {
                                detail()
                            }
                        }
                    else {
                        val sheetState = rememberBottomSheetScaffoldState()
                        BottomSheetScaffold(
                            scaffoldState = sheetState,
                            sheetPeekHeight =
                                if (selection == null) 160.dp
                                else (maxHeight * .42f).coerceIn(96.dp, 260.dp),
                            sheetContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                            sheetContent = {
                                Box(Modifier.fillMaxWidth().heightIn(max = panelHeight)) {
                                    detail()
                                }
                            },
                        ) { padding ->
                            // Leave the visible sheet area clear for map attribution and controls.
                            Box(
                                Modifier.fillMaxSize()
                                    .padding(bottom = padding.calculateBottomPadding())
                            ) {
                                map()
                            }
                        }
                    }
                }
        }
    }
    if (offlineMap) OfflineCityMapSheet(onDismiss = { offlineMap = false })
    if (filters)
        ModalBottomSheet(onDismissRequest = { filters = false }) {
            Column(Modifier.fillMaxWidth().padding(bottom = 24.dp)) {
                Heading(stringResource(R.string.filters))
                FlowRow(
                    Modifier.padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ChoiceChip(
                        stringResource(R.string.area),
                        area?.toString(),
                        app.content.program.areas.map {
                            it.areaID.toString() to it.names.text(language)
                        },
                    ) {
                        area = it?.toLongOrNull()
                    }
                    if (app.content.prepared.admission.isNotEmpty())
                        ChoiceChip(
                            stringResource(R.string.admission),
                            admission,
                            app.content.prepared.admission.map {
                                it.categoryID to it.titles.text(language)
                            },
                        ) {
                            admission = it
                        }
                    ChoiceChip(
                        stringResource(R.string.places),
                        category,
                        app.content.prepared.mapCategories.map {
                            it.categoryID to it.titles.text(language)
                        },
                    ) {
                        category = it
                    }
                }
                TextButton(
                    onClick = {
                        area = null
                        admission = null
                        category = null
                        query = ""
                    },
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    Text(stringResource(R.string.reset_filters))
                }
            }
        }
}

@Composable
internal fun ChoiceChip(
    label: String,
    value: String?,
    values: List<Pair<String, String>>,
    changed: (String?) -> Unit,
) {
    if (values.isEmpty()) return
    var expanded by remember { mutableStateOf(false) }
    Box {
        FilterChip(
            value != null,
            { expanded = true },
            { Text(values.firstOrNull { it.first == value }?.second ?: label) },
            trailingIcon = { Icon(Icons.Default.ArrowDropDown, null) },
        )
        DropdownMenu(expanded, { expanded = false }) {
            DropdownMenuItem(
                text = { Text(stringResource(R.string.all)) },
                onClick = {
                    changed(null)
                    expanded = false
                },
            )
            values.forEach { (key, text) ->
                DropdownMenuItem(
                    text = { Text(text) },
                    onClick = {
                        changed(key)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun FestivalMap(
    places: List<ProgramPlace>,
    selected: String,
    modifier: Modifier,
    preview: Boolean = false,
    onSelectPlace: ((String) -> Unit)? = null,
) {
    val app = LocalApp.current
    val context = LocalContext.current
    var locationRequested by rememberSaveable { mutableStateOf(false) }
    var locationRequest by remember { mutableIntStateOf(0) }
    var focusLocation by remember { mutableStateOf(false) }
    val location = rememberMapLocation(locationRequested && !preview, locationRequest)
    val permission =
        rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            result ->
            if (result.values.any { it }) {
                locationRequested = true
                focusLocation = true
            } else Toast.makeText(context, R.string.location_denied, Toast.LENGTH_LONG).show()
        }
    val features =
        remember(places) {
            FeatureCollection.fromFeatures(
                places
                    .filter { it.hasUsableLocation }
                    .map { place ->
                        Feature.fromGeometry(Point.fromLngLat(place.longitude, place.latitude))
                            .apply {
                                addStringProperty("id", place.placeKey)
                                addStringProperty("marker", place.placeKey)
                            }
                    }
            )
        }
    var currentFeatures by remember { mutableStateOf<FeatureCollection?>(null) }
    var lastSelected by remember { mutableStateOf("") }
    var lastLocation by remember { mutableStateOf<android.location.Location?>(null) }
    val dark = MaterialTheme.colorScheme.surface.luminance() < 0.5f
    var appliedDark by remember { mutableStateOf<Boolean?>(null) }
    val color = FestivalMapStyle.marker
    val markerText = FestivalMapStyle.markerForeground
    val density = LocalDensity.current.density
    val markers =
        remember(app.content, color, markerText, density) {
            app.content.program.places.associate { place ->
                place.placeKey to placeMarker(place, color, markerText, density)
            }
        }
    Box(modifier) {
        NativeMap(
            CityMap.styleUrl,
            LatLng(50.7201, 11.3390),
            14.5,
            Modifier.fillMaxSize(),
            configure = { map, style ->
                FestivalMapStyle.apply(style, dark)
                appliedDark = dark
                style.addSource(GeoJsonSource("places", features))
                markers.forEach { (id, bitmap) -> style.addImage(id, bitmap) }
                style.addLayer(
                    SymbolLayer("places", "places")
                        .withProperties(
                            iconImage(get("marker")),
                            iconAllowOverlap(true),
                            iconIgnorePlacement(true),
                            iconSize(1f),
                        )
                )
                if (preview) {
                    map.uiSettings.isScrollGesturesEnabled = false
                    map.uiSettings.isZoomGesturesEnabled = false
                    map.uiSettings.isRotateGesturesEnabled = false
                }
                style.addSource(GeoJsonSource("location"))
                style.addLayer(
                    CircleLayer("location", "location")
                        .withProperties(
                            circleRadius(7f),
                            circleColor("#1976d2"),
                            circleStrokeWidth(3f),
                            circleStrokeColor("#ffffff"),
                        )
                )
                map.addOnMapClickListener { coordinate ->
                    val point = map.projection.toScreenLocation(coordinate)
                    val match =
                        map.queryRenderedFeatures(
                                android.graphics.RectF(
                                    point.x - 20,
                                    point.y - 20,
                                    point.x + 20,
                                    point.y + 20,
                                ),
                                "places",
                            )
                            .firstOrNull()
                    match?.getStringProperty("id")?.let {
                        if (preview) app.showPlaceOnMap(it)
                        else onSelectPlace?.invoke(it) ?: app.place(it)
                    }
                    match != null
                }
            },
            update = { map ->
                if (appliedDark != dark)
                    map.style?.let {
                        FestivalMapStyle.apply(it, dark)
                        appliedDark = dark
                    }
                map.style
                    ?.getLayerAs<SymbolLayer>("places")
                    ?.setProperties(
                        iconSize(
                            switchCase(
                                eq(get("id"), literal(selected)),
                                literal(1.25f),
                                literal(1f),
                            )
                        )
                    )
                if (currentFeatures !== features) {
                    map.style?.getSourceAs<GeoJsonSource>("places")?.setGeoJson(features)
                    currentFeatures = features
                }
                if (selected != lastSelected) {
                    app.content.places[selected]
                        ?.takeIf { it.hasUsableLocation }
                        ?.let {
                            map.animateCamera(
                                CameraUpdateFactory.newLatLngZoom(
                                    LatLng(it.latitude, it.longitude),
                                    if (preview) 15.8 else 16.5,
                                )
                            )
                        }
                    lastSelected = selected
                }
                if (lastLocation !== location.location) {
                    val fix = location.location
                    map.style
                        ?.getSourceAs<GeoJsonSource>("location")
                        ?.setGeoJson(
                            if (fix == null) FeatureCollection.fromFeatures(emptyList())
                            else
                                FeatureCollection.fromFeatures(
                                    listOf(
                                        Feature.fromGeometry(
                                            Point.fromLngLat(fix.longitude, fix.latitude)
                                        )
                                    )
                                )
                        )
                    lastLocation = fix
                }
                if (focusLocation)
                    location.location?.let { fix ->
                        map.animateCamera(
                            CameraUpdateFactory.newLatLngZoom(
                                LatLng(fix.latitude, fix.longitude),
                                16.0,
                            )
                        )
                        focusLocation = false
                    }
            },
        )
        if (!preview) {
            val locationLabel = stringResource(R.string.location)
            if (location.unavailable)
                Surface(
                    Modifier.align(Alignment.TopStart).padding(12.dp),
                    color = MaterialTheme.colorScheme.errorContainer,
                    shape = MaterialTheme.shapes.medium,
                ) {
                    Text(
                        stringResource(R.string.location_unavailable),
                        Modifier.widthIn(max = 220.dp).padding(12.dp),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            SmallFloatingActionButton(
                onClick = {
                    if (hasLocationPermission(context)) {
                        locationRequested = true
                        locationRequest++
                        focusLocation = true
                    } else
                        permission.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            )
                        )
                },
                modifier =
                    Modifier.align(Alignment.TopEnd).padding(16.dp).semantics {
                        contentDescription = locationLabel
                    },
            ) {
                if (location.locating)
                    CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                else Icon(Icons.Default.MyLocation, null)
            }
        }
    }
}

@Composable
internal fun PlaceRow(place: ProgramPlace, onClick: (() -> Unit)? = null) {
    val app = LocalApp.current
    ListItem(
        headlineContent = { Text(place.names.text(language)) },
        supportingContent = { place.area?.let { Text(it.names.text(language)) } },
        leadingContent = { StageBadge(place) },
        modifier = Modifier.clickable { onClick?.invoke() ?: app.place(place.placeKey) },
    )
}

@Composable
internal fun PlaceMapPreview(place: ProgramPlace, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val context = LocalContext.current
    Box(modifier.fillMaxWidth().height(210.dp).clip(MaterialTheme.shapes.large)) {
        val plan = app.content.program.sitePlan
        if (plan?.background != null)
            SitePlanView(plan, listOf(place), place.placeKey, preview = true)
        else
            FestivalMap(
                listOf(place),
                place.placeKey,
                Modifier.fillMaxSize(),
                preview = true,
            )
        if (place.hasUsableLocation)
            FilledTonalIconButton(
                onClick = {
                    openURL(
                        context,
                        "geo:0,0?q=${place.latitude},${place.longitude}(${android.net.Uri.encode(place.names.text(app.language))})",
                    )
                },
                Modifier.align(Alignment.TopEnd).padding(8.dp),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.OpenInNew,
                    stringResource(R.string.open_in_maps_app),
                )
            }
        FilledTonalIconButton(
            onClick = { app.showPlaceOnMap(place.placeKey) },
            Modifier.align(Alignment.BottomEnd).padding(8.dp),
        ) {
            Icon(Icons.Default.OpenInFull, stringResource(R.string.open_map))
        }
    }
}

@Composable
internal fun PlaceScreen(id: String?, highlightedEvent: Long? = null) {
    val app = LocalApp.current
    val place = app.content.places[id]
    if (place == null) {
        Page(stringResource(R.string.stage)) { Status(stringResource(R.string.not_found)) }
        return
    }
    Page(place.names.text(language)) { modifier -> PlaceContent(place, modifier, highlightedEvent) }
}

@Composable
private fun PlaceContent(
    place: ProgramPlace,
    modifier: Modifier = Modifier,
    highlightedEvent: Long? = null,
    showMap: Boolean = true,
    onSelectPlace: ((String) -> Unit)? = null,
) {
    val app = LocalApp.current
    val context = LocalContext.current
    val days = app.content.details.placeDays(place.placeKey)
    var day by
        rememberSaveable(place.placeKey, highlightedEvent) {
            mutableStateOf(
                app.content.details.initialPlaceDay(
                    place.placeKey,
                    highlightedEvent,
                    app.content.days,
                    now(),
                )
            )
        }
    val info = app.content.capabilities.places.details(place.placeKey)
    val nearby = app.content.details.nearby(place.placeKey)
    val programItems: LazyListScope.() -> Unit = {
        if (days.isNotEmpty()) {
            item {
                DayTabs(app.content.days.filter { d -> days.any { it.dayID == d.id } }, day) {
                    day = it
                }
            }
            items(
                days.firstOrNull { it.dayID == day }?.events.orEmpty(),
                key = { it.eventID },
            ) {
                EventRow(it, highlighted = it.eventID == highlightedEvent, showStage = false)
            }
        }
    }

    LazyColumn(modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
        if (showMap)
            item {
                ListItem(
                    headlineContent = {
                        Text(
                            place.names.text(language),
                            style = MaterialTheme.typography.titleLarge,
                        )
                    },
                    supportingContent = { Text(place.detailSubtitle(language)) },
                    leadingContent = { StageBadge(place, 48.dp) },
                )
            }
        if (!showMap) programItems()
        if (showMap && (place.hasUsableLocation || app.content.program.sitePlan != null))
            item {
                PlaceMapPreview(place, Modifier.padding(horizontal = 16.dp))
            }
        item { Body(info?.content) }
        if (place.locationIsApproximate)
            item {
                Text(
                    stringResource(R.string.approximate),
                    Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        items(info?.programLinks.orEmpty()) { WebLink(it) }
        if (showMap) programItems()
        if (nearby.isNotEmpty()) {
            item { Heading(stringResource(R.string.nearby)) }
            items(nearby) { near ->
                ListItem(
                    headlineContent = { Text(near.place.names.text(language)) },
                    supportingContent = {
                        Text(
                            stringResource(
                                R.string.walking,
                                near.transfer.walkingMinutes,
                                near.transfer.distanceInMeters.roundToInt(),
                            )
                        )
                    },
                    leadingContent = { StageBadge(near.place) },
                    modifier =
                        Modifier.clickable {
                            onSelectPlace?.invoke(near.place.placeKey)
                                ?: app.place(near.place.placeKey)
                        },
                )
            }
        }
    }
}

@Composable
private fun MapPlacePanel(
    places: List<ProgramPlace>,
    selected: String?,
    clear: () -> Unit,
    select: (String) -> Unit,
) {
    val app = LocalApp.current
    val place = app.content.places[selected]
    Column(Modifier.fillMaxWidth()) {
        if (place == null)
            Text(
                stringResource(R.string.places),
                Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                style = MaterialTheme.typography.titleMedium,
            )
        else
            ListItem(
                colors =
                    ListItemDefaults.colors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainerLow
                    ),
                headlineContent = {
                    Text(
                        place.names.text(app.language),
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
                supportingContent = { Text(place.detailSubtitle(app.language)) },
                leadingContent = { StageBadge(place) },
                trailingContent = {
                    IconButton(onClick = clear) {
                        Icon(Icons.Default.Close, stringResource(R.string.back_to_places))
                    }
                },
            )
        if (place == null)
            LazyColumn(Modifier.fillMaxWidth()) {
                if (places.isEmpty())
                    item { Text(stringResource(R.string.empty), Modifier.padding(16.dp)) }
                items(places, key = { it.placeKey }) { item ->
                    PlaceRow(item) { select(item.placeKey) }
                }
            }
        else
            key(place.placeKey) {
                PlaceContent(
                    place,
                    Modifier.fillMaxWidth(),
                    showMap = false,
                    onSelectPlace = select,
                )
            }
    }
}

private fun ProgramPlace.detailSubtitle(language: String): String =
    listOfNotNull(area?.names?.text(language), admission?.titles?.text(language))
        .filter { it.isNotBlank() }
        .joinToString(" · ")

@Composable
private fun SitePlanView(
    plan: SitePlan,
    places: List<ProgramPlace>,
    selected: String,
    preview: Boolean = false,
    onSelectPlace: ((String) -> Unit)? = null,
) {
    val app = LocalApp.current
    val shown = places.associateBy { it.placeKey }
    val background = plan.background ?: return
    val bitmap by
        produceState<androidx.compose.ui.graphics.ImageBitmap?>(null, background) {
            value =
                withContext(Dispatchers.IO) {
                    val name = background.resourceName + ".png"
                    FestivalContentLoader::class
                        .java
                        .getResourceAsStream("/FestivalBackup/$name")
                        ?.use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
                }
        }
    var scale by rememberSaveable { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    Column {
        Box(
            Modifier.weight(1f)
                .fillMaxWidth()
                .clipToBounds()
                .transformable(
                    rememberTransformableState { zoom, pan, _ ->
                        scale = (scale * zoom).coerceIn(1f, 5f)
                        offset = if (scale <= 1f) Offset.Zero else offset + pan
                    }
                )
        ) {
            BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                val ratio = (background.width / background.height).toFloat()
                val width = (maxHeight * ratio).coerceAtMost(maxWidth)
                val density = LocalDensity.current
                LaunchedEffect(selected, width) {
                    val point =
                        plan.locations
                            .firstOrNull {
                                (it.stageID?.let { id -> "n:$id" } ?: "t:${it.id}") == selected
                            }
                            ?.point
                    if (point != null) {
                        scale = 2f
                        offset =
                            with(density) {
                                Offset(
                                    (width * (0.5 - point.x).toFloat() * scale).toPx(),
                                    (width / ratio * (point.y - 0.5).toFloat() * scale).toPx(),
                                )
                            }
                    }
                }
                Box(
                    Modifier.size(width, width / ratio).graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        translationX = offset.x
                        translationY = offset.y
                    }
                ) {
                    bitmap?.let {
                        Image(it, stringResource(R.string.site_plan), Modifier.fillMaxSize())
                    }
                    plan.locations.forEach { location ->
                        val point = location.point ?: return@forEach
                        val id = location.stageID?.let { "n:$it" } ?: "t:${location.id}"
                        val place = shown[id] ?: return@forEach
                        val title = place.names.text(app.language)
                        FilledIconButton(
                            onClick = {
                                if (preview) app.showPlaceOnMap(id)
                                else onSelectPlace?.invoke(id) ?: app.place(id)
                            },
                            modifier =
                                Modifier.offset(
                                        x = width * point.x.toFloat() - 24.dp,
                                        y = width / ratio * (1 - point.y).toFloat() - 24.dp,
                                    )
                                    .size(48.dp)
                                    .semantics { contentDescription = title },
                        ) {
                            if (location.reference != null)
                                Text(
                                    location.reference!!,
                                    style = MaterialTheme.typography.labelMedium,
                                )
                            else
                                Icon(
                                    if (location.category == "food") Icons.Default.Restaurant
                                    else Icons.Default.Info,
                                    null,
                                    Modifier.size(18.dp),
                                )
                        }
                    }
                }
            }
            if (!preview)
                IconButton(
                    onClick = {
                        scale = 1f
                        offset = Offset.Zero
                    },
                    Modifier.align(Alignment.TopEnd),
                ) {
                    Icon(Icons.Default.ZoomOutMap, stringResource(R.string.clear))
                }
        }
    }
}

@Composable
internal fun WorldScreen() {
    val app = LocalApp.current
    val counts =
        remember(app.content) {
            app.content.program.artists
                .filter { !it.hiddenFromArtistList }
                .flatMap { a ->
                    a.content.countryCodes.mapNotNull(CountryParser::alpha2).distinct()
                }
                .groupingBy { it }
                .eachCount()
        }
    val data by
        produceState<FeatureCollection?>(null, counts) {
            value =
                withContext(Dispatchers.Default) {
                    FeatureCollection.fromJson(resourceText("world_countries.geojson")).also {
                        collection ->
                        collection.features()?.forEach { feature ->
                            val code =
                                listOf("ISO_A2", "ISO_A2_EH", "POSTAL")
                                    .mapNotNull { key ->
                                        feature.getStringProperty(key)?.takeIf {
                                            it.length == 2 && it != "-99"
                                        }
                                    }
                                    .firstOrNull()
                                    .orEmpty()
                            feature.addStringProperty("country", code)
                            feature.addNumberProperty("count", counts[code] ?: 0)
                        }
                    }
                }
        }
    val countries = counts.keys.sortedBy { countryName(it, app.language) }
    var selectedCountry by rememberSaveable { mutableStateOf<String?>(null) }
    val artists =
        remember(app.content, selectedCountry) {
            app.content.program.artists
                .filter { artist ->
                    !artist.hiddenFromArtistList &&
                        artist.content.countryCodes.any {
                            CountryParser.alpha2(it) == selectedCountry
                        }
                }
                .sortedBy { foldText(it.name) }
        }
    BackHandler(enabled = selectedCountry != null) { selectedCountry = null }
    Page(stringResource(R.string.world_title)) { modifier ->
        BoxWithConstraints(modifier) {
            val wide = maxWidth >= 840.dp || (maxWidth >= 700.dp && maxHeight < 480.dp)
            val panelHeight = maxHeight * .9f
            val detail: @Composable () -> Unit = {
                Column(Modifier.fillMaxWidth()) {
                    Row(
                        Modifier.fillMaxWidth().padding(start = 24.dp, end = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f).padding(vertical = 8.dp)) {
                            Text(
                                selectedCountry?.let {
                                    "${CountryParser.flag(it).orEmpty()} ${countryName(it, app.language)}"
                                } ?: stringResource(R.string.countries),
                                style = MaterialTheme.typography.titleLarge,
                            )
                            if (selectedCountry != null)
                                Text(
                                    androidx.compose.ui.res.pluralStringResource(
                                        R.plurals.artist_count,
                                        artists.size,
                                        artists.size,
                                    ),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                        }
                        if (selectedCountry != null)
                            IconButton(onClick = { selectedCountry = null }) {
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowBack,
                                    stringResource(R.string.all_countries),
                                )
                            }
                    }
                    LazyColumn(
                        Modifier.weight(1f, fill = false),
                        contentPadding = PaddingValues(bottom = 24.dp),
                    ) {
                        if (selectedCountry == null) {
                            item {
                                Text(
                                    stringResource(R.string.globe_hint),
                                    Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                            }
                            items(countries, key = { it }) { code ->
                                ListItem(
                                    headlineContent = {
                                        Text(
                                            "${CountryParser.flag(code).orEmpty()} ${countryName(code, app.language)}"
                                        )
                                    },
                                    trailingContent = { Text(counts[code].toString()) },
                                    modifier = Modifier.clickable { selectedCountry = code },
                                )
                            }
                        } else items(artists, key = { it.artistID }) { ArtistRow(it) }
                    }
                }
            }
            val globe: @Composable (Modifier) -> Unit = { globeModifier ->
                val collection = data
                if (collection == null) Box(globeModifier) { Status() }
                else CountryGlobe(collection, globeModifier) { selectedCountry = it }
            }
            if (wide)
                Row(Modifier.fillMaxSize()) {
                    globe(Modifier.weight(1f).fillMaxHeight())
                    Surface(
                        Modifier.width(360.dp).fillMaxHeight(),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                    ) {
                        detail()
                    }
                }
            else
                BottomSheetScaffold(
                    sheetPeekHeight = if (selectedCountry == null) 208.dp else 184.dp,
                    sheetContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                    sheetContent = {
                        Box(Modifier.fillMaxWidth().heightIn(max = panelHeight)) { detail() }
                    },
                ) { padding ->
                    globe(Modifier.fillMaxSize().padding(bottom = padding.calculateBottomPadding()))
                }
        }
    }
}

private fun placeMarker(
    place: ProgramPlace,
    color: Int,
    foreground: Int,
    density: Float,
): android.graphics.Bitmap {
    val size = (34 * density).roundToInt()
    val bitmap =
        android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
    paint.color = FestivalMapStyle.markerForeground
    canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
    paint.color = color
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - 2 * density, paint)
    paint.color = foreground
    paint.textSize = 15 * density
    paint.typeface =
        android.graphics.Typeface.create(
            android.graphics.Typeface.DEFAULT,
            android.graphics.Typeface.BOLD,
        )
    paint.textAlign = android.graphics.Paint.Align.CENTER
    val label =
        place.stageCode
            ?: when (place.mapGrouping?.categoryID) {
                "parking" -> "P"
                "food" -> "♨"
                "toilets" -> "WC"
                "firstAid" -> "+"
                "entrance" -> "→"
                else -> "i"
            }
    canvas.drawText(label, size / 2f, size / 2f - (paint.ascent() + paint.descent()) / 2, paint)
    return bitmap
}
