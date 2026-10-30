package de.leongeorgi.rudolstadt.android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.festival.*

@Composable
internal fun MoreScreen() {
    val app = LocalApp.current
    Page(stringResource(R.string.more_title), back = false) { modifier ->
        LazyColumn(modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
            item { SourceNotice() }
            item {
                MenuItem(stringResource(R.string.settings), Icons.Default.Settings) {
                    app.navigate("settings")
                }
            }
            item {
                MenuItem(stringResource(R.string.world_title), Icons.Default.Public) {
                    app.navigate("world")
                }
            }
            if (app.state.edition.definition.identity.festivalID == "rudolstadt")
                item {
                    MenuItem(stringResource(R.string.information), Icons.Default.Info) {
                        app.navigate("information")
                    }
                }
            item { Heading(stringResource(R.string.browse)) }
            items(app.content.prepared.tags.filter { it.isDiscoverable }, key = { it.tagID }) { tag
                ->
                MenuItem(tag.titles.text(language), Icons.Default.LocalActivity) {
                    app.navigate("tag/${Uri.encode(tag.tagID)}")
                }
            }
            item { Heading(stringResource(R.string.about)) }
            item {
                MenuItem(stringResource(R.string.about), Icons.Default.Info) {
                    app.navigate("about")
                }
            }
            item {
                MenuItem(stringResource(R.string.licenses), Icons.AutoMirrored.Filled.Article) {
                    app.navigate("licenses")
                }
            }
        }
    }
}

@Composable
private fun MenuItem(
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    clicked: () -> Unit,
) {
    ListItem(
        headlineContent = { Text(text) },
        leadingContent = { Icon(icon, null) },
        trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null) },
        modifier = Modifier.clickable(onClick = clicked),
    )
}

@Composable
private fun Toggle(
    text: String,
    checked: Boolean,
    enabled: Boolean = true,
    changed: (Boolean) -> Unit,
) {
    ListItem(
        headlineContent = { Text(text) },
        trailingContent = { Switch(checked, changed, enabled = enabled) },
        modifier = Modifier.clickable(enabled = enabled) { changed(!checked) },
    )
}

@Composable
internal fun SettingsScreen() {
    val app = LocalApp.current
    val settings = app.state.settings
    val context = LocalContext.current
    var denied by remember { mutableStateOf(false) }
    val permission =
        rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            app.model.notifications(granted)
            denied = !granted
        }
    Page(stringResource(R.string.settings)) { modifier ->
        LazyColumn(modifier, contentPadding = PaddingValues(bottom = 32.dp)) {
            item { Heading(stringResource(R.string.festival_edition)) }
            items(Edition.all, key = { it.key }) { edition ->
                ListItem(
                    headlineContent = { Text("${editionName(edition, language)} ${edition.year}") },
                    supportingContent = {
                        if (edition.archive) Text(stringResource(R.string.archive))
                        else if (edition.experimental) Text(stringResource(R.string.experiment))
                    },
                    leadingContent = { RadioButton(settings.edition == edition.key, null) },
                    modifier = Modifier.clickable { app.model.selectEdition(edition.key) },
                )
            }
            item { Heading(stringResource(R.string.appearance)) }
            item {
                Row(Modifier.padding(horizontal = 16.dp)) {
                    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                        listOf(
                                "system" to R.string.system,
                                "light" to R.string.light,
                                "dark" to R.string.dark,
                            )
                            .forEachIndexed { i, (key, title) ->
                                SegmentedButton(
                                    settings.theme == key,
                                    { app.model.changeSettings { it.copy(theme = key) } },
                                    SegmentedButtonDefaults.itemShape(i, 3),
                                ) {
                                    Text(stringResource(title))
                                }
                            }
                    }
                }
            }
            item {
                Toggle(stringResource(R.string.dynamic_color), settings.dynamicColor) { value ->
                    app.model.changeSettings { it.copy(dynamicColor = value) }
                }
            }
            item {
                Toggle(stringResource(R.string.summaries), settings.summaries) { value ->
                    app.model.changeSettings { it.copy(summaries = value) }
                }
            }
            item {
                Toggle(stringResource(R.string.flames), settings.flames) { value ->
                    app.model.changeSettings { it.copy(flames = value) }
                }
            }
            item {
                Toggle(
                    stringResource(R.string.always_show_event_details),
                    settings.alwaysShowEventDetails,
                ) { value ->
                    app.model.changeSettings { it.copy(alwaysShowEventDetails = value) }
                }
            }
            item { Heading(stringResource(R.string.notifications)) }
            item {
                Toggle(
                    stringResource(R.string.news_title),
                    settings.newsNotifications,
                    app.state.edition.live,
                ) { enabled ->
                    if (
                        enabled &&
                            Build.VERSION.SDK_INT >= 33 &&
                            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                PackageManager.PERMISSION_GRANTED
                    )
                        permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else app.model.notifications(enabled)
                }
            }
            item {
                Text(
                    stringResource(R.string.notification_hint),
                    Modifier.padding(horizontal = 16.dp),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            if (denied)
                item {
                    Text(
                        stringResource(R.string.notification_denied),
                        Modifier.padding(16.dp),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            item {
                ListItem(
                    headlineContent = { Text(stringResource(R.string.android_settings)) },
                    modifier =
                        Modifier.clickable {
                            context.startActivity(
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            )
                        },
                )
            }
            item { Heading(stringResource(R.string.language)) }
            item {
                ListItem(
                    headlineContent = { Text(stringResource(R.string.language)) },
                    supportingContent = { Text(stringResource(R.string.language_hint)) },
                    modifier =
                        Modifier.clickable {
                            context.startActivity(
                                Intent(
                                    if (Build.VERSION.SDK_INT >= 33)
                                        Settings.ACTION_APP_LOCALE_SETTINGS
                                    else Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:${context.packageName}"),
                                )
                            )
                        },
                )
            }
            item {
                Text(
                    stringResource(R.string.local_data),
                    Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
internal fun InformationScreen() {
    val app = LocalApp.current
    val context = LocalContext.current
    Page(stringResource(R.string.information)) { modifier ->
        LazyColumn(modifier) {
            item { Heading(stringResource(R.string.park_ride)) }
            item {
                Text(
                    stringResource(R.string.park_and_ride_navi_description),
                    Modifier.padding(16.dp),
                )
            }
            items(app.content.program.places.filter { it.placeKey.startsWith("t:parking") }) {
                PlaceRow(it)
            }
            item {
                MenuItem(stringResource(R.string.shuttle), Icons.Default.DirectionsBus) {
                    openURL(
                        context,
                        RudolstadtContent.information { key, _ -> key }
                            .first { it.pageID == "bus" }
                            .webURL!!,
                    )
                }
            }
            item {
                MenuItem(stringResource(R.string.website), Icons.AutoMirrored.Filled.OpenInNew) {
                    openURL(context, "https://www.rudolstadt-festival.de")
                }
            }
        }
    }
}

@Composable
internal fun AboutScreen() {
    val app = LocalApp.current
    val context = LocalContext.current
    Page(stringResource(R.string.about)) { modifier ->
        LazyColumn(modifier) {
            item { Heading("Rudolstadt · Android") }
            item { Text(stringResource(R.string.about_text), Modifier.padding(16.dp)) }
            item {
                MenuItem(stringResource(R.string.contact), Icons.Default.Email) {
                    openURL(
                        context,
                        "mailto:rudolstadt@leongeorgi.de?subject=Feedback%20Festival-App%20Android",
                    )
                }
            }
            item {
                MenuItem(stringResource(R.string.source_code), Icons.Default.Code) {
                    openURL(context, "https://github.com/LeonGeorgi/RudolstadtForiOS")
                }
            }
            items(
                app.state.edition.definition.links.filter { !it.url.contains("apps.apple.com") }
            ) { link ->
                WebLink(ProgramLink(link.id, link.title, link.url))
            }
            item {
                MenuItem(stringResource(R.string.licenses), Icons.AutoMirrored.Filled.Article) {
                    app.navigate("licenses")
                }
            }
        }
    }
}

@Composable
internal fun LicensesScreen() {
    val links =
        listOf(
            "Kotlin · Apache 2.0" to
                "https://github.com/JetBrains/kotlin/blob/master/license/LICENSE.txt",
            "AndroidX / Compose / Media3 · Apache 2.0" to
                "https://android.googlesource.com/platform/frameworks/support/+/androidx-main/LICENSE.txt",
            "Ktor · Apache 2.0" to "https://github.com/ktorio/ktor/blob/main/LICENSE",
            "Coil · Apache 2.0" to "https://github.com/coil-kt/coil/blob/main/LICENSE.txt",
            "MapLibre Native · BSD 2-Clause" to
                "https://github.com/maplibre/maplibre-native/blob/main/LICENSE.md",
            "OkHttp · Apache 2.0" to "https://github.com/square/okhttp/blob/master/LICENSE.txt",
            "Natural Earth · Public domain" to
                "https://www.naturalearthdata.com/about/terms-of-use/",
            "OpenStreetMap · ODbL" to "https://www.openstreetmap.org/copyright",
        )
    Page(stringResource(R.string.licenses)) { modifier ->
        LazyColumn(modifier) {
            items(links) { (title, url) -> WebLink(ProgramLink(title, mapOf("en" to title), url)) }
        }
    }
}
