@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.fromHtml
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.discovery.NewsLinkPreview
import de.leongeorgi.rudolstadt.discovery.NewsWebLink
import de.leongeorgi.rudolstadt.discovery.ProgramMentions
import de.leongeorgi.rudolstadt.discovery.TextSearch
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

@Composable
internal fun NewsScreen() {
    val app = LocalApp.current
    val news by app.model.news.state.collectAsStateWithLifecycle()
    val items = news.items.filter { it.languageCode == language }
    Page(
        stringResource(R.string.news_title),
        back = false,
        actions = {
            IconButton(onClick = app.model::markAllRead, enabled = app.state.edition.live) {
                Icon(Icons.Default.DoneAll, stringResource(R.string.mark_all_read))
            }
            IconButton(
                onClick = { app.model.refreshNews(true) },
                enabled = app.state.edition.live,
            ) {
                Icon(Icons.Default.Refresh, stringResource(R.string.refresh))
            }
        },
    ) { modifier ->
        if (!app.state.edition.live)
            Box(modifier) { Status(stringResource(R.string.news_unavailable)) }
        else
            PullToRefreshBox(app.state.newsRefreshing, { app.model.refreshNews(true) }, modifier) {
                LazyColumn(Modifier.fillMaxSize()) {
                    item {
                        Text(
                            stringResource(
                                when (news.source) {
                                    "remote" -> R.string.news_source_remote
                                    "cache" -> R.string.news_source_cache
                                    else -> R.string.news_source_bundle
                                }
                            ),
                            Modifier.padding(16.dp),
                            style = MaterialTheme.typography.labelMedium,
                        )
                        if (news.notice != null)
                            Text(
                                stringResource(R.string.refresh_failed),
                                Modifier.padding(horizontal = 16.dp),
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodySmall,
                            )
                    }
                    if (items.isEmpty())
                        item {
                            Text(
                                stringResource(
                                    if (news.failure != null) R.string.refresh_failed
                                    else if (app.state.newsRefreshing) R.string.loading
                                    else R.string.news_empty
                                ),
                                Modifier.padding(24.dp),
                            )
                        }
                    items(items, key = { it.newsID }) { item ->
                        val unread = item.newsID !in app.state.settings.readNews
                        var menu by remember(item.newsID) { mutableStateOf(false) }
                        ListItem(
                            headlineContent = {
                                Text(
                                    item.shortDescription,
                                    style =
                                        if (unread) MaterialTheme.typography.titleMedium
                                        else MaterialTheme.typography.bodyLarge,
                                )
                            },
                            overlineContent = {
                                Text("${item.dateAsString} · ${item.timeAsString}")
                            },
                            supportingContent = { Text(item.longDescription, maxLines = 3) },
                            trailingContent = {
                                Box {
                                    IconButton(onClick = { menu = true }) {
                                        Icon(
                                            Icons.Default.MoreVert,
                                            stringResource(R.string.more_title),
                                        )
                                    }
                                    DropdownMenu(menu, { menu = false }) {
                                        DropdownMenuItem(
                                            text = {
                                                Text(
                                                    stringResource(
                                                        if (unread) R.string.mark_read
                                                        else R.string.mark_unread
                                                    )
                                                )
                                            },
                                            onClick = {
                                                app.model.toggleRead(item.newsID)
                                                menu = false
                                            },
                                        )
                                    }
                                }
                            },
                            leadingContent = {
                                if (unread)
                                    Icon(
                                        Icons.Default.Circle,
                                        stringResource(R.string.unread),
                                        Modifier.size(10.dp),
                                        tint = MaterialTheme.colorScheme.primary,
                                    )
                            },
                            modifier = Modifier.clickable { app.navigate("news/${item.newsID}") },
                        )
                    }
                }
            }
    }
}

@Composable
internal fun NewsDetail(id: Long?) {
    val app = LocalApp.current
    val news by app.model.news.state.collectAsStateWithLifecycle()
    val message =
        news.items.firstOrNull { it.newsID == id && it.languageCode == language }
            ?: news.items.firstOrNull { it.newsID == id }
    LaunchedEffect(message?.newsID) { message?.let { app.model.markRead(it.newsID) } }
    Page(message?.shortDescription ?: stringResource(R.string.news_title)) { modifier ->
        if (message == null)
            Box(modifier) {
                Status(
                    if (app.state.newsRefreshing) null else stringResource(R.string.not_found),
                    if (!app.state.newsRefreshing) ({ app.model.refreshNews(true) }) else null,
                )
            }
        else {
            val mentions =
                remember(message, app.content.program, app.language) {
                    val normalized =
                        TextSearch.normalizedMention(
                            foldText(
                                androidx.core.text.HtmlCompat.fromHtml(
                                        listOf(
                                                message.shortDescription,
                                                message.longDescription,
                                                message.content,
                                            )
                                            .joinToString("\n"),
                                        androidx.core.text.HtmlCompat.FROM_HTML_MODE_LEGACY,
                                    )
                                    .toString()
                            )
                        )
                    ProgramMentions.find(
                        normalized,
                        app.content.program.artists,
                        app.content.program.places,
                        { TextSearch.normalizedMention(foldText(it.name)) },
                        { TextSearch.normalizedMention(foldText(it.names.text(app.language))) },
                    )
                }
            val linkStyles =
                TextLinkStyles(
                    SpanStyle(
                        color = MaterialTheme.colorScheme.primary,
                        textDecoration = TextDecoration.Underline,
                    )
                )
            val text =
                remember(message, mentions, linkStyles, app.nav, app.language) {
                    linkedNewsText(
                        AnnotatedString(message.longDescription),
                        AnnotatedString.fromHtml(message.content, linkStyles = linkStyles),
                        mentions.artists,
                        linkStyles,
                        places = mentions.places,
                        placeName = { it.names.text(app.language) },
                        onPlaceClick = { app.place(it) },
                    ) {
                        app.artist(it)
                    }
                }
            val context = LocalContext.current
            val previews by
                produceState<Map<String, NewsLinkPreview>>(emptyMap(), text.webLinks) {
                    value = emptyMap()
                    val links =
                        text.webLinks.values
                            .filter { it.emailAddress == null }
                            .distinctBy { it.url }
                    if (links.isEmpty()) return@produceState
                    val cache = NewsPreviewCache(context.applicationContext)
                    try {
                        coroutineScope {
                            links.forEach { link ->
                                launch {
                                    cache.load(link.url)?.let {
                                        value = value + (link.url to it)
                                    }
                                }
                            }
                        }
                    } finally {
                        cache.close()
                    }
                }
            LazyColumn(modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
                item {
                    Text(
                        message.shortDescription,
                        Modifier.padding(16.dp),
                        style = MaterialTheme.typography.headlineMedium,
                    )
                }
                item {
                    Text(
                        "${message.dateAsString} · ${message.timeAsString}",
                        Modifier.padding(horizontal = 16.dp),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
                if (message.longDescription.isNotBlank())
                    item {
                        NewsArticleText(
                            text,
                            previews,
                            true,
                            Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp),
                        )
                    }
                if (text.content.isNotBlank())
                    item {
                        SelectionContainer {
                            NewsArticleText(
                                text,
                                previews,
                                false,
                                Modifier.padding(16.dp),
                            )
                        }
                    }
                if (mentions.artists.isNotEmpty())
                    item { Heading(stringResource(R.string.artists_title)) }
                items(mentions.artists, key = { it.artistID }) { ArtistRow(it) }
                if (mentions.places.isNotEmpty()) item { Heading(stringResource(R.string.places)) }
                items(mentions.places, key = { it.placeKey }) { PlaceRow(it) }
            }
        }
    }
}

@Composable
private fun NewsArticleText(
    text: NewsText,
    previews: Map<String, NewsLinkPreview>,
    subtitle: Boolean,
    modifier: Modifier,
) {
    BoxWithConstraints(modifier) {
        Text(
            if (subtitle) text.subtitle else text.content,
            style =
                if (subtitle) MaterialTheme.typography.titleLarge
                else MaterialTheme.typography.bodyLarge,
            inlineContent = newsInlineContent(text, previews, subtitle, maxWidth),
        )
    }
}

@Composable
private fun newsInlineContent(
    text: NewsText,
    previews: Map<String, NewsLinkPreview>,
    subtitle: Boolean,
    maxWidth: Dp,
): Map<String, InlineTextContent> {
    val app = LocalApp.current
    val density = LocalDensity.current
    val mentions =
        text.inlineContent.mapValues { (_, mention) ->
            val artist = mention.artist
            val place = mention.place
            val size = (if (artist != null && !subtitle) 18 else 20).sp
            val displaySize = with(density) { size.toDp() }
            val gap = with(density) { 4.sp.toDp() }
            InlineTextContent(
                Placeholder((size.value + 4).sp, size, PlaceholderVerticalAlign.TextCenter)
            ) {
                Box(
                    Modifier.fillMaxSize().padding(end = gap).clearAndSetSemantics {},
                    contentAlignment = Alignment.Center,
                ) {
                    if (artist != null) {
                        Box(
                            Modifier.size(displaySize)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                                .clickable { app.artist(artist.artistID) }
                        ) {
                            Icon(
                                Icons.Default.Person,
                                null,
                                Modifier.fillMaxSize(),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            AsyncImage(
                                model = artist.content.thumbnail ?: artist.content.image,
                                contentDescription = null,
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Crop,
                            )
                        }
                    } else if (place != null) {
                        Box(Modifier.clickable { app.place(place.placeKey) }) {
                            StageBadge(place, displaySize)
                        }
                    }
                }
            }
        }
    val measurer = rememberTextMeasurer()
    val chipStyle =
        MaterialTheme.typography.bodySmall.copy(
            fontSize = (if (subtitle) 15 else 13).sp,
            fontWeight = FontWeight.Medium,
            textDecoration = TextDecoration.None,
        )
    val webLinks =
        text.webLinks.mapValues { (_, link) ->
            val isWeb = link.emailAddress == null
            val preview = previews[link.url].takeIf { link.emailAddress == null }
            val width =
                with(density) {
                    (if (isWeb) maxWidth.toSp().value
                        else
                            measurer.measure(link.label, chipStyle).size.width.toSp().value +
                                16 +
                                if (link.emailAddress != null) 22 else 0)
                        .coerceAtMost(maxWidth.toSp().value)
                        .sp
                }
            InlineTextContent(
                Placeholder(
                    width,
                    (if (isWeb) 92 else if (subtitle) 28 else 26).sp,
                    PlaceholderVerticalAlign.TextCenter,
                )
            ) {
                NewsUrlChip(link, preview, chipStyle)
            }
        }
    return mentions + webLinks
}

@Composable
private fun NewsUrlChip(
    link: NewsWebLink,
    preview: NewsLinkPreview?,
    style: androidx.compose.ui.text.TextStyle,
) {
    val url = link.url
    val label = link.label
    val context = LocalContext.current
    val density = LocalDensity.current
    val email = link.emailAddress
    var menu by remember(url) { mutableStateOf(false) }
    val openLabel = stringResource(if (email != null) R.string.write_email else R.string.open_link)
    val copyLabel = stringResource(if (email != null) R.string.copy_email else R.string.copy_link)
    val scalePadding = with(density) { (if (email == null) 10 else 8).sp.toDp() }
    BoxWithConstraints {
        val thumbnailLimit = maxWidth * 0.28f
        Box(
            Modifier.fillMaxSize()
                .clip(RoundedCornerShape(if (email == null) 12.dp else 6.dp))
                .background(MaterialTheme.colorScheme.secondaryContainer)
                .combinedClickable(
                    onClick = { openURL(context, url) },
                    onLongClick = { menu = true },
                    onLongClickLabel = copyLabel,
                )
                .padding(horizontal = scalePadding),
            contentAlignment = Alignment.Center,
        ) {
            if (email == null) {
                Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                    val side = with(density) { 72.sp.toDp() }.coerceAtMost(thumbnailLimit)
                    Box(
                        Modifier.size(side)
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.Link,
                            null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        AsyncImage(
                            preview?.imageURL,
                            null,
                            Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                    }
                    Spacer(Modifier.width(with(density) { 12.sp.toDp() }))
                    Column(Modifier.weight(1f)) {
                        Text(
                            preview?.title ?: label,
                            style = style.copy(fontSize = 15.sp),
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            preview?.domain
                                ?: de.leongeorgi.rudolstadt.discovery.NewsLinkPreviews.domain(url),
                            style = style.copy(fontSize = 12.sp, fontWeight = FontWeight.Normal),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            } else
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (email != null) {
                        Icon(
                            Icons.Default.MailOutline,
                            null,
                            Modifier.size(with(density) { 16.sp.toDp() }),
                            tint = MaterialTheme.colorScheme.onSecondaryContainer,
                        )
                        Spacer(Modifier.width(with(density) { 6.sp.toDp() }))
                    }
                    Text(
                        label,
                        style = style,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
        }
        DropdownMenu(menu, { menu = false }) {
            Text(
                email ?: url,
                Modifier.padding(horizontal = 16.dp, vertical = 8.dp).widthIn(max = 280.dp),
                style = MaterialTheme.typography.bodySmall,
            )
            DropdownMenuItem(
                text = { Text(openLabel) },
                onClick = {
                    menu = false
                    openURL(context, url)
                },
            )
            DropdownMenuItem(
                text = { Text(copyLabel) },
                onClick = {
                    context
                        .getSystemService(android.content.ClipboardManager::class.java)
                        .setPrimaryClip(android.content.ClipData.newPlainText(label, email ?: url))
                    menu = false
                },
            )
        }
    }
}
