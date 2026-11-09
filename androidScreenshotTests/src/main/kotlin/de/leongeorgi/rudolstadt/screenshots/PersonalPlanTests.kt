package de.leongeorgi.rudolstadt.screenshots

import android.os.Bundle
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import java.io.File
import org.junit.Assert.*
import org.junit.Test

/** Runs through the real navigation with an isolated, restored local emulator profile. */
class PersonalPlanTests {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val german =
        InstrumentationRegistry.getArguments().getString("screenshotLocale") == "de"
    private val app = "de.leongeorgi.rudolstadt.android"
    private val settings = "files/datastore/rudolstadt.json"
    private val directory =
        File(requireNotNull(instrumentation.context.getExternalFilesDir(null)), "personal-plan")

    private fun find(selector: BySelector, timeout: Long = 20_000): UiObject2 =
        requireNotNull(device.wait(Until.findObject(selector), timeout)) {
            "Element not found: $selector"
        }

    private fun capture(name: String) {
        directory.mkdirs()
        uiAutomator { waitForStableInActiveWindow(8_000, 750, 100, false) }
        assertTrue(device.takeScreenshot(File(directory, "$name.png")))
        File(directory, "$name.xml").also { device.dumpWindowHierarchy(it) }
        instrumentation.sendStatus(
            0,
            Bundle().apply { putString("screenshotDirectory", directory.absolutePath) },
        )
    }

    private fun launchPlan() {
        device.executeShellCommand("am start -W -n $app/.MainActivity")
        find(By.desc(if (german) "Mein Plan" else "My plan"), 180_000)
        find(By.text(if (german) "Sa. 4" else "Sat 4")).click()
        find(By.desc(if (german) "Mein Plan" else "My plan")).click()
        find(By.res("personal-plan-screen"))
    }

    private fun withProfile(saved: List<Long>, body: () -> Unit) {
        check(device.executeShellCommand("getprop ro.kernel.qemu").trim() == "1")
        device.executeShellCommand("am force-stop $app")
        val original = device.executeShellCommand("run-as $app cat $settings")
        check(original.trim().startsWith("{")) { "Initialize the app before running this test" }
        val backup = File(instrumentation.context.filesDir, "personal-plan-original.json")
        backup.writeText(original)
        fun write(json: String) {
            val file =
                File(requireNotNull(instrumentation.context.externalCacheDir), "plan-profile.json")
            file.parentFile?.mkdirs()
            file.writeText(json)
            val staging = "/data/local/tmp/rudolstadt-plan-profile.json"
            device.executeShellCommand("cp ${file.absolutePath} $staging")
            device.executeShellCommand("chmod 644 $staging")
            device.executeShellCommand("run-as $app mkdir -p files/datastore")
            device.executeShellCommand("run-as $app cp $staging $settings")
            check(device.executeShellCommand("run-as $app cat $settings").trim() == json.trim())
            device.executeShellCommand("rm $staging")
            file.delete()
        }
        val seed =
            """{"edition":"rudolstadt/2026","theme":"system","dynamicColor":false,"profiles":{"rudolstadt/2026":{"savedEventIDs":[${saved.joinToString(",")}],"artistPreferences":[{"artistID":268,"rating":3}]}},"scheduleFilters":{}}"""
        try {
            write(seed)
            body()
        } finally {
            device.executeShellCommand("am force-stop $app")
            write(original)
            backup.delete()
        }
    }

    @Test
    fun emptyDayAndRecommendationMenu() =
        withProfile(emptyList()) {
            launchPlan()
            find(
                By.text(
                    if (german) "Noch keine gemerkten Konzerte für diesen Tag."
                    else "No saved concerts for this day yet."
                )
            )
            capture("empty")
            find(By.desc(if (german) "Optionen für Mein Plan" else "My plan options")).click()
            find(By.text(if (german) "Empfehlungen anzeigen" else "Show recommendations"))
            capture("recommendation-menu")
            device.pressBack()
            device.pressBack()
            find(By.desc(if (german) "Mein Plan" else "My plan"))
            assertTrue(find(By.text(if (german) "Sa. 4" else "Sat 4")).parent.isSelected)
        }

    @Test
    fun savedConcertsWalkingConflictsAndRemoval() =
        withProfile(listOf(353, 158, 209, 204)) {
            launchPlan()
            val artist = find(By.text("Ramsch & Rosen"))
            val time = find(By.text("12:00"))
            assertTrue(
                "A start time must stay on a single line",
                time.visibleBounds.height() <= artist.visibleBounds.height(),
            )
            find(By.text(if (german) "Freie Zeit" else "Free time"))
            find(By.res("personal-plan-routes-158"))
            find(
                By.textContains(if (german) "Möglicher Zeitkonflikt" else "Possible time conflict")
            )
            capture("saved")
            find(By.res("personal-plan-event-353")).click()
            find(By.text("Ramsch & Rosen"))
            device.pressBack()
            find(By.res("personal-plan-screen"))
            find(By.desc(if (german) "Optionen für Mein Plan" else "My plan options")).click()
            find(By.text(if (german) "Empfehlungen anzeigen" else "Show recommendations")).click()
            find(By.text("Ramsch & Rosen"))
            capture("recommendations")
            find(By.res("personal-plan-save-353")).click()
            assertTrue(device.wait(Until.gone(By.res("personal-plan-event-353")), 10_000))
            capture("after-removal")
        }
}
