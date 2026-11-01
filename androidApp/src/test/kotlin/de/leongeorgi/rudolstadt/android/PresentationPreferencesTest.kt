package de.leongeorgi.rudolstadt.android

import de.leongeorgi.rudolstadt.android.data.LocalSettings
import de.leongeorgi.rudolstadt.android.data.SettingsSerializer
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class PresentationPreferencesTest {
    @Test
    fun existingSettingsRemainReadableAfterAddingGridDensityAndEditionFilters() = runBlocking {
        val old =
            """{"edition":"rudolstadt/2025","artistLayout":"grid","theme":"dark","profiles":{},"readNews":[42]}"""
        val settings = SettingsSerializer.readFrom(ByteArrayInputStream(old.toByteArray()))
        assertEquals("rudolstadt/2025", settings.edition)
        assertEquals("grid", settings.artistLayout)
        assertEquals("comfortable", settings.artistGridDensity)
        assertEquals("dark", settings.theme)
        assertFalse(settings.alwaysShowEventDetails)
        assertEquals(setOf(42L), settings.readNews)
        assertEquals("all", settings.scheduleFilterFor(settings.edition, true))
    }

    @Test
    fun alwaysShowConcertDetailsSurvivesRelaunchAndFestivalChanges() = runBlocking {
        val settings = LocalSettings(alwaysShowEventDetails = true, edition = "ludwigsburg/2026")
        val output = ByteArrayOutputStream()
        SettingsSerializer.writeTo(settings, output)
        val restored = SettingsSerializer.readFrom(ByteArrayInputStream(output.toByteArray()))
        assertTrue(restored.alwaysShowEventDetails)
        assertTrue(restored.copy(edition = "rudolstadt/2025").alwaysShowEventDetails)
        assertFalse(restored.copy(alwaysShowEventDetails = false).alwaysShowEventDetails)
    }

    @Test
    fun filtersSurviveRelaunchIndependentlyForEachFestivalEdition() = runBlocking {
        val settings =
            LocalSettings(
                artistLayout = "grid",
                artistGridDensity = "compact",
                scheduleFilters =
                    mapOf(
                        "rudolstadt/2026" to "saved",
                        "rudolstadt/2025" to "interesting",
                        "ludwigsburg/2026" to "optimal",
                    ),
            )
        val output = ByteArrayOutputStream()
        SettingsSerializer.writeTo(settings, output)
        val restored = SettingsSerializer.readFrom(ByteArrayInputStream(output.toByteArray()))
        assertEquals(settings, restored)
        assertEquals("saved", restored.scheduleFilterFor("rudolstadt/2026", true))
        assertEquals("interesting", restored.scheduleFilterFor("rudolstadt/2025", true))
        assertEquals("optimal", restored.scheduleFilterFor("ludwigsburg/2026", true))
        assertEquals("all", restored.scheduleFilterFor("ludwigsburg/2026", false))
        assertEquals("all", restored.scheduleFilterFor("rudolstadt/2024", true))
    }

    @Test
    fun unrecognizedFiltersFallBackToAnAvailableView() {
        val settings = LocalSettings(scheduleFilters = mapOf("future" to "unsupported"))
        assertEquals("all", settings.scheduleFilterFor("future", true))
    }

    @Test
    fun normalHourConcertShowsItsTimeWithoutRequiringZoom() {
        val layout = TimelineCellLayout(DEFAULT_TIMELINE_COLUMN_WIDTH, 60 * 1.2f)
        assertTrue(layout.showTime)
        assertTrue(layout.titleLines >= 1)
        assertFalse(layout.showSummary)
        assertTrue(TimelineCellLayout(192f, 240f).showSummary)
    }

    @Test
    fun locationFromEarlierInTheDayIsNeverPresentedAsCurrent() {
        val second = 1_000_000_000L
        assertTrue(isRecentLocation(600 * second, 610 * second, 15_000))
        assertFalse(isRecentLocation(600 * second, 630 * second, 15_000))
        assertFalse(isRecentLocation(600 * second, 900 * second))
        assertFalse(isRecentLocation(0, 10 * second))
        assertFalse(isRecentLocation(610 * second, 600 * second))
    }
}
