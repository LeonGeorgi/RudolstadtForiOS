package de.leongeorgi.rudolstadt.screenshots

import android.os.Bundle
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import androidx.test.uiautomator.uiAutomator
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class MainScreenshots {
    @Test
    fun captureMainScreens() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        val german = arguments.getString("screenshotLocale") == "de"
        val directory =
            File(requireNotNull(instrumentation.context.getExternalFilesDir(null)), "screenshots")
        directory.mkdirs()
        directory.listFiles()?.forEach { require(it.delete()) }
        val device = UiDevice.getInstance(instrumentation)
        device.setOrientationPortrait()
        device.executeShellCommand("am start -W -n de.leongeorgi.rudolstadt.android/.MainActivity")

        fun find(selector: BySelector, timeout: Long = 20_000): UiObject2 =
            requireNotNull(device.wait(Until.findObject(selector), timeout)) {
                "Element not found: $selector"
            }

        fun capture(name: String) {
            uiAutomator { waitForStableInActiveWindow(8_000, 500, 100, false) }
            assertTrue(
                "Could not capture $name",
                device.takeScreenshot(File(directory, "$name.png")),
            )
        }

        find(By.desc(if (german) "Filter: Alle" else "Filters: All"), 60_000)
        capture("01-schedule")
        find(By.desc(if (german) "Künstler" else "Artists")).click()
        find(By.desc(if (german) "Künstler suchen" else "Search artists"))
        capture("02-artists")
        find(By.desc(if (german) "Orte" else "Locations")).click()
        find(By.desc(if (german) "Bühnen und Orte suchen" else "Search stages and places"))
        find(By.res("city-map-ready"), 30_000)
        capture("03-locations")
        find(By.desc(if (german) "Mehr" else "More")).click()
        find(By.text(if (german) "Einstellungen" else "Settings"))
        capture("04-more")
        device.unfreezeRotation()
        instrumentation.sendStatus(
            0,
            Bundle().apply { putString("screenshotDirectory", directory.absolutePath) },
        )
    }
}
