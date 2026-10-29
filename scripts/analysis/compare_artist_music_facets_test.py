import unittest

from compare_artist_music_facets import ranked_neighbors, weighted_score


WEIGHTS = {"style": 0.7, "instrumentation": 0.1, "vocals": 0.1, "rhythm": 0.1}


class MusicFacetComparisonTests(unittest.TestCase):
    def test_shared_instrument_without_known_style_cannot_create_recommendation(self):
        score, coverage = weighted_score({"instrumentation": 1.0}, WEIGHTS)
        self.assertIsNone(score)
        self.assertEqual(coverage, 0)

    def test_missing_facets_do_not_count_as_matches(self):
        score, coverage = weighted_score({"style": 0.8}, WEIGHTS)
        self.assertAlmostEqual(score, 0.8)
        self.assertAlmostEqual(coverage, 0.7)

    def test_matching_instrument_cannot_overturn_stronger_style_match(self):
        close_style, _ = weighted_score({"style": 0.9, "instrumentation": 0.4}, WEIGHTS)
        distant_style, _ = weighted_score({"style": 0.6, "instrumentation": 1}, WEIGHTS)
        self.assertGreater(close_style, distant_style)

    def test_rankings_exclude_self_and_unknown_similarity_without_padding(self):
        scores = {(1, 1): 1, (1, 2): None, (1, 3): 0.8, (1, 4): 0.9}
        self.assertEqual(ranked_neighbors(1, [1, 2, 3, 4, 5], scores), [4, 3])


if __name__ == "__main__":
    unittest.main()
