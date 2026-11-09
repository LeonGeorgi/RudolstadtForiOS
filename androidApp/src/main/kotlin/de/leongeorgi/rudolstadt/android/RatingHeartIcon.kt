package de.leongeorgi.rudolstadt.android

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateOffset
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.updateTransition
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

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

private data class HeartPlacement(
    val scale: Float,
    val x: Float = 0f,
    val y: Float = 0f,
    val visible: Boolean = true,
)

// Centers and scales in the assets' 24-point viewport, ordered core, right, left.
private val heartPlacements =
    listOf(
        listOf(
            HeartPlacement(0.82f, visible = false),
            HeartPlacement(0.38f, visible = false),
            HeartPlacement(0.38f, visible = false),
        ),
        listOf(
            HeartPlacement(1f),
            HeartPlacement(0.38f, visible = false),
            HeartPlacement(0.38f, visible = false),
        ),
        listOf(
            HeartPlacement(0.78f / 1.35f, x = -5.525f, y = 2.5f),
            HeartPlacement(0.78f / 1.35f, x = 5.525f, y = -2.5f),
            HeartPlacement(0.38f, x = -5.525f, y = 2.5f, visible = false),
        ),
        listOf(
            HeartPlacement(0.67f / 1.35f, y = 6.56667f),
            HeartPlacement(0.67f / 1.35f, x = 5.9f, y = -3.28333f),
            HeartPlacement(0.67f / 1.35f, x = -5.9f, y = -3.28333f),
        ),
    )
private val heartMovementEasing = CubicBezierEasing(0.21f, 0.76f, 0.27f, 1f)
private val heartFadeEasing = CubicBezierEasing(0f, 0f, 0.58f, 1f)

@Composable
internal fun AnimatedRatingHeartIcon(rating: Int, modifier: Modifier, tint: Color) {
    val transition = updateTransition(rating.coerceIn(0, 3), label = "Heart rating")
    val painter = painterResource(R.drawable.rating_heart_1)
    val outlineOpacity by
        transition.animateFloat(
            transitionSpec = { tween(135, easing = heartFadeEasing) },
            label = "Empty heart opacity",
        ) { state ->
            if (state == 0) 1f else 0f
        }
    Box(modifier, contentAlignment = Alignment.Center) {
        Icon(
            Icons.Default.FavoriteBorder,
            contentDescription = null,
            modifier = Modifier.size(24.dp).graphicsLayer { alpha = outlineOpacity },
            tint = tint,
        )
        for (index in heartPlacements.first().indices) {
            val offset by
                transition.animateOffset(
                    transitionSpec = { tween(285, easing = heartMovementEasing) },
                    label = "Heart position",
                ) { state ->
                    val placement = heartPlacements[state][index]
                    Offset(placement.x, placement.y)
                }
            val scale by
                transition.animateFloat(
                    transitionSpec = { tween(285, easing = heartMovementEasing) },
                    label = "Heart scale",
                ) { state ->
                    heartPlacements[state][index].scale
                }
            val opacity by
                transition.animateFloat(
                    transitionSpec = {
                        val delay =
                            if (heartPlacements[targetState][index].visible) index * 16 else 0
                        tween(135, delayMillis = delay, easing = heartFadeEasing)
                    },
                    label = "Heart opacity",
                ) { state ->
                    if (heartPlacements[state][index].visible) 1f else 0f
                }
            Icon(
                painter,
                contentDescription = null,
                modifier =
                    Modifier.matchParentSize().graphicsLayer {
                        translationX = offset.x * size.width / 24f
                        translationY = offset.y * size.height / 24f
                        scaleX = scale
                        scaleY = scale
                        alpha = opacity
                    },
                tint = tint,
            )
        }
    }
}
