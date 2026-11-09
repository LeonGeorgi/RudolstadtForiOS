package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.presentation.*
import de.leongeorgi.rudolstadt.profile.*
import kotlin.math.pow
import kotlin.test.*

class ProfileColorsTests {
    @Test
    fun ringPositionsSelectTheSameHueAtEverySize() {
        for (diameter in listOf(232.0, 464.0, 696.0)) {
            assertEquals(0.0, ProfileColors.hueAt(diameter / 2, 0.0, diameter))
            assertEquals(90.0, ProfileColors.hueAt(diameter, diameter / 2, diameter))
            assertEquals(180.0, ProfileColors.hueAt(diameter / 2, diameter, diameter))
            assertEquals(270.0, ProfileColors.hueAt(0.0, diameter / 2, diameter))
            assertEquals(
                45.0,
                assertNotNull(ProfileColors.hueAt(diameter * 0.8, diameter * 0.2, diameter)),
                0.000001,
            )
        }
        assertTrue(assertNotNull(ProfileColors.hueAt(116.01, 10.0, 232.0)) < 0.01)
        assertTrue(assertNotNull(ProfileColors.hueAt(115.99, 10.0, 232.0)) > 359.99)
    }

    @Test
    fun ringIgnoresTheBadgeCenterCornersAndInvalidCoordinates() {
        assertNull(ProfileColors.hueAt(116.0, 116.0, 232.0))
        assertNull(ProfileColors.hueAt(0.0, 0.0, 232.0))
        assertNull(ProfileColors.hueAt(116.0, -20.0, 232.0))
        assertNull(ProfileColors.hueAt(Double.NaN, 0.0, 232.0))
        assertNull(ProfileColors.hueAt(116.0, Double.POSITIVE_INFINITY, 232.0))
        assertNull(ProfileColors.hueAt(0.0, 0.0, 0.0))
        assertNull(ProfileColors.hueAt(0.0, 0.0, Double.NaN))
    }

    @Test
    fun activeRingDragProjectsOutsideAndInsideTheRingWithoutStopping() {
        assertEquals(0.0, ProfileColors.hueForDrag(116.0, -100.0, 232.0))
        assertEquals(90.0, ProfileColors.hueForDrag(500.0, 116.0, 232.0))
        assertEquals(180.0, ProfileColors.hueForDrag(116.0, 500.0, 232.0))
        assertEquals(270.0, ProfileColors.hueForDrag(-100.0, 116.0, 232.0))
        assertEquals(90.0, ProfileColors.hueForDrag(160.0, 116.0, 232.0))
        assertEquals(315.0, ProfileColors.hueForDrag(0.0, 0.0, 232.0))
        assertEquals(
            ProfileColors.hueAt(180.0, 52.0, 232.0),
            ProfileColors.hueForDrag(500.0, -268.0, 232.0),
        )
        assertEquals(
            ProfileColors.hueAt(360.0, 104.0, 464.0),
            ProfileColors.hueForDrag(1000.0, -536.0, 464.0),
        )
        assertNull(ProfileColors.hueAt(500.0, 116.0, 232.0))
    }

    @Test
    fun activeRingDragKeepsItsLastHueNearTheCenterAndIgnoresInvalidPositions() {
        assertNull(ProfileColors.hueForDrag(116.0, 116.0, 232.0))
        assertNull(ProfileColors.hueForDrag(117.0, 115.0, 232.0))
        assertNull(ProfileColors.hueForDrag(Double.NaN, 0.0, 232.0))
        assertNull(ProfileColors.hueForDrag(116.0, Double.POSITIVE_INFINITY, 232.0))
        assertNull(ProfileColors.hueForDrag(0.0, 0.0, 0.0))
    }

    @Test
    fun hueWrapsAtOneTurnAndInvalidValuesUseTheDefault() {
        assertEquals(0.0, ProfileReducer.resolvedHue(360.0))
        assertEquals(330.0, ProfileReducer.resolvedHue(-30.0))
        for (value in listOf(null, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertEquals(ProfileReducer.defaultHue, ProfileReducer.resolvedHue(value))
        }
        assertEquals(ProfileColors.rgb(30.0), ProfileColors.rgb(390.0))
    }

    @Test
    fun allHuesRenderInSRGBUsingTheSameOKHSLPolicy() {
        for (hue in 0 until 360) {
            val rgb = ProfileColors.rgb(hue.toDouble())
            assertTrue(listOf(rgb.r, rgb.g, rgb.b).all { it.isFinite() && it in 0.0..1.0 })
            val okhsl = ColorMath.srgbToOKHSL(rgb)
            assertEquals(ProfileColors.saturation, okhsl.s, 0.0001)
            assertEquals(ProfileColors.lightness, okhsl.l, 0.0001)
        }
        assertNotEquals(ProfileColors.rgb(30.0), ProfileColors.rgb(210.0))
    }

    @Test
    fun whiteBadgeTextRetainsTheApprovedPaletteContrastAcrossTheHueCircle() {
        fun linear(channel: Double): Double =
            if (channel <= 0.04045) channel / 12.92 else ((channel + 0.055) / 1.055).pow(2.4)
        for (step in 0 until 3600) {
            val hue = step / 10.0
            val rgb = ProfileColors.rgb(hue)
            val luminance = 0.2126 * linear(rgb.r) + 0.7152 * linear(rgb.g) + 0.0722 * linear(rgb.b)
            // The selected S 75 % / L 55 % palette has a minimum white contrast of about 3.56:1.
            assertTrue(1.05 / (luminance + 0.05) >= 3.5, "White text contrast at hue $hue")
        }
    }

    @Test
    fun hueSurvivesPrivateSyncAndFriendProjectionWithoutRGBFields() {
        val profile =
            ProfileReducer.apply(
                PersonalProfile(),
                ProfileMutation("updateBadge", text = "Alex", hue = 210.5),
            )
        val record =
            OwnProfileData.badge(profile.badgeName, profile.badgeHue, ProfileVersion(1.0, "a"))
        val encoded = OwnProfileData.encodeRecords(listOf(record))
        assertTrue(encoded.contains("\"hue\":210.5"))
        assertFalse(encoded.contains("color", ignoreCase = true))
        assertEquals(profile, OwnProfileData.profile(OwnProfileData.decodeRecords(encoded)))
        assertEquals(
            210.5,
            FriendSharing.profile(
                    "id",
                    "rudolstadt-2026",
                    FriendIdentity("Alex", 210.5),
                    emptyList(),
                    emptyList(),
                )
                .badgeHue,
        )
        assertTrue(OwnProfileData.compare(record.copy(hue = 100.0), record.copy(hue = 30.0)) > 0)
    }

    @Test
    fun missingHueResetsOldQueuedBadgeColorsToAnUploadableDefault() {
        val old =
            """[{"key":"profile","version":{"modifiedAt":1,"changeID":"old"},"badgeName":"Alex","badgeColor":"#FFFFFF"}]"""
        val records = OwnProfileData.decodeRecords(old)
        assertEquals(ProfileReducer.defaultHue, records.single().hue)
        assertTrue(OwnProfileData.encodeRecords(records).contains("\"hue\":30.0"))
    }
}
