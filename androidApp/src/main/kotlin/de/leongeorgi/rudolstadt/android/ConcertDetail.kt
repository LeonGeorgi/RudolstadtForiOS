@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.festival.*

@Composable
internal fun ConcertDetailScreen(id: Long?) {
    val app = LocalApp.current
    val event = app.content.events[id]
    if (!app.showsEventDetails && event != null) {
        ArtistScreen(event.artist.artistID, event.eventID)
        return
    }
    Page(
        stringResource(R.string.concert_details),
        actions = {
            if (event != null) {
                val saved = event.eventID in app.state.profile.saved
                val saveLabel =
                    stringResource(if (saved) R.string.unsave_event else R.string.save_event)
                if (app.state.edition.editable)
                    IconToggleButton(
                        checked = saved,
                        onCheckedChange = { app.model.saveEvent(event.eventID) },
                    ) {
                        Icon(
                            if (saved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            saveLabel,
                        )
                    }
                else if (saved) Icon(Icons.Default.Bookmark, stringResource(R.string.saved))
            }
        },
    ) { modifier ->
        LazyColumn(modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
            if (event == null) {
                item { Text(stringResource(R.string.not_found), Modifier.padding(16.dp)) }
            } else {
                item { ConcertHero(event) }
                val info = app.content.capabilities.eventDetails?.details(event.eventID)
                if (info?.article?.texts?.values?.any { it.isNotBlank() } == true)
                    item {
                        Heading(stringResource(R.string.concert_about))
                        Body(info.article)
                    }
                info
                    ?.fields
                    .orEmpty()
                    .filter { it.hasContent }
                    .forEach { field ->
                        item {
                            Heading(field.titles.text(app.language))
                            Text(
                                field.values.text(app.language),
                                Modifier.padding(horizontal = 16.dp),
                            )
                        }
                    }
                info?.links.orEmpty().forEach { link -> item { WebLink(link) } }
                if (
                    event.stage.hasUsableLocation ||
                        app.content.program.sitePlan?.background != null
                )
                    item {
                        Heading(stringResource(R.string.concert_location))
                        PlaceMapPreview(event.stage, Modifier.padding(horizontal = 16.dp))
                        TextButton(
                            onClick = { app.showPlaceOnMap(event.stage.placeKey) },
                            modifier = Modifier.padding(horizontal = 8.dp),
                        ) {
                            Text(stringResource(R.string.open_map))
                        }
                    }
            }
        }
    }
}

@Composable
private fun ConcertHero(event: ProgramOccurrence) {
    val app = LocalApp.current
    val container = stageContainer(event.stage)
    val header =
        when (event.stage.typeCode) {
            1 -> MaterialTheme.colorScheme.primary
            2 -> MaterialTheme.colorScheme.secondary
            3 -> MaterialTheme.colorScheme.tertiary
            else -> MaterialTheme.colorScheme.inverseSurface
        }
    val date =
        (event.startTimestamp ?: event.knownDateTimestamp)?.let {
            dateTime(it, "EEEE, d MMMM yyyy", event.zoneID)
        } ?: stringResource(R.string.unknown_date)
    val tag = event.tags.firstOrNull { it.showsOnTimeline } ?: event.tags.firstOrNull()
    val duration = event.confirmedDuration?.let { stringResource(R.string.duration, it.minutes) }
    val metadata =
        listOfNotNull(tag?.titles?.text(app.language), duration)
            .filter { it.isNotBlank() }
            .joinToString(" · ")
    Column(
        Modifier.fillMaxWidth()
            .background(container.copy(alpha = .35f))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        EventTimeBadge(event, size = 64.dp, headerColor = header)
        Text(date, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Row(
            Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(
                enabled = event.stage.isMetadataAvailable,
                role = Role.Button,
            ) {
                app.place(event.stage.placeKey, event.eventID)
            },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        ) {
            Box(Modifier.clearAndSetSemantics {}) { StageBadge(event.stage, 24.dp) }
            Text(
                event.stage.names.text(app.language),
                style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp),
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f, fill = false),
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                null,
                Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Row(
            Modifier.widthIn(max = 640.dp)
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .clickable(enabled = event.artist.isMetadataAvailable, role = Role.Button) {
                    app.artist(event.artist.artistID, event.eventID)
                }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        ) {
            ArtistPhoto(
                event.artist,
                Modifier.size(36.dp)
                    .shadow(3.dp, CircleShape)
                    .clip(CircleShape)
                    .clearAndSetSemantics {},
                description = null,
            )
            Text(
                event.artist.name,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f, fill = false).semantics { heading() },
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                null,
                Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (metadata.isNotEmpty())
            Text(metadata, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
    }
}
