"""Focused checks for the audio pilot's sampling and equal-song aggregation."""

import unittest

import numpy as np

from embed_artist_audio import aggregate, normalized, window_starts


class AudioPilotTests(unittest.TestCase):
    def test_sampling_stays_inside_short_recording(self):
        self.assertEqual(window_starts(10), [0.0] * 6)
        starts = window_starts(100)
        np.testing.assert_allclose(starts, [5, 21, 37, 53, 69, 85])
        with self.assertRaises(ValueError):
            window_starts(9)

    def test_each_song_has_equal_weight_despite_different_window_consistency(self):
        recordings = [
            {"artist_id": 1, "embeddings": [[1, 0], [-0.8, 0.6], [-0.8, -0.6]]},
            {"artist_id": 1, "embeddings": [[0, 1], [0, 1], [0, 1]]},
            {"artist_id": 2, "embeddings": [[1, 0], [1, 0]]},
        ]
        result = aggregate(recordings, [2, 1])
        np.testing.assert_allclose(result, [[1, 0], [-1 / np.sqrt(2), 1 / np.sqrt(2)]])
        self.assertFalse(np.allclose(result[1], normalized(np.mean(
            recordings[0]["embeddings"] + recordings[1]["embeddings"], axis=0))))

    def test_rejects_invalid_embeddings(self):
        for values in [[0, 0], [1, np.nan], [np.inf, 0]]:
            with self.assertRaises(ValueError):
                normalized(values)


if __name__ == "__main__":
    unittest.main()
