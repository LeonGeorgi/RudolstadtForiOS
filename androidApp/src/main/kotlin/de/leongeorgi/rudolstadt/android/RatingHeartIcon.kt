package de.leongeorgi.rudolstadt.android

import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource

@Composable
internal fun RatingHeartIcon(
    rating: Int,
    modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current,
) {
    val asset =
        when (rating.coerceIn(1, 3)) {
            1 -> R.drawable.rating_heart_1
            2 -> R.drawable.rating_heart_2
            else -> R.drawable.rating_heart_3
        }
    Icon(painterResource(asset), null, modifier, tint = tint)
}
