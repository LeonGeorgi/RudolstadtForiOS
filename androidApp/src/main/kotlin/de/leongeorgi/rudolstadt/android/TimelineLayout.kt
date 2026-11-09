package de.leongeorgi.rudolstadt.android

import kotlin.math.roundToInt

// Match the iOS timeline's 71-point cards plus 4-point column spacing.
internal const val DEFAULT_TIMELINE_COLUMN_WIDTH = 75f
internal const val TIMELINE_TIME_COLUMN_WIDTH = 58f

/** Preserve the content under a pinch focal point, including when a zoom limit is reached. */
internal fun anchoredTimelineOffset(
    offset: Int,
    focus: Float,
    oldScale: Float,
    newScale: Float,
): Int = (((offset + focus) * newScale / oldScale) - focus).roundToInt().coerceAtLeast(0)

internal fun timelineZoom(current: Float, factor: Float, minimum: Float, maximum: Float): Float =
    if (factor.isFinite() && factor > 0) (current * factor).coerceIn(minimum, maximum) else current

/** Keep the start time readable at the default 60-minute cell size (75 × 72 dp). */
internal class TimelineCellLayout(width: Float, height: Float) {
    val showTime = height >= 48
    val titleLines = if (height < 64) 1 else if (height < 190) 2 else 3
    val showRating = height >= 96
    val showTag = height >= 116
    val showOrigin = height >= 150 && width >= 104
    val showSummary = height >= 220 && width >= 145
}
