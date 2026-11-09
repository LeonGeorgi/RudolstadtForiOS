import itertools
import random
import unittest

from benchmark_schedule_planner import (
    Dataset, Event, Graph, Transfer, Walking, bits, conflict_graph, current_greedy,
    load_dataset, prepare_request, resolve_durations, solve, transition_conflict,
)


def graph(weights, edges):
    adjacent = [0] * len(weights)
    for a, b in edges:
        adjacent[a] |= 1 << b
        adjacent[b] |= 1 << a
    return Graph(tuple(adjacent), tuple(weights))


def exhaustive(g):
    # Enumerate every subset without using the search algorithm or its bounds.
    return max((g.score(mask) for mask in range(g.mask + 1) if g.valid(mask)), default=0)


class BranchAndBoundTests(unittest.TestCase):
    def test_matches_all_subsets_on_150_seeded_weighted_graphs(self):
        rng = random.Random(20261105)
        for case in range(150):
            n = rng.randrange(14)
            density = rng.choice((0, .1, .3, .6, 1))
            g = graph([rng.choice((1, 4, 9)) for _ in range(n)],
                      [(a, b) for a, b in itertools.combinations(range(n), 2)
                       if rng.random() < density])
            result = solve(g, seconds=None)
            with self.subTest(case=case):
                self.assertTrue(g.valid(result.chosen))
                self.assertEqual(result.score, exhaustive(g))
                self.assertTrue(result.optimal)
                self.assertEqual(result.upper_bound, result.score)

    def test_timeout_retains_seed_and_an_admissible_upper_bound(self):
        g = graph([9, 9, 9], [(0, 1), (0, 2)])
        result = solve(g, initial=1, seconds=0)
        self.assertEqual(result.score, 9)
        self.assertGreaterEqual(result.upper_bound, exhaustive(g))
        self.assertFalse(result.optimal)

    def test_partial_search_bounds_surround_the_exhaustive_optimum(self):
        rng = random.Random(42)
        for _ in range(30):
            g = graph([rng.choice((1, 4, 9)) for _ in range(13)],
                      [(a, b) for a, b in itertools.combinations(range(13), 2)
                       if rng.random() < .3])
            result = solve(g, seconds=.00003)
            optimum = exhaustive(g)
            self.assertLessEqual(result.score, optimum)
            self.assertGreaterEqual(result.upper_bound, optimum)

    def test_one_long_concert_can_be_replaced_with_two_short_concerts(self):
        g = graph([9, 9, 9], [(0, 1), (0, 2)])
        result = solve(g, initial=1, seconds=None)
        self.assertEqual(result.chosen, 0b110)
        self.assertEqual(result.score, 18)

    def test_artist_can_move_to_another_day_to_free_a_conflicting_slot(self):
        events = [Event(1, 1, "1", 100_000, "2026-07-03", 1080, 60),
                  Event(2, 1, "1", 186_400, "2026-07-04", 1080, 60),
                  Event(3, 2, "1", 100_000, "2026-07-03", 1080, 60)]
        transfers = {("1", "1"): Transfer(0, 0, "sameStage")}
        g = Graph(conflict_graph(events, transfers), (9, 9, 9))
        initial = current_greedy(events, g, {1: 3, 2: 3})
        self.assertEqual(initial, 1)
        result = solve(g, initial, seconds=None)
        self.assertEqual({events[i].id for i in bits(result.chosen)}, {2, 3})

    def test_invalid_seed_is_rejected(self):
        with self.assertRaises(ValueError):
            solve(graph([9, 9], [(0, 1)]), initial=3)

    def test_operation_checkpoints_match_independent_runs(self):
        rng = random.Random(99)
        budgets = (0, 1, 5, 20, 100, 300, 1000)
        for _ in range(12):
            g = graph([rng.choice((71, 480, 1323)) for _ in range(13)],
                      [(a, b) for a, b in itertools.combinations(range(13), 2)
                       if rng.random() < .3])
            trace = solve(g, seconds=None, operation_limit=budgets[-1], checkpoints=budgets)
            scores = [c.score for c in trace.checkpoints]
            self.assertEqual(scores, sorted(scores))
            optimum = exhaustive(g)
            for checkpoint in trace.checkpoints:
                separate = solve(g, seconds=None, operation_limit=checkpoint.budget)
                self.assertEqual(checkpoint.score, separate.score)
                self.assertEqual(checkpoint.chosen, separate.chosen)
                self.assertLessEqual(checkpoint.operations, checkpoint.budget)
                self.assertLessEqual(checkpoint.score, optimum)
                self.assertGreaterEqual(checkpoint.upper_bound, optimum)

    def test_completed_search_stays_flat_for_larger_operation_budgets(self):
        g = graph([9, 9, 9], [(0, 1), (0, 2)])
        trace = solve(g, initial=1, seconds=None, operation_limit=10000,
                      checkpoints=(0, 100, 1000, 10000))
        self.assertEqual(trace.checkpoints[0].score, 9)
        for checkpoint in trace.checkpoints[1:]:
            self.assertTrue(checkpoint.optimal)
            self.assertEqual(checkpoint.score, 18)
            self.assertEqual(checkpoint.phase, "complete")

    def test_improved_strategies_match_exhaustive_optima_and_budget_prefixes(self):
        rng = random.Random(617)
        budgets = (0, 10, 100, 1000, 10000)
        for case in range(80):
            n = rng.randrange(1, 13)
            g = graph([rng.randint(1, 1500) for _ in range(n)],
                      [(a, b) for a, b in itertools.combinations(range(n), 2)
                       if rng.random() < rng.choice((.1, .4, .8))])
            optimum = exhaustive(g)
            for strategy in ("active-cover", "improved", "repair"):
                exact = solve(g, seconds=None, strategy=strategy)
                self.assertTrue(exact.optimal)
                self.assertEqual(exact.score, optimum)
                trace = solve(g, seconds=None, strategy=strategy,
                              operation_limit=budgets[-1], checkpoints=budgets)
                scores = [c.score for c in trace.checkpoints]
                self.assertEqual(scores, sorted(scores))
                for point in trace.checkpoints:
                    self.assertTrue(g.valid(point.chosen))
                    self.assertLessEqual(point.score, optimum)
                    self.assertGreaterEqual(point.upper_bound, optimum)
                    separate = solve(g, seconds=None, strategy=strategy,
                                     operation_limit=point.budget)
                    self.assertEqual((point.score, point.chosen), (separate.score, separate.chosen))


class PlanningModelTests(unittest.TestCase):
    def event(self, id, start, duration=None, artist=None, place="1", day="2026-07-03"):
        return Event(id, artist or id, place, start * 60, day, start, duration)

    def test_duration_estimates_match_documented_kotlin_boundaries(self):
        for gap, expected in [(20, 20), (45, 45), (60, 60), (120, 60), (180, 90), (360, 60)]:
            events = resolve_durations([self.event(1, 600), self.event(2, 600 + gap)])
            self.assertEqual(events[0].duration, expected)
            self.assertEqual(events[1].duration, 60)
        self.assertEqual(resolve_durations([self.event(1, 600, 75)])[0].duration, 75)

    def test_arrival_buffer_estimates_unknown_transfers_and_day_boundaries(self):
        a = self.event(1, 600, 60)
        b = self.event(2, 662, 60)
        self.assertFalse(transition_conflict(a, b, {("1", "1"): Transfer(0, 0, "sameStage")}))
        self.assertTrue(transition_conflict(a, self.event(2, 661, 60), {("1", "1"): Transfer(0, 0, "sameStage")}))
        estimate = {("1", "1"): Transfer(160, 2, "directCoordinateEstimate")}
        self.assertTrue(transition_conflict(a, b, estimate))
        self.assertFalse(transition_conflict(a, b, estimate, requires_known=False))
        self.assertTrue(transition_conflict(a, b, {}))
        self.assertFalse(transition_conflict(a, b, {}, requires_known=False))
        self.assertFalse(transition_conflict(a, self.event(2, 600, 60, day="2026-07-04"), {}))

    def test_saved_concerts_exclude_their_artist_and_conflicts_and_past_events(self):
        events = [self.event(1, 600, 60), self.event(2, 800, 60, artist=1),
                  self.event(3, 630, 60), self.event(4, 800, 60), self.event(5, 400, 60)]
        transfers = {("1", "1"): Transfer(0, 0, "sameStage")}
        data = Dataset("test", events, events, {}, {}, {}, transfers, None)
        candidates, g = prepare_request(data, {a: 3 for a in range(1, 6)}, [1], 500 * 60,
                                        conflict_graph(events, transfers))
        self.assertEqual([e.id for e in candidates], [4])
        self.assertEqual(solve(g, seconds=None).score, 9)

    def test_walking_prefers_valid_known_routes_and_estimates_other_pairs(self):
        locations = {"1": (50.718, 11.332), "2": (50.7198, 11.3345), "3": (50.7216, 11.337)}
        walking = Walking(locations, {"1": {"2": 320}})
        self.assertEqual(walking.estimate("1", "1"), Transfer(0, 0, "sameStage"))
        self.assertEqual(walking.estimate("1", "2"), Transfer(320, 4, "knownRoute"))
        self.assertEqual(walking.estimate("1", "3").source, "anchoredEstimate")
        self.assertIsNone(walking.estimate("1", "unknown"))

    def test_bundled_programs_load_with_unique_events_and_positive_durations(self):
        for name, count in [("rudolstadt-2026", 310), ("fantasy-2027", 500)]:
            data = load_dataset(name)
            self.assertEqual(len(data.events), count)
            self.assertEqual(len({e.id for e in data.events}), count)
            self.assertTrue(all(e.duration > 0 for e in data.events))


if __name__ == "__main__":
    unittest.main()
