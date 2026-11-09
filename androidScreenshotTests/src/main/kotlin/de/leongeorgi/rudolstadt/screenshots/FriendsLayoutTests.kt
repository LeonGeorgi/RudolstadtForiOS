package de.leongeorgi.rudolstadt.screenshots

import android.os.Bundle
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import java.io.File
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class FriendsLayoutTests {
    @Test
    fun captureConnectedFriendLayouts() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val device = UiDevice.getInstance(instrumentation)
        val args = InstrumentationRegistry.getArguments()
        val output =
            File(
                requireNotNull(instrumentation.context.getExternalFilesDir(null)),
                "friends-${System.currentTimeMillis()}",
            )
        output.mkdirs()
        device.setOrientationPortrait()
        fun find(selector: BySelector, timeout: Long = 30_000): UiObject2 =
            requireNotNull(device.wait(Until.findObject(selector), timeout)) {
                "Missing UI element: $selector"
            }
        fun capture(name: String) {
            uiAutomator { waitForStableInActiveWindow(10_000, 700, 150, false) }
            assertTrue(device.takeScreenshot(File(output, "$name.png")))
            device.dumpWindowHierarchy(File(output, "$name.xml"))
        }
        fun clickText(value: String) = find(By.text(value)).click()
        device.executeShellCommand("am start -W -n de.leongeorgi.rudolstadt.android/.MainActivity")
        find(By.desc("Mehr"), 90_000).click()
        clickText("Einstellungen")
        val palette = By.text("Farben des Hintergrundbilds verwenden")
        repeat(4) {
            if (!device.hasObject(palette)) device.swipe(600, 2100, 600, 700, 35)
        }
        val paletteRow = find(palette).parent
        val toggle =
            paletteRow.findObject(By.checkable(true))
                ?: paletteRow.parent.findObject(By.checkable(true))
        if (toggle?.isChecked == true) toggle.click()
        device.pressBack()
        clickText("Freunde")
        val login = device.wait(Until.findObject(By.text("Mit Schlüssel anmelden")), 5_000)
        if (login != null) {
            login.click()
            val credentials =
                JSONObject(
                    device.executeShellCommand(
                        "cat " + requireNotNull(args.getString("credentialsFile"))
                    )
                )
            find(By.clazz("android.widget.EditText")).text = credentials.getString("key")
            clickText("Mit Schlüssel anmelden")
        }
        find(By.desc("Freunde hinzufügen"), 60_000)
        find(By.res("friends-all"), 45_000)
        Thread.sleep(5_000)
        capture("full")
        find(By.desc("Freunde hinzufügen")).click()
        capture("plus")
        clickText("Einladung erstellen")
        find(By.text("Einladung teilen"), 45_000)
        capture("qr")
        device.pressBack()
        find(By.desc("Jetzt synchronisieren"))
        find(By.desc("Mein Profil")).click()
        find(By.text("Profil bearbeiten"))
        capture("profile")
        clickText("Profil bearbeiten")
        find(By.text("Badge-Farbe"))
        find(By.desc("Farbton"))
        capture("color")
        device.pressBack()
        find(By.res("friends-all")).click()
        find(By.text("Alle Freunde"))
        clickText("Test · Ben")
        find(By.textContains("Merker"))
        capture("detail")
        device.pressBack()
        find(By.text("Alle Freunde"))
        device.pressBack()
        find(By.res("friends-recommendations")).click()
        find(By.text("Freundesempfehlungen"))
        Thread.sleep(4_000)
        capture("recommendations")
        device.pressBack()
        find(By.desc("Freunde hinzufügen")).click()
        clickText("Einladung erstellen")
        find(By.text("Einladung teilen"), 45_000)
        device.pressBack()
        device.unfreezeRotation()
        instrumentation.sendStatus(
            0,
            Bundle().apply { putString("screenshotDirectory", output.absolutePath) },
        )
    }
}
