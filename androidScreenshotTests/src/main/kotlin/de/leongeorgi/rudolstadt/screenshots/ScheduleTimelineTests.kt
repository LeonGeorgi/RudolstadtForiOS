package de.leongeorgi.rudolstadt.screenshots

import android.os.Bundle
import android.text.Html
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import java.io.File
import java.util.zip.ZipFile
import kotlin.math.abs
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class ScheduleTimelineTests {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val app = "de.leongeorgi.rudolstadt.android"
    private val german =
        InstrumentationRegistry.getArguments().getString("screenshotLocale") == "de"
    private val settings = "files/datastore/rudolstadt.json"
    private val directory =
        File(
            requireNotNull(instrumentation.context.getExternalFilesDir(null)),
            "schedule-timeline-${System.currentTimeMillis()}",
        )

    private fun find(selector: BySelector, timeout: Long = 20_000): UiObject2 =
        requireNotNull(device.wait(Until.findObject(selector), timeout)) {
            "Element not found: $selector"
        }

    private fun text(node: UiObject2): String =
        (listOfNotNull(node.text, node.contentDescription) + node.children.map(::text))
            .joinToString(" ")

    private fun source(): JSONObject {
        val cached = device.executeShellCommand("run-as $app cat cache/program-2026.json")
        return if (cached.trim().startsWith("{")) {
            JSONObject(JSONObject(cached).getString("content"))
        } else {
            val apk =
                device
                    .executeShellCommand("pm path $app")
                    .lineSequence()
                    .first { it.startsWith("package:") }
                    .substringAfter(":")
                    .trim()
            ZipFile(apk).use { zip ->
                JSONObject(
                    zip.getInputStream(zip.getEntry("FestivalBackup/2026_rudolstadt_data.json"))
                        .bufferedReader()
                        .use { it.readText() }
                )
            }
        }
    }

    private fun record(records: JSONArray, id: Long): JSONObject =
        (0 until records.length())
            .map { records.getJSONObject(it) }
            .single { it.getLong("id") == id }

    private fun artist(source: JSONObject, eventId: Long): String {
        val event = record(source.getJSONArray("events"), eventId)
        return Html.fromHtml(
                record(source.getJSONArray("artists"), event.getLong("artist")).getString("name"),
                Html.FROM_HTML_MODE_LEGACY,
            )
            .toString()
    }

    private fun capture(name: String) {
        directory.mkdirs()
        uiAutomator { waitForStableInActiveWindow(8_000, 750, 100, false) }
        assertTrue(device.takeScreenshot(File(directory, "$name.png")))
        device.dumpWindowHierarchy(File(directory, "$name.xml"))
        instrumentation.sendStatus(
            0,
            Bundle().apply { putString("screenshotDirectory", directory.absolutePath) },
        )
    }

    private fun withTimeline(body: () -> Unit) {
        device.findObject(By.pkg("android").text("Wait"))?.click()
        check(device.executeShellCommand("getprop ro.kernel.qemu").trim() == "1")
        device.executeShellCommand("am force-stop $app")
        val original = device.executeShellCommand("run-as $app cat $settings")
        check(original.trim().startsWith("{")) { "Initialize the emulator app first" }
        val backup = File(instrumentation.context.filesDir, "schedule-timeline-original.json")
        check(!backup.exists()) { "Restore the previous test's private backup before continuing" }
        backup.writeText(original)
        fun write(json: String) {
            val input =
                File(
                    requireNotNull(instrumentation.context.externalCacheDir),
                    "timeline-profile.json",
                )
            input.parentFile?.mkdirs()
            input.writeText(json)
            val staging = "/data/local/tmp/rudolstadt-timeline-profile.json"
            device.executeShellCommand("cp ${input.absolutePath} $staging")
            device.executeShellCommand("chmod 644 $staging")
            device.executeShellCommand("run-as $app cp $staging $settings")
            check(device.executeShellCommand("run-as $app cat $settings").trim() == json.trim())
            device.executeShellCommand("rm $staging")
            input.delete()
        }
        try {
            write(
                JSONObject(original)
                    .put("edition", "rudolstadt/2026")
                    .put("theme", "light")
                    .put("dynamicColor", false)
                    .put("scheduleLayout", "timeline")
                    .put("scheduleFilters", JSONObject())
                    .toString()
            )
            device.executeShellCommand("am start -n $app/.MainActivity")
            var ready = false
            repeat(36) {
                if (!ready) {
                    device.findObject(By.pkg("android").text("Wait"))?.click()
                    ready =
                        device.wait(
                            Until.hasObject(By.desc(if (german) "Mein Plan" else "My plan")),
                            5_000,
                        )
                }
            }
            check(ready) { "The app did not finish loading the festival programme" }
            find(By.text(if (german) "Sa. 4" else "Sat 4")).click()
            val timeline = find(By.res("schedule-timeline"))
            val vertical =
                timeline.findObjects(By.scrollable(true)).maxBy { it.visibleBounds.height() }
            vertical.scroll(Direction.UP, 1f)
            body()
        } finally {
            device.executeShellCommand("am force-stop $app")
            write(original)
            backup.delete()
        }
    }

    @Test
    fun fullApiNamesStartTimesAndAlignedColumns() = withTimeline {
        capture("standard")
        val source = source()
        val rastakTime = record(source.getJSONArray("events"), 128).getString("time")
        File(directory, "source-expectations.json")
            .writeText(
                JSONObject()
                    .put("rastakTime", rastakTime)
                    .put("event195Artist", artist(source, 195))
                    .toString(2)
            )
        val stage = find(By.res("timeline-stage-n:4"))
        val concert = find(By.res("timeline-event-127"))
        assertTrue(
            text(stage)
                .contains(if (german) "Konzertbühne Heinepark" else "Concert Stage Heinepark")
        )
        assertTrue(text(concert).contains(artist(source, 127)))
        assertTrue(
            abs(stage.visibleBounds.exactCenterX() - concert.visibleBounds.exactCenterX()) <= 2
        )
        val rastak = find(By.res("timeline-event-128"))
        assertTrue("Expected Rastak: ${text(rastak)}", text(rastak).contains("Rastak"))
        assertTrue(
            "Expected Rastak at $rastakTime: ${text(rastak)}",
            text(rastak).contains(rastakTime),
        )
        assertTrue(text(find(By.res("timeline-event-389"))).contains(artist(source, 389)))
        assertTrue(text(find(By.res("timeline-event-195"))).contains(artist(source, 195)))
        rastak.click()
        find(By.text("Rastak"))
        device.pressBack()
        find(By.res("schedule-timeline"))
        find(By.desc("Zoom")).click()
        find(By.text(if (german) "Ansicht zurücksetzen" else "Reset view")).click()
        find(By.text(if (german) "Schließen" else "Close")).click()
        find(By.res("timeline-stage-n:4"))
        capture("reset")
    }
}
