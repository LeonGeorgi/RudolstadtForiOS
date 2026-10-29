#!/usr/bin/env python3
"""Diagnostic distance comparison on frozen audio vectors, without new inference.

Run with .venv-analysis/bin/python -B scripts/analysis/compare_artist_audio_distances.py.
Local scaling uses the fifth neighbor, excluding self; no parameter search.
All review labels are the prior subjective, description-based judgments.
"""

from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy.spatial.distance import cdist

from compare_artist_music_profiles import rankings, read_json, review_summary
from embed_artist_audio import aggregate, normalized, write_json


DIRECTORY = (Path(__file__).resolve().parents[2]
             / "artifacts/artist-similarity/MusicProfilePilot/AudioEmbeddingGemma")


def scores(vectors):
    vectors = normalized(vectors)
    cosine = np.clip(vectors @ vectors.T, -1, 1)
    euclidean = cdist(vectors, vectors, metric="euclidean")
    np.testing.assert_allclose(euclidean ** 2, np.maximum(2 - 2 * cosine, 0), atol=1e-12)
    centered = normalized(vectors - vectors.mean(axis=0))
    distances = euclidean.copy()
    np.fill_diagonal(distances, np.inf)
    radii = np.sort(distances, axis=1)[:, 4]
    assert np.all(radii > 0)
    return {
        "cosine": cosine,
        "euclidean": -euclidean,
        "angular": -np.arccos(cosine),
        "manhattan": -cdist(vectors, vectors, metric="cityblock"),
        "centered_cosine": np.clip(centered @ centered.T, -1, 1),
        "local_scaling_k5": np.exp(-euclidean ** 2 / (radii[:, None] * radii[None, :])),
    }


def main():
    original, original_hash = read_json(DIRECTORY / "results.json")
    embeddings, embeddings_hash = read_json(DIRECTORY / "artist_embeddings.json")
    windows, windows_hash = read_json(DIRECTORY / "window_embeddings.json")
    ids = [a["artist_id"] for a in embeddings["artists"]]
    index = {artist_id: i for i, artist_id in enumerate(ids)}
    names = {a["artist_id"]: a["name"] for a in original["artists"]}
    vectors = normalized([a["embedding"] for a in embeddings["artists"]])
    matrices = scores(vectors)
    ranked = {method: rankings(matrix, ids) for method, matrix in matrices.items()}
    # Unit-vector Euclidean and angular distances must preserve cosine ordering.
    assert ranked["cosine"] == ranked["euclidean"] == ranked["angular"]
    halves = [scores(aggregate(windows["recordings"], ids, slice(offset, None, 2))) for offset in [0, 1]]
    split_ranks = [{method: rankings(matrix, ids) for method, matrix in half.items()} for half in halves]
    reviewed = []
    for pair in original["reviewed_pairs"]:
        a, b = pair["artist_ids"]
        reviewed.append({key: pair[key] for key in ["artist_ids", "artists", "judgment", "reason"]} | {
            method: {"cosine": float(matrix[index[a], index[b]]),
                     "ranks": [ranked[method][a].index(b) + 1, ranked[method][b].index(a) + 1]}
            for method, matrix in matrices.items()
        })
    summaries = {}
    for method in matrices:
        incoming = Counter(j for neighbors in ranked[method].values() for j in neighbors[:5])
        summaries[method] = {
            **review_summary(reviewed, method),
            "max_top5_incoming": max(incoming.values()),
            "artists_at_max": [names[i] for i in ids if incoming[i] == max(incoming.values())],
            "zwei_stimmen_top5_incoming": incoming[293],
            "alternating_windows_same_top1_count": sum(
                split_ranks[0][method][i][0] == split_ranks[1][method][i][0] for i in ids),
            "alternating_windows_top5_mean_shared_count": float(np.mean([
                len(set(split_ranks[0][method][i][:5]) & set(split_ranks[1][method][i][:5])) for i in ids])),
            "same_top1_as_cosine_count": sum(ranked[method][i][0] == ranked["cosine"][i][0] for i in ids),
        }
    assert summaries["cosine"]["similar_pair_directional_top5_count"] == original["review_summary"]["audio"]["similar_pair_directional_top5_count"]
    for pair in reviewed:
        for method in matrices:
            pair[method]["score"] = pair[method].pop("cosine")
    output = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "source_sha256": {"results": original_hash, "artist_embeddings": embeddings_hash,
                          "window_embeddings": windows_hash},
        "model": embeddings["model"], "sample_size": len(ids), "new_embeddings_computed": False,
        "score_convention": "Higher is more similar; only cosine methods are cosine scores",
        "methods": {
            "cosine": "Dot product of unit artist vectors",
            "euclidean": "Negative Euclidean distance of the same unit vectors",
            "angular": "Negative arccos of cosine, in radians",
            "manhattan": "Negative sum of absolute coordinate differences",
            "centered_cosine": "Subtract sample mean from each artist vector, renormalize, then cosine",
            "local_scaling_k5": "exp(-d(i,j)^2 / (sigma(i)*sigma(j))); Euclidean d, sigma = fifth non-self neighbor distance",
        },
        "limitations": [
            "Exploratory comparison on the same small sample, not a held-out model selection benchmark.",
            "Review labels are subjective and description-based, not independent listening judgments.",
            "Centering and local scaling depend on the artist cohort and are not plain metric substitutions.",
            "No parameter search; k=5 fixed to match the existing top-five neighborhood size.",
            "Alternating-window stability is within-recording stability, not across-song generalization.",
            "No production changes or recommendation threshold calibration.",
        ],
        "summary": summaries, "reviewed_pairs": reviewed,
        "artists": [{"artist_id": i, "name": names[i], "neighbors": {
            method: [{"artist_id": j, "name": names[j], "score": float(matrices[method][index[i], index[j]])}
                     for j in ranked[method][i]] for method in matrices}} for i in ids],
    }
    write_json(DIRECTORY / "distance_comparison.json", output)
    for method, summary in summaries.items():
        print(method, summary, flush=True)


if __name__ == "__main__":
    main()
