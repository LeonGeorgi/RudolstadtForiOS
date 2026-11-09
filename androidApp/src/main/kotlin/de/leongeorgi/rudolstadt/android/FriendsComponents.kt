@file:OptIn(
    androidx.compose.foundation.ExperimentalFoundationApi::class,
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class,
)

package de.leongeorgi.rudolstadt.android

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material3.*
import androidx.compose.material3.carousel.HorizontalUncontainedCarousel
import androidx.compose.material3.carousel.rememberCarouselState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import de.leongeorgi.rudolstadt.android.data.foldText
import de.leongeorgi.rudolstadt.android.data.text
import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import de.leongeorgi.rudolstadt.profile.*

@Composable
internal fun rememberFriendRecommendations(
    friends: List<SharedProfile>
): List<FriendRecommendation> {
    val app = LocalApp.current
    val events =
        remember(app.content) {
            app.content.program.events.map {
                it.planningEvent(it.eventDuration?.minutes, it.eligibleForPlanning, true)
            }
        }
    val artists =
        remember(app.content) {
            app.content.program.artists.map {
                DiscoveryArtist(
                    it.artistID,
                    it.name,
                    foldText(it.name),
                    it.hiddenFromArtistList,
                    it.isMetadataAvailable,
                )
            }
        }
    val own = app.state.profile.profile
    return remember(friends, own.savedEventIDs, own.artistPreferences, events, artists) {
        Discovery.friendRecommendations(
            profiles =
                friends.map {
                    FriendProfile(it.profileID, it.badgeName ?: it.title, it.saved, it.preferences)
                },
            artists = artists,
            events = events,
            excluded =
                Discovery.excludedArtists(
                    own.savedEventIDs.toSet(),
                    own.artistPreferences.associate { it.artistID to it.rating },
                    events,
                ),
        )
    }
}

@Composable
internal fun FriendActionButton(label: String, enabled: Boolean = true, action: () -> Unit) {
    Button(action, Modifier.fillMaxWidth().heightIn(min = 56.dp), enabled = enabled) {
        Text(label, style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
internal fun FriendFeedback(state: FriendsState, retry: (() -> Unit)? = null) {
    if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
    state.error?.let { error ->
        Card(
            colors =
                CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
        ) {
            Column(Modifier.padding(16.dp)) {
                Text(
                    stringResource(error.androidString),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                )
                if (retry != null)
                    TextButton(onClick = retry, enabled = !state.busy) {
                        Text(stringResource(R.string.firebase_friends_retry))
                    }
            }
        }
    }
}

@Composable
internal fun FriendProfilePager(
    connections: List<FriendConnection>,
    state: PagerState,
    open: (FriendConnection) -> Unit,
    remove: ((FriendConnection) -> Unit)?,
) {
    HorizontalPager(
        state = state,
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
        pageSize = PageSize.Fixed(96.dp),
        pageSpacing = 8.dp,
        verticalAlignment = Alignment.Top,
        key = { connections[it].uid },
    ) { page ->
        val friend = connections[page]
        val name = friend.name ?: stringResource(R.string.friends_global_loading)
        Column(
            Modifier.fillMaxWidth()
                .combinedClickable(
                    onClick = { open(friend) },
                    onLongClick = remove?.let { request -> { request(friend) } },
                    onLongClickLabel = stringResource(R.string.firebase_friends_remove),
                    role = Role.Button,
                ),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ProfileBadgeAvatar(
                friend.name.orEmpty(),
                friend.hue,
                80.dp,
                Modifier.clearAndSetSemantics {},
            )
            Text(
                name,
                modifier = Modifier.fillMaxWidth(),
                style = MaterialTheme.typography.labelLarge,
                textAlign = TextAlign.Center,
                minLines = 2,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
internal fun FriendListSegment(
    connection: FriendConnection,
    index: Int,
    count: Int,
    open: () -> Unit,
    remove: (() -> Unit)?,
) {
    val name = connection.name ?: stringResource(R.string.friends_global_loading)
    SegmentedListItem(
        onClick = open,
        onLongClick = remove,
        onLongClickLabel = stringResource(R.string.firebase_friends_remove),
        shapes = ListItemDefaults.segmentedShapes(index, count),
        modifier = friendProfileRowPadding(index).testTag("friend-${connection.uid}"),
        leadingContent = {
            ProfileBadgeAvatar(
                connection.name.orEmpty(),
                connection.hue,
                40.dp,
                Modifier.clearAndSetSemantics {},
            )
        },
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        colors =
            ListItemDefaults.segmentedColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerLow
            ),
    ) {
        Text(name)
    }
}

@Composable
internal fun FriendRecommendationTile(
    recommendation: FriendRecommendation,
    profiles: List<SharedProfile>,
) {
    val app = LocalApp.current
    val artist = app.content.artists[recommendation.artistID] ?: return
    Card(
        onClick = {
            app.artist(
                artist.artistID,
                recommendation.contributions.firstNotNullOfOrNull { it.eventID },
            )
        },
        modifier = Modifier.width(224.dp).testTag("friend-recommendation-${artist.artistID}"),
        shape = RoundedCornerShape(28.dp),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            ),
    ) {
        ArtistPhoto(
            artist,
            Modifier.fillMaxWidth().height(168.dp),
            fullSize = true,
            description = null,
        )
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                artist.name,
                style = MaterialTheme.typography.titleMedium,
            )
            recommendation.contributions.firstOrNull()?.let {
                Text(
                    friendContributionText(it, profiles),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
internal fun FriendRecommendationRow(
    recommendation: FriendRecommendation,
    profiles: List<SharedProfile>,
) {
    val app = LocalApp.current
    val artist = app.content.artists[recommendation.artistID] ?: return
    Card(
        onClick = {
            app.artist(
                artist.artistID,
                recommendation.contributions.firstNotNullOfOrNull { it.eventID },
            )
        },
        shape = RoundedCornerShape(24.dp),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            ),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.Top,
        ) {
            ArtistPhoto(
                artist,
                Modifier.size(112.dp).clip(RoundedCornerShape(16.dp)),
                fullSize = true,
                description = null,
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    artist.name,
                    style = MaterialTheme.typography.titleLarge,
                )
                recommendation.contributions.forEach {
                    Text(
                        friendContributionText(it, profiles),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun friendContributionText(
    contribution: FriendContribution,
    profiles: List<SharedProfile>,
): String {
    val app = LocalApp.current
    val profile = profiles.firstOrNull { it.profileID == contribution.profileID }
    val name = profile?.badgeName ?: profile?.title.orEmpty()
    val event = contribution.eventID?.let { app.content.events[it] }
    if (event != null) {
        val time = event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) } ?: ""
        val day =
            (event.assignedDay?.date?.start ?: event.startTimestamp)
                ?.let { dateTime(it, "EEE", event.zoneID) }
                .orEmpty()
        return stringResource(R.string.friends_ui_reason_saved, name, day, time)
    }
    return stringResource(
        if (contribution.rating == 1) R.string.friends_ui_reason_rating_one
        else R.string.friends_ui_reason_rating_other,
        name,
        contribution.rating ?: 0,
    )
}

@Composable
internal fun FriendQRCode(value: String, modifier: Modifier = Modifier) {
    val bitmap =
        remember(value) {
            runCatching {
                val matrix = QRCodeWriter().encode(value, BarcodeFormat.QR_CODE, 480, 480)
                Bitmap.createBitmap(480, 480, Bitmap.Config.ARGB_8888)
                    .apply {
                        val pixels =
                            IntArray(480 * 480) {
                                if (matrix[it % 480, it / 480]) android.graphics.Color.BLACK
                                else android.graphics.Color.WHITE
                            }
                        setPixels(pixels, 0, 480, 0, 0, 480, 480)
                    }
                    .asImageBitmap()
            }
                .getOrNull()
        }
    Card(modifier.widthIn(max = 304.dp), shape = RoundedCornerShape(24.dp)) {
        if (bitmap != null)
            Image(
                bitmap,
                stringResource(R.string.friends_ui_invitation),
                Modifier.padding(24.dp).fillMaxWidth().aspectRatio(1f).background(Color.White),
            )
        else Text(stringResource(R.string.friends_ui_qr_error), Modifier.padding(24.dp))
    }
}

internal enum class FriendProfileSection {
    SHARED,
    DISCOVERIES,
    SAVED,
    RATINGS,
}

@Composable
internal fun friendProfileSectionTitle(section: FriendProfileSection, name: String): String =
    when (section) {
        FriendProfileSection.SHARED -> stringResource(R.string.friends_profile_shared)
        FriendProfileSection.DISCOVERIES ->
            stringResource(R.string.friends_profile_discoveries, name)
        FriendProfileSection.SAVED -> stringResource(R.string.friends_profile_saved, name)
        FriendProfileSection.RATINGS -> stringResource(R.string.friends_profile_ratings, name)
    }

private data class FriendProfileRating(val artist: ProgramArtist, val preference: ArtistPreference)

@Composable
internal fun FriendDetail(
    modifier: Modifier,
    connection: FriendConnection?,
    profile: SharedProfile?,
    section: FriendProfileSection?,
    overviewState: LazyListState,
    onOpenSection: (FriendProfileSection) -> Unit,
) {
    val app = LocalApp.current
    val edition = app.state.edition
    val editionLabel = "${editionName(edition, app.language)} ${edition.year}"
    val visibleProfile = profile?.takeIf { connection != null && it.year == app.state.edition.year }
    if (visibleProfile == null) {
        Column(modifier.fillMaxSize().padding(top = 12.dp)) {
            if (section == null && connection != null) {
                FriendProfileHeader(
                    connection.name ?: stringResource(R.string.friends_global_loading),
                    connection.hue,
                    editionLabel,
                )
            }
            Text(stringResource(R.string.friends_global_no_data), Modifier.padding(16.dp))
        }
        return
    }

    val name = connection?.name ?: visibleProfile.badgeName ?: visibleProfile.title
    val ownSaved = app.state.profile.saved
    val saved =
        remember(visibleProfile.saved, app.content) {
            visibleProfile.saved
                .mapNotNull(app.content.events::get)
                .sortedWith(
                    compareBy<ProgramOccurrence> {
                            it.startTimestamp ?: it.knownDateTimestamp ?: Double.POSITIVE_INFINITY
                        }
                        .thenBy { it.eventID }
                )
        }
    val shared = remember(saved, ownSaved) { saved.filter { it.eventID in ownSaved } }
    val discoveries = remember(saved, ownSaved) { saved.filterNot { it.eventID in ownSaved } }
    val ratings =
        remember(visibleProfile.preferences, app.content) {
            visibleProfile.preferences
                .mapNotNull { preference ->
                    if (preference.rating == 0) return@mapNotNull null
                    app.content.artists[preference.artistID]?.let {
                        FriendProfileRating(it, preference)
                    }
                }
                .sortedBy { foldText(it.artist.name) }
        }
    val recommended =
        if (section == null || section == FriendProfileSection.DISCOVERIES) {
            rememberFriendRecommendations(remember(visibleProfile) { listOf(visibleProfile) })
        } else {
            emptyList()
        }
    val discoveryRatings =
        remember(recommended, discoveries, ratings) {
            val artistsWithConcerts = discoveries.mapTo(mutableSetOf()) { it.artist.artistID }
            val ratingsByArtist = ratings.associateBy { it.artist.artistID }
            recommended.mapNotNull { recommendation ->
                if (
                    recommendation.artistID in artistsWithConcerts ||
                        recommendation.contributions.none { it.rating != null }
                )
                    null
                else ratingsByArtist[recommendation.artistID]
            }
        }

    val listState = if (section == null) overviewState else key(section) { rememberLazyListState() }
    LazyColumn(
        modifier.fillMaxSize(),
        state = listState,
        contentPadding = PaddingValues(vertical = 12.dp),
    ) {
        if (section == null) {
            item {
                FriendProfileHeader(name, connection?.hue ?: visibleProfile.badgeHue, editionLabel)
            }
            if (saved.isEmpty() && ratings.isEmpty()) {
                item {
                    Card(Modifier.fillMaxWidth().padding(16.dp)) {
                        Column(
                            Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                stringResource(R.string.friends_ui_no_content),
                                style = MaterialTheme.typography.titleLarge,
                            )
                            Text(stringResource(R.string.friends_ui_no_content_hint))
                        }
                    }
                }
            }
            if (shared.isNotEmpty()) {
                item { FriendProfileHeading(FriendProfileSection.SHARED, name, onOpenSection) }
                friendConcertRows(shared.take(3), "shared", showDate = true)
            }
            if (discoveries.isNotEmpty() || discoveryRatings.isNotEmpty()) {
                item { FriendProfileHeading(FriendProfileSection.DISCOVERIES, name, onOpenSection) }
                item { FriendProfileCarousel(discoveries, discoveryRatings) }
            }
            if (saved.isNotEmpty()) {
                item { FriendProfileHeading(FriendProfileSection.SAVED, name, onOpenSection) }
                friendConcertRows(saved.take(3), "saved", showDate = true)
            }
            if (ratings.isNotEmpty()) {
                item { FriendProfileHeading(FriendProfileSection.RATINGS, name, onOpenSection) }
                item { FriendProfileCarousel(emptyList(), ratings) }
            }
        } else {
            val sectionEvents =
                when (section) {
                    FriendProfileSection.SHARED -> shared
                    FriendProfileSection.DISCOVERIES -> discoveries
                    FriendProfileSection.SAVED -> saved
                    FriendProfileSection.RATINGS -> emptyList()
                }
            val sectionRatings =
                when (section) {
                    FriendProfileSection.DISCOVERIES -> discoveryRatings
                    FriendProfileSection.RATINGS -> ratings
                    else -> emptyList()
                }
            if (sectionEvents.isEmpty() && sectionRatings.isEmpty()) {
                item {
                    Text(stringResource(R.string.friends_profile_empty), Modifier.padding(16.dp))
                }
            }
            sectionEvents
                .groupBy { friendConcertDay(it, "EEEE, d MMMM") }
                .forEach { (day, events) ->
                    item { FriendProfileListHeading(day ?: stringResource(R.string.unknown_date)) }
                    friendConcertRows(events, "full", showDate = false)
                }
            if (section == FriendProfileSection.DISCOVERIES && sectionRatings.isNotEmpty()) {
                item {
                    FriendProfileListHeading(
                        stringResource(R.string.friends_profile_artist_ratings)
                    )
                }
            }
            itemsIndexed(
                sectionRatings,
                key = { _, rating -> "artist-${rating.artist.artistID}" },
            ) { index, rating ->
                SegmentedListItem(
                    onClick = { app.artist(rating.artist.artistID) },
                    modifier = friendProfileRowPadding(index),
                    shapes = ListItemDefaults.segmentedShapes(index, sectionRatings.size),
                    leadingContent = { FriendProfileThumbnail(rating.artist) },
                    supportingContent = { FriendPreference(rating.preference) },
                    trailingContent = { ArtistRating(rating.artist.artistID) },
                ) {
                    Text(rating.artist.name)
                }
            }
        }
    }
}

@Composable
private fun FriendProfileHeader(name: String, hue: Double, editionLabel: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ProfileBadgeAvatar(name, hue, 52.dp)
        Column {
            Text(name, style = MaterialTheme.typography.headlineSmall)
            Text(
                editionLabel,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun FriendProfileHeading(
    section: FriendProfileSection,
    name: String,
    onOpenSection: (FriendProfileSection) -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            friendProfileSectionTitle(section, name),
            Modifier.weight(1f).semantics { heading() },
            style = MaterialTheme.typography.titleLarge,
        )
        TextButton(
            onClick = { onOpenSection(section) },
            modifier = Modifier.testTag("friend-profile-${section.name.lowercase()}"),
        ) {
            Text(stringResource(R.string.friends_ui_see_all))
        }
    }
}

@Composable
private fun FriendProfileListHeading(title: String) {
    Text(
        title,
        Modifier.padding(start = 16.dp, top = 12.dp, bottom = 6.dp).semantics { heading() },
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

private fun LazyListScope.friendConcertRows(
    events: List<ProgramOccurrence>,
    keyPrefix: String,
    showDate: Boolean,
) {
    itemsIndexed(events, key = { _, event -> "$keyPrefix-${event.eventID}" }) { index, event ->
        val app = LocalApp.current
        val saved = event.eventID in app.state.profile.saved
        SegmentedListItem(
            onClick = { app.event(event.eventID) },
            modifier = friendProfileRowPadding(index),
            shapes = ListItemDefaults.segmentedShapes(index, events.size),
            leadingContent = { FriendProfileThumbnail(event.artist) },
            supportingContent = {
                Text(
                    listOfNotNull(
                            if (showDate) friendConcertDay(event, "EEE") else null,
                            event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) },
                            event.stage.names.text(app.language).takeIf { it.isNotBlank() },
                        )
                        .joinToString(" · ")
                )
            },
            trailingContent = {
                val icon = if (saved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder
                if (app.state.edition.editable) {
                    IconToggleButton(
                        checked = saved,
                        onCheckedChange = { app.model.saveEvent(event.eventID) },
                    ) {
                        Icon(
                            icon,
                            stringResource(
                                if (saved) R.string.unsave_event else R.string.save_event
                            ),
                            tint =
                                if (saved) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    Icon(
                        icon,
                        stringResource(if (saved) R.string.unsave_event else R.string.save_event),
                    )
                }
            },
        ) {
            Text(event.artist.name)
        }
    }
}

private fun friendConcertDay(event: ProgramOccurrence, pattern: String): String? =
    (event.assignedDay?.date?.start ?: event.startTimestamp ?: event.knownDateTimestamp)?.let {
        dateTime(it, pattern, event.zoneID)
    }

private fun friendProfileRowPadding(index: Int): Modifier =
    Modifier.padding(start = 16.dp, end = 16.dp, top = if (index == 0) 0.dp else 2.dp)

@Composable
private fun FriendProfileThumbnail(artist: ProgramArtist) {
    ArtistPhoto(artist, Modifier.size(48.dp).clip(MaterialTheme.shapes.medium), description = null)
}

@Composable
private fun FriendProfileCarousel(
    events: List<ProgramOccurrence>,
    ratings: List<FriendProfileRating>,
) {
    val app = LocalApp.current
    HorizontalUncontainedCarousel(
        state = rememberCarouselState { events.size + ratings.size },
        modifier = Modifier.fillMaxWidth(),
        itemWidth = 160.dp,
        itemSpacing = 12.dp,
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) { index ->
        val event = events.getOrNull(index)
        val rating = ratings.getOrNull(index - events.size)
        val artist = event?.artist ?: rating?.artist ?: return@HorizontalUncontainedCarousel
        Column(
            Modifier.maskClip(RectangleShape).clickable {
                if (event != null) app.event(event.eventID) else app.artist(artist.artistID)
            },
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            ArtistPhoto(
                artist,
                Modifier.fillMaxWidth().aspectRatio(1f).clip(MaterialTheme.shapes.large),
                fullSize = true,
                description = null,
            )
            Text(
                artist.name,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (event != null) {
                Text(
                    listOfNotNull(
                            friendConcertDay(event, "EEE"),
                            event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) },
                        )
                        .joinToString(" · ")
                        .ifEmpty { stringResource(R.string.unknown_date) },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else if (rating != null) {
                FriendPreference(rating.preference)
            }
        }
    }
}

@Composable
private fun FriendPreference(preference: ArtistPreference) {
    val description =
        if (preference.rating > 0)
            stringResource(R.string.friends_profile_rating_value, preference.rating)
        else
            stringResource(
                alternativeRatings.firstOrNull { it.first == preference.iconName }?.second
                    ?: R.string.not_interested
            )
    Row(
        Modifier.clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (preference.rating > 0)
            RatingHeartIcon(
                preference.rating,
                Modifier.size(22.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
        else Icon(negativeSymbol(preference.iconName), null, Modifier.size(22.dp))
        Text(
            description,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
