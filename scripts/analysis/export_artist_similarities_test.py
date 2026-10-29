import unittest

from export_artist_similarities import ranked_artist_ids


class ExportArtistSimilaritiesTests(unittest.TestCase):
    def test_threshold_ranking_and_both_directions(self):
        pairs = [
            {"artist_a_id": 1, "artist_b_id": 2, "cosine_similarity": 0.85},
            {"artist_a_id": 5, "artist_b_id": 1, "cosine_similarity": 0.9},
            {"artist_a_id": 1, "artist_b_id": 4, "cosine_similarity": 0.849999},
            {"artist_a_id": 3, "artist_b_id": 1, "cosine_similarity": 0.9},
        ]
        self.assertEqual(ranked_artist_ids(pairs, 0.85), {
            "1": [3, 5, 2], "2": [1], "3": [1], "5": [1],
        })

    def test_no_matches_below_threshold(self):
        self.assertEqual(ranked_artist_ids([
            {"artist_a_id": 1, "artist_b_id": 2, "cosine_similarity": 0.84},
        ], 0.85), {})


if __name__ == "__main__":
    unittest.main()
