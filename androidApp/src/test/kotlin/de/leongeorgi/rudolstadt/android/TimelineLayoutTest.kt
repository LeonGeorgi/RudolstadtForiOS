package de.leongeorgi.rudolstadt.android

import org.junit.Assert.*
import org.junit.Test

class TimelineLayoutTest {
    @Test
    fun zoomKeepsTheConcertUnderTheFingersInPlace() {
        val offset = anchoredTimelineOffset(240, 80f, 100f, 150f)
        assertEquals(400, offset)
        assertEquals((240 + 80f) / 100, (offset + 80f) / 150, .001f)
        assertEquals(240, anchoredTimelineOffset(offset, 80f, 150f, 100f))
    }

    @Test
    fun zoomLimitsDoNotMoveTheViewportWhenScaleCannotChange() {
        val limited = timelineZoom(192f, 1.5f, 72f, 192f)
        assertEquals(192f, limited, 0f)
        assertEquals(350, anchoredTimelineOffset(350, 90f, 192f, limited))
        assertEquals(72f, timelineZoom(80f, .1f, 72f, 192f), 0f)
        assertEquals(0, anchoredTimelineOffset(0, 200f, 150f, 72f))
    }

    @Test
    fun fastGestureUpdatesAccumulateWithoutLosingTheFocalPoint() {
        var pendingOffset = 0
        var scale = 1f
        repeat(20) {
            val next = scale + .05f
            pendingOffset = anchoredTimelineOffset(pendingOffset, 600f, scale, next)
            scale = next
        }
        assertEquals(600f, pendingOffset.toFloat(), 2f)
        assertEquals(600f, (pendingOffset + 600f) / scale, 2f)
    }

    @Test
    fun invalidGestureGeometryCannotCorruptTheScale() {
        listOf(Float.NaN, Float.POSITIVE_INFINITY, 0f, -1f).forEach {
            assertEquals(104f, timelineZoom(104f, it, 72f, 192f), 0f)
        }
    }
}
