import unittest

from benchmark_schedule_planner import Graph, load_dataset, transition_conflict
from simulate_planning_budgets import milp_reference, scenarios


class SimulationTests(unittest.TestCase):
    def test_balanced_grid_and_stress_cases_are_reproducible(self):
        for name in ("rudolstadt-2026", "fantasy-2027"):
            dataset = load_dataset(name)
            first = list(scenarios(dataset, 2))
            self.assertEqual(first, list(scenarios(dataset, 2)))
            self.assertEqual(len(first), 200)
            self.assertEqual(len({s.id for s in first}), 200)
            regular = [s for s in first if s.kind == "factorial"]
            self.assertEqual(len(regular), 192)
            groups = {}
            by_id = {e.id: e for e in dataset.events}
            for scenario in regular:
                self.assertEqual(len(scenario.saved), scenario.saved_requested)
                key = (scenario.density, scenario.mix, scenario.time, scenario.seed)
                groups.setdefault(key, []).append(scenario)
                saved = [by_id[id] for id in scenario.saved]
                self.assertEqual(len({e.artist for e in saved}), len(saved))
                for i, event in enumerate(saved):
                    self.assertTrue(all(not transition_conflict(event, other, dataset.transfers)
                                        for other in saved[:i]))
            for values in groups.values():
                values.sort(key=lambda s: s.saved_requested)
                for smaller, larger in zip(values, values[1:]):
                    self.assertEqual(smaller.saved, larger.saved[:len(smaller.saved)])
                    self.assertEqual(smaller.ratings, larger.ratings)

    def test_independent_milp_reference_finds_known_optimum(self):
        try:
            import scipy  # Optional dependency for independent verification.
        except ImportError:
            self.skipTest("SciPy not installed")
        graph = Graph((0b110, 0b001, 0b001), (1080, 1080, 1080))
        result = milp_reference(graph, 2)
        self.assertEqual(result["reference_status"], "optimal")
        self.assertEqual(result["reference_score"], 2160)


if __name__ == "__main__":
    unittest.main()
