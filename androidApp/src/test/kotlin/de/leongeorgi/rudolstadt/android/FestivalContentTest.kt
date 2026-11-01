package de.leongeorgi.rudolstadt.android

import androidx.datastore.core.CorruptionException
import androidx.datastore.core.DataStoreFactory
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.planning.ProgramRecommendations
import de.leongeorgi.rudolstadt.profile.*
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.file.Files
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import org.junit.Assert.*
import org.junit.Test

class FestivalContentTest {
    private val loader = FestivalContentLoader()

    @Test
    fun everyEditionLoadsRealResourcesAndRetainsItsIdentity() {
        Edition.all.forEach { edition ->
            val content = loader.bundled(edition)
            assertEquals(edition.year, content.program.year)
            assertTrue(
                "Missing artists for ${edition.key}",
                content.index.matching(false, emptyMap(), "", emptyMap()).isNotEmpty(),
            )
            assertTrue("Missing events for ${edition.key}", content.events.isNotEmpty())
            assertTrue("Missing days for ${edition.key}", content.days.isNotEmpty())
            assertTrue(content.days.all { it.year == edition.year })
            assertEquals(
                edition.definition.automaticPlanning,
                content.capabilities.planning != null,
            )
            assertTrue(
                content.program.events.all {
                    content.artists[it.artist.artistID] === it.artist &&
                        content.places[it.stage.placeKey] === it.stage
                }
            )
        }
    }

    @Test
    fun currentProgramUsesCuratedMetadataAndSharedDayAndDurationRules() {
        val content = loader.bundled(Edition.current)
        assertTrue(
            content.program.artists.any {
                it.content.links.any { link -> link.linkID == "appleMusic" }
            }
        )
        assertTrue(content.program.events.any { it.eventDuration?.minutes != null })
        assertTrue(content.prepared.tags.any { it.isDiscoverable })
        assertTrue(content.prepared.groupings.isNotEmpty())
        assertTrue(
            content.program.places.any {
                it.placeKey.startsWith("t:parking") && it.hasUsableLocation
            }
        )
        assertTrue(
            content.program.artists.any {
                content.details.similarArtists(it.artistID, 5).isNotEmpty()
            }
        )
        assertTrue(
            content.program.events.all { it.startTimestamp == null || it.assignedDay != null }
        )
    }

    @Test
    fun festivalPlanRemainsOfflineAndUsesSameSharedBackgroundBytes() {
        val plan = loader.bundled(Edition.all.last()).program.sitePlan!!
        val name = plan.background!!.resourceName + ".png"
        val bytes = javaClass.getResourceAsStream("/FestivalBackup/$name")!!.use { it.readBytes() }
        val digest =
            java.security.MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") {
                "%02x".format(it)
            }
        assertEquals(plan.background!!.sha256.lowercase(), digest)
        assertTrue(plan.locations.any { it.point != null })
    }

    @Test
    fun remoteDataForTheWrongYearCannotReplaceConfirmedData() {
        val payload =
            resourceText("FestivalBackup/2026_rudolstadt_data.json").replace("2026-07-", "2027-07-")
        assertThrows(IllegalArgumentException::class.java) {
            loader.remote(Edition.current, payload)
        }
    }

    @Test
    fun pastFestivalDoesNotInventFutureRecommendations() {
        val content = loader.bundled(Edition.current)
        val artist =
            content.program.artists.first { a ->
                content.program.events.any { it.artist.artistID == a.artistID }
            }
        val after = content.days.maxOf { it.end } + 86400
        val result =
            ProgramRecommendations.build(
                content.program,
                emptyList(),
                mapOf(artist.artistID.toString() to 3),
                after,
                true,
                content.capabilities.planning!!.eligibleIDs,
                content.transfer,
            ) {
                false
            }
        assertTrue(result.eventIDs.isEmpty())
    }

    @Test
    fun privateDataRoundTripsAndPreservesOtherEditions() = runBlocking {
        val one =
            ProfileReducer.apply(
                PersonalProfile(),
                ProfileMutation("setArtistNote", 123, text = "  演奏 · großartig  "),
            )
        val two = ProfileReducer.apply(PersonalProfile(), ProfileMutation("toggleSavedEvent", 456))
        val settings =
            LocalSettings(
                profiles = mapOf("rudolstadt/2026" to one, "ludwigsburg/2026" to two),
                readNews = setOf(9),
                theme = "dark",
            )
        val output = ByteArrayOutputStream()
        SettingsSerializer.writeTo(settings, output)
        assertEquals(
            settings,
            SettingsSerializer.readFrom(ByteArrayInputStream(output.toByteArray())),
        )
        assertEquals(
            "演奏 · großartig",
            settings.profile("rudolstadt/2026").artistNotes.single().noteText,
        )
        assertEquals(listOf(456L), settings.profile("ludwigsburg/2026").savedEventIDs)
        assertTrue(settings.profile("rudolstadt/2026").savedEventIDs.isEmpty())
    }

    @Test
    fun unreadablePersonalDataIsReportedWithoutReplacingTheFile() = runBlocking {
        val directory = Files.createTempDirectory("rudolstadt-corrupt-profile").toFile()
        val file = directory.resolve("profile.json").apply { writeText("{broken personal data") }
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val store = DataStoreFactory.create(SettingsSerializer, scope = scope) { file }
            repeat(2) {
                try {
                    store.data.first()
                    fail("Corrupt profile should be surfaced")
                } catch (_: CorruptionException) {}
                assertEquals("{broken personal data", file.readText())
            }
        } finally {
            scope.cancel()
            scope.coroutineContext.job.join()
            directory.deleteRecursively()
        }
    }

    @Test
    fun rapidProfileUpdatesAreTransactional() = runBlocking {
        val directory = Files.createTempDirectory("rudolstadt-profile").toFile()
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val store =
                DataStoreFactory.create(SettingsSerializer, scope = scope) {
                    directory.resolve("profile.json")
                }
            coroutineScope {
                (1L..30L)
                    .map { id ->
                        launch(Dispatchers.Default) {
                            store.updateData { settings ->
                                settings.copy(
                                    profiles =
                                        settings.profiles +
                                            (settings.edition to
                                                ProfileReducer.apply(
                                                    settings.profile(),
                                                    ProfileMutation("toggleSavedEvent", id),
                                                ))
                                )
                            }
                        }
                    }
                    .joinAll()
            }
            assertEquals((1L..30L).toList(), store.data.first().profile().savedEventIDs)
        } finally {
            scope.cancel()
            scope.coroutineContext.job.join()
            directory.deleteRecursively()
        }
    }
}
