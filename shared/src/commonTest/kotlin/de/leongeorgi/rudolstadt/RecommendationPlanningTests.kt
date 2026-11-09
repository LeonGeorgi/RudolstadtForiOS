package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.ProgramEvent
import de.leongeorgi.rudolstadt.planning.*
import kotlin.random.Random
import kotlin.test.*

class RecommendationPlanningTests {
    private fun event(id: Long, artist: Long, minutes: Int, duration: Int, day: Int = 1) =
        ProgramEvent(
            id,
            artist,
            "stage",
            minutes * 60.0,
            dayID = "day-$day",
            dayNumber = day,
            startMinutes = minutes,
            duration = duration,
        )

    private fun plan(
        events: List<ProgramEvent>,
        ratings: Map<Long, Int>,
        saved: List<Long> = emptyList(),
    ) =
        RecommendationPlanner(
                PlanningRequest(
                    events,
                    saved,
                    ratings,
                    0.0,
                    mapOf("stage" to mapOf("stage" to Transfer(0.0, 0, "sameStage"))),
                    true,
                )
            )
            .generate()

    @Test
    fun longFavoriteBeatsMiniAppearanceAndLowRatedFillers() {
        val events =
            listOf(
                event(1, 1, 0, 15),
                event(2, 1, 0, 90),
                event(3, 3, 17, 20),
                event(4, 4, 39, 20),
                event(5, 5, 61, 20),
            )
        assertEquals(listOf(2L), plan(events, mapOf(1L to 3, 3L to 1, 4L to 1, 5L to 1)))
    }

    @Test
    fun twoDifferentFavoritesBeatOneTwiceAsLong() {
        val events = listOf(event(1, 1, 0, 180), event(2, 2, 0, 90), event(3, 3, 92, 90))
        assertEquals(listOf(2L, 3L), plan(events, mapOf(1L to 3, 2L to 3, 3L to 3)))
    }

    @Test
    fun movesAnArtistToALaterAppearanceToSeeBothArtists() {
        val events = listOf(event(1, 1, 0, 60), event(2, 1, 120, 60), event(3, 2, 0, 60))
        assertEquals(listOf(3L, 2L), plan(events, mapOf(1L to 3, 2L to 3)))
    }

    @Test
    fun conflictingAndRepeatedSavedArtistsStayFixedWithoutDuplicateRecommendations() {
        val events =
            listOf(
                event(1, 1, 0, 60),
                event(2, 2, 30, 60),
                event(3, 1, 1440, 60, 2),
                event(4, 1, 2880, 60, 3),
                event(5, 3, 100, 60),
                event(6, 4, -120, 60),
                event(7, 5, 500, 60).copy(eligible = false),
            )
        assertEquals(listOf(5L), plan(events, (1L..5L).associateWith { 3 }, listOf(1, 2, 3)))
    }

    @Test
    fun cancellationDoesNotPublishAPartialSelection() {
        val events = listOf(event(1, 1, 0, 60))
        assertTrue(
            RecommendationPlanner(PlanningRequest(events, emptyList(), mapOf(1L to 3), 0.0)) {
                    true
                }
                .generate()
                .isEmpty()
        )
        var checks = 0
        assertNull(
            independentSet(Array<Set<Int>>(160) { emptySet() }, IntArray(160) { 9 }, emptySet()) {
                ++checks > 3
            }
        )
    }

    @Test
    fun searchMatchesExhaustiveEnumerationOnSmallWeightedGraphs() {
        val random = Random(617)
        repeat(150) {
            val n = random.nextInt(1, 10)
            val adjacent = Array(n) { mutableSetOf<Int>() }
            for (a in 0 until n) for (b in 0 until a) {
                if (random.nextBoolean()) {
                    adjacent[a].add(b)
                    adjacent[b].add(a)
                }
            }
            val weights = IntArray(n) { random.nextInt(1, 1501) }
            val graph = Array<Set<Int>>(n) { adjacent[it] }
            val result = assertNotNull(independentSet(graph, weights, emptySet()) { false })
            val expected =
                (0 until (1 shl n))
                    .mapNotNull { mask ->
                        val chosen = (0 until n).filter { mask and (1 shl it) != 0 }.toSet()
                        if (chosen.any { v -> adjacent[v].any { it in chosen } }) null
                        else chosen.sumOf { weights[it].toLong() }
                    }
                    .max()
            assertEquals(expected, result.indices.sumOf { weights[it].toLong() })
            assertTrue(result.operations <= 10_000)
        }
    }

    @Test
    fun largeGraphsAreDeterministicAndRespectTheFixedBudget() {
        val random = Random(91)
        val adjacent = Array(160) { mutableSetOf<Int>() }
        for (a in adjacent.indices) for (b in 0 until a) {
            if (random.nextInt(5) == 0) {
                adjacent[a].add(b)
                adjacent[b].add(a)
            }
        }
        val graph = Array<Set<Int>>(160) { adjacent[it] }
        val weights = IntArray(160) { random.nextInt(1, 1501) }
        val result = assertNotNull(independentSet(graph, weights, emptySet()) { false })
        assertEquals(10_000, result.operations)
        assertEquals(result, independentSet(graph, weights, emptySet()) { false })
        assertTrue(result.indices.all { v -> adjacent[v].none { it in result.indices } })
    }
}
