import itertools
import random
import unittest

from benchmark_schedule_planner import Event, Graph, solve
from compare_duration_weights import MODELS, UNITS_PER_POINT, event_weight, miniature_example


class DurationWeightTests(unittest.TestCase):
    def event(self, minutes):
        return Event(1, 1, "1", 0, "2026-07-03", 0, minutes)

    def test_models_agree_at_sixty_minutes(self):
        for rating in (1, 2, 3):
            for model in MODELS:
                self.assertEqual(event_weight(self.event(60), rating, model),
                                 UNITS_PER_POINT * rating ** 2)

    def test_long_favorite_beats_mini_plus_fillers_for_duration_models(self):
        for row in miniature_example():
            self.assertTrue(row["optimal"])
            self.assertEqual(row["chosen_ids"], [1, 3, 4, 5] if row["model"] == "artist-only" else [2])

    def test_linear_weight_is_additive_per_minute_and_preserves_rating_ratios(self):
        for rating in (1, 2, 3):
            self.assertEqual(event_weight(self.event(90), rating, "linear"),
                             event_weight(self.event(30), rating, "linear") +
                             event_weight(self.event(60), rating, "linear"))
        self.assertEqual(event_weight(self.event(60), 3, "linear"),
                         event_weight(self.event(540), 1, "linear"))

    def test_duration_models_increase_with_duration(self):
        for model in MODELS[1:]:
            values = [event_weight(self.event(minutes), 3, model) for minutes in (15, 30, 60, 90, 120)]
            self.assertEqual(values, sorted(set(values)))

    def test_missing_duration_and_nonpositive_rating_are_rejected(self):
        for duration, rating in ((None, 3), (0, 3), (60, 0), (60, -1)):
            with self.assertRaises(ValueError):
                event_weight(self.event(duration), rating, "linear")

    def test_duration_weights_match_exhaustive_search_on_arbitrary_conflict_graphs(self):
        rng = random.Random(20261106)
        for case in range(80):
            n = rng.randrange(1, 12)
            adjacency = [0] * n
            for i, j in itertools.combinations(range(n), 2):
                if rng.random() < .35:
                    adjacency[i] |= 1 << j
                    adjacency[j] |= 1 << i
            model = MODELS[case % len(MODELS)]
            weights = tuple(event_weight(self.event(rng.choice((15, 45, 60, 75, 90, 120))),
                                         rng.randint(1, 3), model) for _ in range(n))
            graph = Graph(tuple(adjacency), weights)
            expected = max(graph.score(mask) for mask in range(1 << n) if graph.valid(mask))
            result = solve(graph, seconds=None)
            self.assertTrue(result.optimal)
            self.assertEqual(result.score, expected)


if __name__ == "__main__":
    unittest.main()
