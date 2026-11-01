package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence

@Composable
internal fun EventTimeBadge(
    event: ProgramOccurrence,
    size: Dp = 48.dp,
    headerColor: Color? = null,
) {
    val date = event.startTimestamp ?: event.knownDateTimestamp
    val time = event.startTimestamp?.let { dateTime(it, "HH:mm", event.zoneID) } ?: "—"
    val description =
        eventDate(event) +
            " · " +
            (event.startTimestamp?.let { time } ?: stringResource(R.string.unknown_time)) +
            (event.confirmedDuration?.let {
                " · " + stringResource(R.string.duration, it.minutes)
            } ?: "")
    val scale = size.value / 48f
    val density = LocalDensity.current
    Column(
        Modifier.size(size)
            .clip(RoundedCornerShape(8.dp * scale))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .clearAndSetSemantics { contentDescription = description },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            date?.let { dateTime(it, "EEE", event.zoneID).uppercase() } ?: "?",
            Modifier.fillMaxWidth()
                .background(headerColor ?: MaterialTheme.colorScheme.primary.copy(alpha = .12f)),
            style = MaterialTheme.typography.labelSmall,
            color = headerColor?.let { contentColorFor(it) } ?: LocalContentColor.current,
            fontSize = MaterialTheme.typography.labelSmall.fontSize * scale / density.fontScale,
            lineHeight = MaterialTheme.typography.labelSmall.lineHeight * scale / density.fontScale,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(
                time,
                style = MaterialTheme.typography.labelLarge,
                fontSize = MaterialTheme.typography.labelLarge.fontSize * scale / density.fontScale,
                lineHeight =
                    MaterialTheme.typography.labelLarge.lineHeight * scale / density.fontScale,
                fontFamily = FontFamily.Monospace,
                maxLines = 1,
            )
        }
    }
}
