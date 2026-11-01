package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.*
import kotlin.test.*

class ScreenProjectionTests {
    private fun url(
        path: List<String>,
        query: List<MediaParameter> = emptyList(),
        host: String = "music.apple.com",
        scheme: String = "https",
    ) = MediaURLParts(scheme, host, path, query)

    @Test
    fun mediaReferencesRetain64BitIDsAndAlbumTrackOverrides() {
        val reference =
            assertNotNull(
                MediaLinks.music(
                    url(
                        listOf("de", "album", "Name", "4294967297"),
                        listOf(MediaParameter("i", "4294967298")),
                    )
                )
            )
        assertEquals(MusicKind.SONG, reference.kind)
        assertEquals(4294967298L, reference.catalogID)
        assertEquals("DE", reference.lookupParameters.last().value)
        assertNull(MediaLinks.music(url(listOf("de", "artist", "1"), host = "example.com")))
        assertNull(MediaLinks.music(url(listOf("de", "artist", "1"), scheme = "http")))
        assertNull(MediaLinks.music(url(listOf("de", "song", "-1"))))
        assertEquals(
            "50",
            MusicReference(MusicKind.ARTIST, 1, "de")
                .lookupParameters
                .single { it.name == "limit" }
                .value,
        )
    }

    @Test
    fun musicLookupKeepsTheFirstExactMatchAndRejectsMalformedResponses() {
        val source =
            """{"results":[{"kind":"song","artistId":8,"trackName":"Wrong","artistName":"Other","previewUrl":"https://wrong"},{"kind":"song","artistId":4294967297,"trackName":"Right","artistName":"Artist","previewUrl":"https://right"}]}"""
        val reference = MusicReference(MusicKind.ARTIST, 4294967297, "de")
        assertEquals("Right", MusicPreviews.select(source, reference) { true }?.trackName)
        assertNull(MusicPreviews.select(source, reference.copy(catalogID = 9)) { true })
        assertFails { MusicPreviews.select("{}", reference) { true } }
        assertFails { MusicPreviews.select(source, reference) { false } }
    }

    @Test
    fun curatedPreviewChoiceRetainsDisabledAndSongOnlyOverrides() {
        val artist = url(listOf("de", "artist", "1"))
        val song = url(listOf("de", "song", "2"))
        val links =
            CuratedArtistLinks(appleMusicURL = "artist", preview = "songURL", previewURL = "song")
        val parse: (String) -> MediaURLParts? = { if (it == "song") song else artist }
        assertEquals(2L, MediaLinks.previewReference(links, parse)?.catalogID)
        assertNull(MediaLinks.previewReference(links.copy(preview = "disabled"), parse))
        assertNull(MediaLinks.previewReference(links.copy(previewURL = "artist"), parse))
        assertEquals(
            1L,
            MediaLinks.previewReference(links.copy(previewURL = null), parse)?.catalogID,
        )
    }

    @Test
    fun youtubeRecognizesShortEmbedLiveAndQueryForms() {
        for (parts in
            listOf(
                url(listOf("abc_9-z"), host = "youtu.be"),
                url(listOf("watch"), listOf(MediaParameter("v", "abc_9-z")), "www.youtube.com"),
                url(listOf("embed", "abc_9-z"), host = "youtube-nocookie.com"),
                url(listOf("live", "abc_9-z"), host = "youtube.com"),
            )) {
            assertEquals("abc_9-z", MediaLinks.youtube(parts))
        }
        assertNull(MediaLinks.youtube(url(listOf("watch"), host = "example.com")))
    }

    private fun time(value: String): Double =
        FestivalTime.parse(value, "yyyy-MM-dd'T'HH:mm", "Europe/Berlin")!!

    private val place =
        ProgramPlace("n:1", mapOf("en" to "Stage"), latitude = 50.7, longitude = 11.3)

    private fun event(
        id: Long,
        start: String?,
        duration: Int? = 60,
        stage: ProgramPlace = place,
        artist: Long = id,
    ) =
        ProgramOccurrence(
            id,
            start?.let(::time),
            time("2026-07-04T00:00"),
            stage,
            ProgramArtist(
                artist,
                "Artist",
                false,
                ProgramArtistDetails(ProgramContent(emptyMap())),
            ),
            emptyList(),
            duration?.let { EventDuration(it, false) },
        )

    @Test
    fun timelineAlignsColumnsAndKeepsLongestDuplicateSlotWithoutDrift() {
        val first = event(1, "2026-07-04T12:00", 30)
        val longest = event(2, "2026-07-04T12:00", 90)
        val overlap = event(3, "2026-07-04T12:30", 30)
        val last = event(4, "2026-07-04T14:00", 60)
        val other = event(5, "2026-07-04T13:00", 60, place.copy(placeKey = "n:2"))
        val result =
            ProgramTimeline.build(
                listOf(first, longest, overlap, last, other),
                listOf(EventMinutes(1, 30), EventMinutes(2, 90), EventMinutes(3, 30)),
                "Europe/Berlin",
                true,
                true,
            ) { a, b ->
                a.placeKey < b.placeKey
            }
        assertEquals(listOf(2L, 4L), result.columns.first().items.mapNotNull { it.event?.eventID })
        assertSame(longest, result.columns.first().items.first().event)
        assertEquals(1800.0, result.columns.first().items.single { it.event == null }.gapSeconds)
        assertEquals(3600.0, result.columns.last().items.first().gapSeconds)
        assertEquals(time("2026-07-04T15:00"), result.ticks.last())
        assertTrue(
            ProgramTimeline.build(emptyList(), emptyList(), "Europe/Berlin", true, true) { _, _ ->
                    false
                }
                .ticks
                .isEmpty()
        )
    }

    @Test
    fun festivalTimelineKeepsLogicalDaysAndOmitsOvernightGaps() {
        fun day(id: String, number: Int) =
            OccurrenceDay(
                ProgramDay(id, 2026, 7, number, time("${id}T04:00"), time("${id}T04:00") + 86_400),
                mapOf("en" to id),
            )
        val saturday = day("2026-07-04", 4)
        val sunday = day("2026-07-05", 5)
        val monday = day("2026-07-06", 6)
        val late = event(4294967297, "2026-07-05T01:00").copy(assignedDay = saturday)
        val noon = event(2, "2026-07-05T12:00").copy(assignedDay = sunday)
        val unknown = event(3, null).copy(assignedDay = saturday)
        val result =
            ProgramTimeline.buildDays(
                listOf(noon, unknown, late),
                listOf(saturday, sunday, monday),
                listOf(EventMinutes(late.eventID, 90), EventMinutes(noon.eventID, 45)),
                "Europe/Berlin",
            ) { a, b ->
                a.placeKey < b.placeKey
            }
        assertEquals(listOf(saturday, sunday, monday), result.map { it.day })
        assertSame(late, result[0].timeline.columns.single().items.single().event)
        assertSame(noon, result[1].timeline.columns.single().items.single().event)
        assertEquals(time("2026-07-05T02:30"), result[0].timeline.ticks.last())
        assertEquals(time("2026-07-05T12:00"), result[1].timeline.ticks.first())
        assertTrue(result.take(2).all { it.timeline.ticks.size < 8 })
        assertTrue(result.last().timeline.ticks.isEmpty())
        assertTrue(result.last().timeline.columns.isEmpty())
        assertEquals(listOf(unknown), ProgramSchedule.unplaced(listOf(noon, unknown, late)))
    }

    @Test
    fun timelineRoundingUsesTheFestivalZoneAndCrossesSummerTime() {
        val start = time("2026-03-29T01:45")
        val end = time("2026-03-29T03:30")
        assertEquals(
            listOf(time("2026-03-29T01:30"), time("2026-03-29T03:00"), end),
            ProgramTimeline.halfHours(start, end, "Europe/Berlin"),
        )
    }

    private val noWalking = TransferSource { _, _ -> Transfer(0.0, 0, "sameStage") }

    private fun details(
        events: List<ProgramOccurrence>,
        places: List<ProgramPlace> = listOf(place),
        transfer: TransferSource = noWalking,
        similarities: ProgramSimilarityCatalog? = null,
    ) = ProgramDetailCatalog(events.map { it.artist }, places, events, transfer, similarities)

    @Test
    fun detailCatalogRetainsProgramOrderAndReactsToChangedSavedEvents() {
        val concert = event(4294967297, "2026-07-04T12:00")
        val first = event(2, "2026-07-04T12:30")
        val second = event(3, "2026-07-04T12:45")
        val sameArtist = event(4, "2026-07-04T12:30", artist = concert.artist.artistID)
        val unknown = event(5, "2026-07-04T12:30", duration = null)
        val events = listOf(concert, first, second, sameArtist, unknown)
        val catalog = details(events)
        assertEquals(listOf(concert, sameArtist), catalog.artistEvents(concert.artist.artistID))
        assertTrue(catalog.artistEvents(-1).isEmpty())
        assertTrue(
            catalog.conflicts(concert.artist.artistID, emptySet()).all { it.events.isEmpty() }
        )
        val saved = linkedSetOf(3L, 5L, 2L, 4L, -1L)
        assertEquals(
            ProgramDetails.conflicts(listOf(concert, sameArtist), events, saved, noWalking),
            catalog.conflicts(concert.artist.artistID, saved),
        )
        assertEquals(
            listOf(first),
            catalog.conflicts(concert.artist.artistID, setOf(2)).first().events,
        )
        assertTrue(
            catalog.conflicts(concert.artist.artistID, emptySet()).all { it.events.isEmpty() }
        )
    }

    @Test
    fun detailCatalogPreservesOvernightDaysAndDoesNotReuseAnotherProgramsGroups() {
        val overnight = event(1, "2026-07-04T02:00")
        val other = event(2, "2026-07-05T12:00", stage = place.copy(placeKey = "n:2"))
        val catalog = details(listOf(overnight, other))
        assertEquals(
            ProgramDetails.placeDays(listOf(overnight), place.placeKey),
            catalog.placeDays(place.placeKey),
        )
        assertEquals(
            "2026-07-03",
            catalog.initialPlaceDay(place.placeKey, null, emptyList(), clock),
        )
        assertTrue(catalog.placeDays("missing").isEmpty())
        val replacement = details(listOf(other))
        assertTrue(replacement.placeDays(place.placeKey).isEmpty())
        assertEquals(listOf(other), replacement.artistEvents(other.artist.artistID))
    }

    @Test
    fun detailCatalogBuildsNearbyPlacesOnlyWhenRequestedAndReusesThem() {
        var requests = 0
        val places = (1..3).map { place.copy(placeKey = "n:$it") }
        val catalog =
            details(
                emptyList(),
                places,
                TransferSource { _, _ ->
                    requests++
                    Transfer(80.0, 5, "knownRoute")
                },
            )
        assertEquals(0, requests)
        assertEquals(2, catalog.nearby("n:1").size)
        assertEquals(2, requests)
        assertEquals(2, catalog.nearby("n:1").size)
        assertEquals(2, requests)
        assertTrue(catalog.nearby("missing").isEmpty())
    }

    @Test
    fun detailCatalogResolvesRankedSimilaritiesToTheOriginalVisibleModels() {
        val events = (1L..4L).map { event(it, "2026-07-04T12:00") }.toMutableList()
        events[1] = events[1].copy(artist = events[1].artist.copy(hiddenFromArtistList = true))
        val catalog =
            details(
                events,
                similarities =
                    ProgramSimilarityCatalog(listOf(SimilarArtistIDs(1, listOf(1, 99, 2, 4, 3)))),
            )
        assertEquals(listOf(4L, 3L), catalog.similarArtists(1, 5).map { it.artistID })
        assertSame(events[3].artist, catalog.similarArtists(1, 1).single())
        assertTrue(catalog.similarArtists(1, 0).isEmpty())
        assertTrue(catalog.similarArtists(1, -1).isEmpty())
        assertTrue(catalog.similarArtists(99, 5).isEmpty())
    }

    @Test
    fun artistConflictsExcludeTheSameArtistAndMissingDurations() {
        val concert = event(4294967297, "2026-07-04T12:00")
        val collision = event(2, "2026-07-04T12:30")
        val sameArtist = event(3, "2026-07-04T12:30", artist = concert.artist.artistID)
        val unknown = event(4, "2026-07-04T12:30", duration = null)
        val result =
            ProgramDetails.conflicts(
                listOf(concert),
                listOf(concert, collision, sameArtist, unknown),
                setOf(2, 3, 4),
                noWalking,
            )
        assertSame(collision, result.single().events.single())
    }

    @Test
    fun nearbyPlacesAreSortedFilteredAndLimitedInSharedCode() {
        val places = (1..4).map { place.copy(placeKey = "n:$it") }
        val result =
            ProgramDetails.nearby(
                places,
                "n:1",
                TransferSource { _, to ->
                    if (to == "n:2") null
                    else Transfer(if (to == "n:3") 80.0 else 40.0, 5, "knownRoute")
                },
                10,
                1,
            )
        assertEquals("n:4", result.single().place.placeKey)
    }

    @Test
    fun placeDaysKeepTheFiveAmBoundaryAndHighlightedSelection() {
        val overnight = event(1, "2026-07-04T02:00")
        val result = ProgramDetails.placeDays(listOf(overnight), place.placeKey)
        assertEquals("2026-07-03", result.single().dayID)
        assertEquals(
            "2026-07-03",
            ProgramDetails.initialPlaceDay(
                listOf(overnight),
                place.placeKey,
                null,
                emptyList(),
                time("2026-07-04T03:00"),
            ),
        )
    }

    private val clock = time("2026-07-04T02:00")
    private val freshness = PlanFreshness(clock, "cache", clock, true, clock, true, clock)
    private val policy = PlanFreshnessPolicy()

    private fun plan(events: List<PlanEvent>) =
        PersonalPlanSnapshot(2026, events, 0, false, false, freshness, emptyList(), emptyList())

    @Test
    fun dayPlanRetainsSimultaneousEventsConflictsAndEndedTransitionSources() {
        val events =
            listOf(
                PlanEvent(1, clock - 3600, clock - 1, 3, true, 3),
                PlanEvent(2, clock - 1800, clock + 3600, 3, true, 2),
                PlanEvent(3, clock + 30, clock + 7200, 3, true, 1),
            )
        val input =
            plan(events)
                .copy(
                    transitions =
                        listOf(PlanTransition(1, 3, "tight"), PlanTransition(2, 3, "unknown")),
                    conflicts = listOf(PlanConflict(2, 3, 10)),
                )
        val result = PersonalPlan.day(input, clock, "Europe/Berlin", policy)
        assertEquals("plan", result.kind)
        assertEquals(3, result.day)
        assertEquals(listOf(2L, 3L), result.rows.map { it.eventID })
        assertEquals(10, result.rows.last().conflictMinutes)
        assertEquals(0, result.rows.last().incomingTransitionIndex)
        assertEquals(1, result.rows.last().friendSaveCount)
        assertNull(
            PersonalPlan.day(input, clock + 86401, "Europe/Berlin", policy)
                .rows
                .firstOrNull()
                ?.friendSaveCount
        )
    }

    @Test
    fun nextEventKeepsLatestStartedEventSemanticsAndIncompletePlanStates() {
        val events =
            listOf(
                PlanEvent(1, clock - 100, clock + 1000, 3, true, null),
                PlanEvent(2, clock - 50, clock - 1, 3, true, null),
                PlanEvent(3, clock + 50, clock + 500, 3, true, null),
            )
        val input = plan(events)
        assertEquals(3L, PersonalPlan.next(input, clock, policy).eventID)
        assertEquals(
            "planUnavailable",
            PersonalPlan.next(input.copy(hasUnplacedSavedEvents = true), clock, policy).kind,
        )
        assertEquals(
            "noSavedEvents",
            PersonalPlan.next(
                    input.copy(events = events.map { it.copy(saved = false) }),
                    clock,
                    policy,
                )
                .kind,
        )
    }

    @Test
    fun freshnessKeepsStrictAgeBoundariesAndSeparatesScheduleFromFriendState() {
        assertFalse("festivalDataTooOld" in policy.staleReasons(freshness, clock + 10800, true))
        assertTrue("festivalDataTooOld" in policy.staleReasons(freshness, clock + 10801, true))
        val unknown = freshness.copy(recommendationsAt = null, friendsAt = null)
        assertEquals(
            listOf("recommendationsAgeUnknown", "friendDataAgeUnknown"),
            policy.staleReasons(unknown, clock, false),
        )
        assertTrue(policy.staleReasons(unknown, clock, true).isEmpty())
        assertEquals(
            listOf("timestampInFuture"),
            policy.staleReasons(freshness, clock - 301, false),
        )
    }

    @Test
    fun timelineSchedulesStateChangesAndCapsEntriesWithReload() {
        val events =
            (1..8).map {
                PlanEvent(it.toLong(), clock + it * 100, clock + it * 100 + 50, 3, true, null)
            }
        val result = PersonalPlan.timeline(plan(events), clock, policy, 3)
        assertEquals(3, result.entries.size)
        assertTrue(result.reloadAtEnd)
        assertEquals("upcoming", if (result.entries.first().ongoing) "ongoing" else "upcoming")
        assertEquals(events.first().start, result.entries[1].timestamp)
        assertTrue(result.entries[1].ongoing)
    }
}
