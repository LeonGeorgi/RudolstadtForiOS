package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.news.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.*
import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*

class ApplicationDomainTests {
    @Test
    fun newsWirePreservesOldCacheKeysAndTheSourceClock() {
        val source =
            """[{"id":4294967297,"title":"A &amp; B","language":"de","teaser":"&lt;x&gt;","text":"&#34;Hi&#34;","time":{"date":"2026-07-03 23:15:00.123456","timezone_type":3,"timezone":"Europe/Berlin"}}]"""
        val record = NewsWire.decode(source).single()
        val message = record.message()
        assertEquals(4294967297L, message.newsID)
        assertEquals(
            "A &amp; B",
            message.shortDescription,
        ) // Named entities retain the old HTML-rendering contract.
        assertEquals("03.07.2026", message.dateAsString)
        assertEquals("23:15", message.timeAsString)
        assertEquals("\"Hi\"", message.content)
        assertEquals(listOf(record), NewsWire.decode(NewsWire.encode(listOf(record))))
        assertTrue("timezone_type" in NewsWire.encode(listOf(record)))
        assertFails { NewsWire.decode("{}") }
        assertNull(NewsTime("bad", 3, "Europe/Berlin").timestamp)
    }

    @Test
    fun canonicalNewsRetainsTextIDsLinksAndLanguageFallback() {
        val article =
            NewsArticle(
                "opening",
                mapOf("fr" to "Bonjour"),
                mapOf("en" to "Summary"),
                ProgramContent(mapOf("en" to "Body")),
                null,
                image = "https://example.com/image",
                articleLinks =
                    listOf(ProgramLink("source", mapOf("en" to "Source"), "https://example.com")),
                destinations = listOf(ContentDestination("artist", "4294967297")),
            )
        val snapshot = NewsSnapshot("test", "2027", listOf(article), snapshotSource = "cache")
        val model = NewsViewModel("test", "2027")
        model.applySnapshot(snapshot)
        assertSame(snapshot, model.current.snapshot)
        assertSame(article, model.current.snapshot!!.articles.single())
        assertTrue(model.current.items.isEmpty()) // text IDs stay in the canonical article list
        val translated = snapshot.copy(articles = listOf(article.copy(articleID = "12")))
        assertEquals("Summary", NewsSnapshots.messages(translated).single().longDescription)
        assertEquals("Body", NewsSnapshots.messages(translated).single().content)
    }

    @Test
    fun profileImportRetainsVersionedDeletionsAndFullUploadIntent() {
        val profile =
            PersonalProfile(
                savedEventIDs = listOf(8),
                artistPreferences = listOf(ArtistPreference(9, 3)),
            )
        val deletedVersion = ProfileVersion(100.25, "delete")
        val changes =
            ProfileRecords.changes(
                profile,
                listOf(ProfileRecordVersion("note:42", deletedVersion)),
                -100.0,
            ) {
                "hash:$it"
            }
        assertEquals(listOf("event:8", "note:42", "rating:9"), changes.map { it.key })
        assertTrue(changes.single { it.key == "note:42" }.value.isDeleted)
        assertEquals(deletedVersion, changes.single { it.key == "note:42" }.version)
        assertEquals("legacy:hash:event:true", changes.first().version.changeID)
        val model = ProfileViewModel(true, true, true, false)
        model.restore(profile, changes, emptySet())
        val plan = model.beginFullUpload()
        assertEquals(setOf("profile", "event:8", "note:42", "rating:9"), model.current.pending)
        assertEquals(model.current.pending, plan.map { it.key }.toSet())
        val friend =
            SharedProfile(
                "friend",
                "Friend",
                null,
                null,
                null,
                2026,
                listOf(8),
                listOf(ArtistPreference(9, 3)),
            )
        assertTrue(ProfileRecords.removeShared(friend, "event:8").saved.isEmpty())
        assertEquals(
            friend,
            ProfileRecords.applyShared(
                friend,
                ProfileRecordValue("note", 42, noteText = "Private"),
            ),
        )
    }

    @Test
    fun schedulePresentationOwnsLoadingFailuresAndSavedEventFiltering() {
        val occurrence = event(1, 0)
        val profile = ProfileState(PersonalProfile(savedEventIDs = listOf(1)))
        val loading = RecommendationState()
        assertEquals(
            LoadPhase.LOADING,
            SchedulePresentation.shown(listOf(occurrence), "optimal", profile, loading).phase,
        )
        val failed =
            SchedulePresentation.shown(
                listOf(occurrence),
                "optimal",
                profile,
                RecommendationState(LoadPhase.FAILED),
            )
        assertEquals(LoadPhase.FAILED, failed.phase)
        assertEquals("couldNotLoadFromFile", failed.failure)
        val shown = SchedulePresentation.shown(listOf(occurrence), "interesting", profile, loading)
        assertEquals(LoadPhase.READY, shown.phase)
        assertSame(occurrence, shown.events.single())
    }

    @Test
    fun schedulePreferencesKeepFestivalScopesAndLegacyFallbacksSeparate() {
        val model = SchedulePreferencesViewModel()
        model.restore("2026", 3)
        val initial = model.current
        assertEquals(1, model.select("2025", "interesting"))
        assertEquals(3, model.storedCode("2026"))
        assertEquals(1, model.storedCode("2025"))
        assertFalse("2025" in initial.codes)
        model.restore("2027", 99)
        assertEquals("all", model.name(model.storedCode("2027")))
        assertEquals(99, model.storedCode("2027"))
    }

    private val place =
        ProgramPlace("n:1", mapOf("de" to "Bühne"), latitude = 50.7, longitude = 11.3, typeCode = 1)

    private fun event(id: Long, minutes: Int, artist: Long = id): ProgramOccurrence =
        ProgramOccurrence(
            id,
            1783094400.0 + minutes * 60,
            1783036800.0,
            place,
            ProgramArtist(
                artist,
                "Artist $artist",
                false,
                ProgramArtistDetails(ProgramContent(emptyMap())),
            ),
            emptyList(),
            EventDuration(60, false),
        )

    @Test
    fun recommendationsUseSharedTransferSourcesAndKeepSavedEventsOutOfSuggestions() {
        val first = event(4294967297, 0)
        val second = event(4294967298, 120)
        val program =
            FestivalProgram(
                listOf(first.artist, second.artist),
                emptyList(),
                listOf(place),
                listOf(first, second),
                0,
                2026,
            )
        val transfers =
            TransferEstimator(
                listOf(PlaceLocation(place.placeKey, place.latitude, place.longitude)),
                WalkingDistanceMatrix(emptyMap()),
            )
        val result =
            ProgramRecommendations.build(
                program,
                listOf(first.eventID),
                mapOf(second.artist.artistID.toString() to 3),
                0.0,
                false,
                null,
                transfers,
            ) {
                false
            }
        assertEquals(listOf(second.eventID), result.eventIDs)
        val model = RecommendationViewModel()
        val token = model.beginCalculation(true, "available")!!
        model.inputsChanged()
        model.complete(token, result, 0.0)
        assertEquals(LoadPhase.LOADING, model.current.phase)
        assertNull(model.beginCalculation(true, "unsupported"))
        assertEquals(LoadPhase.READY, model.current.phase)
        assertTrue(model.current.eventIDs.isEmpty())
    }

    @Test
    fun planFactsIncludeNonAdjacentOverlapsAndChooseDeterministicTransitions() {
        val events = listOf(event(1, 0), event(2, 30), event(3, 90), event(4, 240))
        val transfers = TransferSource { _, _ -> Transfer(0.0, 0, "sameStage") }
        val durations =
            listOf(
                EventMinutes(1, 180),
                EventMinutes(2, 30),
                EventMinutes(3, 30),
                EventMinutes(4, 60),
            )
        val facts = PlanFactsCalculator.calculate(events, durations, 60, transfers)
        assertEquals(
            listOf(1L to 2L, 1L to 3L),
            facts.overlaps.map { it.firstEventID to it.secondEventID },
        )
        assertEquals(1, facts.transitions.size)
        assertEquals(1L, facts.transitions.single().firstEventID)
        assertEquals(4L, facts.transitions.single().secondEventID)
        assertEquals(
            facts,
            PlanFactsCalculator.calculate(events.reversed(), durations, 60, transfers),
        )
    }

    @Test
    fun catalogCapabilitiesRetainSupplementaryLinksAndDisabledFeatures() {
        val occurrence = event(1, 0)
        val program =
            FestivalProgram(
                listOf(occurrence.artist),
                emptyList(),
                listOf(place),
                listOf(occurrence),
                0,
                2026,
            )
        val link = ProgramLink("parking", mapOf("en" to "Parking"), "https://example.com")
        val extra =
            ProgramSupplementaryPlace(
                place,
                ProgramContent(mapOf("en" to "Note")),
                null,
                null,
                listOf(link),
            )
        val prepared =
            PreparedProgram(
                program,
                emptyList(),
                emptyList(),
                emptyList(),
                emptyList(),
                emptyMap(),
                emptyList(),
                emptyList(),
            )
        val catalog =
            ProgramCatalogs.build(
                prepared,
                WalkingDistanceMatrix(emptyMap()),
                listOf(extra),
                null,
                false,
                false,
                false,
            )
        val parking = RudolstadtContent.parking { key, language -> "$key/$language" }
        assertEquals(
            listOf("t:parking-raiffeisen", "t:parking-correns"),
            parking.map { it.place.placeKey },
        )
        assertEquals(50.723778, parking.first().coordinate!!.latitude)
        assertEquals("parking", parking.first().category!!.categoryID)
        val information = RudolstadtContent.information { key, language -> "$key/$language" }
        assertEquals(listOf("park-and-ride", "bus"), information.map { it.pageID })
        assertEquals("car", information.first().iconKind)
        assertEquals(
            "https://auskunft.kombus-online.eu/widget/tff/?tpl=165D206D86C",
            information.last().webURL,
        )
        val tags = RudolstadtContent.eventTags()
        assertEquals(setOf("Bühne", "Straßenmusik"), tags.hiddenTimelineNames)
        assertTrue(tags.titleOverrides.isEmpty())
        assertNull(catalog.planning)
        assertNull(catalog.areas)
        assertNull(catalog.admission)
        assertEquals(listOf(link), catalog.places.details(place.placeKey)!!.programLinks)
        assertEquals(
            EditionKind.ARCHIVE,
            FestivalDefinitions.rudolstadt(2025, true).metadata.editionKind,
        )
        assertEquals(
            UserDataAccess.READ_ONLY,
            FestivalDefinitions.rudolstadt(2025, true).metadata.userDataPolicy.savedEvents,
        )
    }
}
