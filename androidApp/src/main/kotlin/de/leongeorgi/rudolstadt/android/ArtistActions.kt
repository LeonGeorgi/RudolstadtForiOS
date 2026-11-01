@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.input.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.android.data.text
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import de.leongeorgi.rudolstadt.profile.ProfileMutation

internal val alternativeRatings =
    listOf(
        "hand.thumbsdown.fill" to R.string.not_interested,
        "questionmark.circle.fill" to R.string.rating_undecided,
        "exclamationmark.triangle.fill" to R.string.rating_unsuitable,
        "clock.arrow.trianglehead.counterclockwise.rotate.90" to R.string.rating_revisit,
        "zzz" to R.string.rating_not_for_me,
        "moon.zzz.fill" to R.string.rating_late,
    )

@Composable
internal fun RatingSheet(artist: ProgramArtist, dismiss: () -> Unit) {
    val app = LocalApp.current
    val rating = app.state.profile.ratings[artist.artistID.toString()] ?: 0
    val icon = app.state.profile.icons[artist.artistID.toString()] ?: "hand.thumbsdown.fill"
    ModalBottomSheet(onDismissRequest = dismiss) {
        LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
            item {
                Text(
                    artist.name,
                    Modifier.padding(horizontal = 24.dp),
                    style = MaterialTheme.typography.headlineSmall,
                )
            }
            item {
                Text(
                    stringResource(R.string.rating_prompt),
                    Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            items(3) { index ->
                val value = index + 1
                ListItem(
                    headlineContent = {
                        Text(
                            stringResource(
                                listOf(
                                    R.string.rating_interest_1,
                                    R.string.rating_interest_2,
                                    R.string.rating_interest_3,
                                )[index]
                            )
                        )
                    },
                    leadingContent = {
                        Row(
                            Modifier.width(76.dp),
                            horizontalArrangement = Arrangement.spacedBy(3.dp),
                        ) {
                            if (app.state.settings.flames)
                                repeat(value) {
                                    Icon(
                                        Icons.Default.LocalFireDepartment,
                                        null,
                                        Modifier.size(22.dp),
                                        tint = MaterialTheme.colorScheme.primary,
                                    )
                                }
                            else
                                RatingHeartIcon(
                                    value,
                                    Modifier.size(28.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                        }
                    },
                    trailingContent = { RadioButton(rating == value, null) },
                    modifier =
                        Modifier.clickable {
                            app.model.rate(artist.artistID, value)
                            dismiss()
                        },
                )
            }
            item {
                HorizontalDivider(Modifier.padding(horizontal = 24.dp))
                Heading(stringResource(R.string.rating_other))
            }
            items(alternativeRatings.size) { index ->
                val (symbol, title) = alternativeRatings[index]
                ListItem(
                    headlineContent = { Text(stringResource(title)) },
                    leadingContent = { Icon(negativeSymbol(symbol), null) },
                    trailingContent = { RadioButton(rating < 0 && icon == symbol, null) },
                    modifier =
                        Modifier.clickable {
                            app.model.mutate(
                                ProfileMutation("setArtistIcon", artist.artistID, text = symbol)
                            )
                            dismiss()
                        },
                )
            }
            item {
                TextButton(
                    onClick = {
                        app.model.rate(artist.artistID, 0)
                        dismiss()
                    },
                    Modifier.padding(horizontal = 16.dp),
                ) {
                    Icon(Icons.Default.Clear, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.remove_rating))
                }
            }
        }
    }
}

@Composable
internal fun NoteEditor(artist: ProgramArtist, dismiss: () -> Unit) {
    val app = LocalApp.current
    val original =
        remember(artist.artistID) { app.state.profile.notes[artist.artistID.toString()].orEmpty() }
    val note = rememberTextFieldState(original)
    var confirmDiscard by rememberSaveable { mutableStateOf(false) }
    fun requestDismiss() {
        if (note.text.toString().trim() != original.trim()) confirmDiscard = true else dismiss()
    }
    AlertDialog(
        onDismissRequest = ::requestDismiss,
        title = { Text(stringResource(R.string.notes)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(artist.name, style = MaterialTheme.typography.bodyMedium)
                OutlinedTextField(
                    state = note,
                    modifier = Modifier.fillMaxWidth(),
                    lineLimits = TextFieldLineLimits.MultiLine(4, 10),
                    placeholder = { Text(stringResource(R.string.note_placeholder)) },
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    app.model.note(artist.artistID, note.text.toString())
                    dismiss()
                }
            ) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = {
            TextButton(onClick = ::requestDismiss) { Text(stringResource(R.string.cancel)) }
        },
    )
    if (confirmDiscard)
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text(stringResource(R.string.discard_title)) },
            text = { Text(stringResource(R.string.discard_message)) },
            confirmButton = {
                TextButton(onClick = dismiss) { Text(stringResource(R.string.discard)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDiscard = false }) {
                    Text(stringResource(R.string.keep_editing))
                }
            },
        )
}

@Composable
internal fun ConcertActions(
    event: ProgramOccurrence,
    expanded: Boolean,
    dismiss: () -> Unit,
    rate: () -> Unit,
) {
    val app = LocalApp.current
    val saved = event.eventID in app.state.profile.saved
    if (!expanded) return
    ModalBottomSheet(
        onDismissRequest = dismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
            item {
                ListItem(
                    headlineContent = {
                        Text(event.artist.name, style = MaterialTheme.typography.titleLarge)
                    },
                    supportingContent = {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                eventDate(event) +
                                    " · " +
                                    (event.startTimestamp?.let {
                                        dateTime(it, "HH:mm", event.zoneID)
                                    } ?: stringResource(R.string.unknown_time))
                            )
                            Text(event.stage.names.text(app.language))
                            ArtistRating(event.artist.artistID)
                        }
                    },
                    leadingContent = {
                        ArtistPhoto(
                            event.artist,
                            Modifier.size(72.dp).clip(MaterialTheme.shapes.large),
                        )
                    },
                )
            }
            if (app.state.settings.summaries)
                event.artist.summaries
                    .firstOrNull { it.language == app.language }
                    ?.let { summary ->
                        item {
                            Text(
                                summary.text,
                                Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                                style = MaterialTheme.typography.bodyMedium,
                                maxLines = 4,
                                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                            )
                        }
                    }
            item {
                ActionRow(stringResource(R.string.concert_details), Icons.Default.Info) {
                    dismiss()
                    app.event(event.eventID)
                }
            }
            item {
                ActionRow(stringResource(R.string.open_stage), Icons.Default.Place) {
                    dismiss()
                    app.place(event.stage.placeKey, event.eventID)
                }
            }
            if (app.state.edition.editable) {
                item {
                    ActionRow(
                        stringResource(if (saved) R.string.unsave_event else R.string.save_event),
                        if (saved) Icons.Default.BookmarkRemove else Icons.Default.BookmarkAdd,
                    ) {
                        app.model.saveEvent(event.eventID)
                        dismiss()
                    }
                }
                if (event.artist.isMetadataAvailable)
                    item {
                        ActionRow(
                            stringResource(R.string.rating_action),
                            Icons.Default.FavoriteBorder,
                        ) {
                            dismiss()
                            rate()
                        }
                    }
            }
        }
    }
}

@Composable
private fun ActionRow(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
) {
    ListItem(
        headlineContent = { Text(title) },
        leadingContent = { Icon(icon, null) },
        modifier = Modifier.clickable(onClick = onClick),
    )
}
