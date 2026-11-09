package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp
import de.leongeorgi.rudolstadt.presentation.ProfileColors

@Composable
internal fun ProfileBadgeAvatar(
    name: String,
    hue: Double,
    size: Dp,
    modifier: Modifier = Modifier,
) {
    val color =
        remember(hue) {
            ProfileColors.rgb(hue).let { Color(it.r.toFloat(), it.g.toFloat(), it.b.toFloat()) }
        }
    val initials =
        remember(name) {
            val words = name.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }
            if (words.size > 1) words.take(2).joinToString("") { it.take(1) }.uppercase()
            else name.filter { it.isLetterOrDigit() }.take(2).uppercase().ifEmpty { "?" }
        }
    val fontSize = with(LocalDensity.current) { (size * (4f / 9f)).toSp() }

    Box(modifier.size(size).background(color, CircleShape), contentAlignment = Alignment.Center) {
        Text(
            initials,
            color = Color.White,
            style =
                MaterialTheme.typography.titleMedium.copy(
                    fontSize = fontSize,
                    lineHeight = fontSize * 1.2f,
                    letterSpacing = 0.sp,
                    fontWeight = FontWeight.Medium,
                ),
            maxLines = 1,
            softWrap = false,
        )
    }
}
