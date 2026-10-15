#!/usr/bin/env python3
"""Center frozen DE/EN music-profile embeddings; never modifies app data.

Run with .codex-tmp/embeddinggemma-env/bin/python -B scripts/center_artist_music_profiles.py.
Primary cohort: all 22 usable text profiles. A separate 21-artist cohort matches
the audio pilot. Each language and cohort gets its own unweighted centroid.
"""

from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr

from compare_artist_music_profiles import rankings, read_json, review_summary
from embed_artist_audio import normalized, write_json


PILOT = Path(__file__).resolve().parents[1] / "Experiments/ArtistSimilarity/MusicProfilePilot"
OUTPUT = PILOT / "Centering"


def compare_cohort(ids, vectors_by_id, names, judgments, verify_original=None):
    index = {artist_id: i for i, artist_id in enumerate(ids)}
    matrices, centroids, centered_vectors = {}, {}, {}
    for language in ["de", "en"]:
        vectors = normalized([vectors_by_id[i][language] for i in ids])
        centroid = vectors.mean(axis=0)
        residuals = vectors - centroid
        np.testing.assert_allclose(residuals.mean(axis=0), 0, atol=1e-12)
        centered = normalized(residuals)
        np.testing.assert_allclose(np.linalg.norm(centered, axis=1), 1, atol=1e-12)
        centered_vectors[language] = centered
        centroids[language] = centroid
        matrices[f"{language}_original"] = np.clip(vectors @ vectors.T, -1, 1)
        matrices[f"{language}_centered"] = np.clip(centered @ centered.T, -1, 1)
    ranked = {method: rankings(matrix, ids) for method, matrix in matrices.items()}
    reviewed = []
    for pair in judgments:
        a, b = pair["artist_ids"]
        assert a in index and b in index
        reviewed.append({key: pair[key] for key in ["artist_ids", "artists", "judgment", "reason"]} | {
            method: {"cosine": float(matrix[index[a], index[b]]),
                     "ranks": [ranked[method][a].index(b) + 1, ranked[method][b].index(a) + 1]}
            for method, matrix in matrices.items()
        })
    summary, top_pairs = {}, {}
    for method, matrix in matrices.items():
        incoming = Counter(j for neighbors in ranked[method].values() for j in neighbors[:5])
        language = method.split("_")[0]
        original_method = f"{language}_original"
        summary[method] = {
            **review_summary(reviewed, method),
            "max_top5_incoming": max(incoming.values()),
            "artists_at_max": [names[i] for i in ids if incoming[i] == max(incoming.values())],
            "same_top1_as_original_count": sum(ranked[method][i][0] == ranked[original_method][i][0] for i in ids),
            "top5_mean_shared_with_original": float(np.mean([
                len(set(ranked[method][i][:5]) & set(ranked[original_method][i][:5])) for i in ids])),
        }
        pairs = sorted(((float(matrix[index[a], index[b]]), a, b)
                        for a in ids for b in ids if a < b), key=lambda p: (-p[0], p[1], p[2]))
        top_pairs[method] = [{"artist_ids": [a, b], "artists": [names[a], names[b]], "cosine": score}
                             for score, a, b in pairs[:10]]
        if verify_original and method.endswith("original"):
            for key, value in verify_original[language].items():
                assert np.isclose(summary[method][key], value)
    upper = np.triu_indices(len(ids), 1)
    language_comparison = {}
    for suffix in ["original", "centered"]:
        de, en = f"de_{suffix}", f"en_{suffix}"
        language_comparison[suffix] = {
            "pair_score_spearman": float(spearmanr(matrices[de][upper], matrices[en][upper]).statistic),
            "same_top1_count": sum(ranked[de][i][0] == ranked[en][i][0] for i in ids),
            "top5_mean_shared_count": float(np.mean([
                len(set(ranked[de][i][:5]) & set(ranked[en][i][:5])) for i in ids])),
        }
    result = {
        "sample_size": len(ids), "pair_count": len(ids) * (len(ids) - 1) // 2,
        "artist_ids": ids, "summary": summary, "top_pairs": top_pairs,
        "centroid_norm": {language: float(np.linalg.norm(value)) for language, value in centroids.items()},
        "language_comparison": language_comparison, "reviewed_pairs": reviewed,
        "artists": [{"artist_id": i, "name": names[i],
                     "top5_incoming": {method: sum(i in neighbors[:5] for neighbors in lists.values())
                                       for method, lists in ranked.items()},
                     "neighbors": {method: [{"artist_id": j, "name": names[j],
                                             "cosine": float(matrix[index[i], index[j]])}
                                            for j in ranked[method][i]] for method, matrix in matrices.items()}}
                    for i in ids],
    }
    saved_vectors = {
        "artist_ids": ids, "centroids": {language: value.tolist() for language, value in centroids.items()},
        "artists": [{"artist_id": i, **{language: value[index[i]].tolist()
                                        for language, value in centered_vectors.items()}} for i in ids],
    }
    return result, saved_vectors


def main():
    source, source_hash = read_json(PILOT / "embeddings.json")
    previous, previous_hash = read_json(PILOT / "results.json")
    audio_protocol, audio_hash = read_json(PILOT / "AudioEmbeddingGemma/protocol.json")
    assert source["model"] == previous["model"]
    assert source["source_hashes"] == previous["source_hashes"]
    for filename, key in [("profiles.json", "profiles"), ("english_profiles.json", "translations")]:
        assert read_json(PILOT / filename)[1] == source["source_hashes"][key]
    vectors = {a["artist_id"]: a for a in source["artists"]}
    names = {a["artist_id"]: a["name"] for a in previous["artists"]}
    assert len(vectors) == len(names) == 22 and set(vectors) == set(names)
    assert all(len(a[language]) == 768 for a in vectors.values() for language in ["de", "en"])
    assert set(audio_protocol["artist_ids"]) < set(vectors)
    assert source["model"]["id"] == audio_protocol["model"]["id"]
    assert source["model"]["revision"] == audio_protocol["model"]["revision"]
    primary, primary_vectors = compare_cohort(sorted(vectors), vectors, names,
                                             previous["reviewed_pairs"], previous["review_summary"])
    matched, matched_vectors = compare_cohort(sorted(audio_protocol["artist_ids"]), vectors, names,
                                             previous["reviewed_pairs"])
    provenance = {
        "model": source["model"], "prompt": source["prompt"],
        "source_sha256": {"embeddings": source_hash, "original_results": previous_hash,
                          "audio_cohort_protocol": audio_hash},
        "method": "Normalize original vectors; subtract unweighted cohort mean per language; renormalize; cosine",
        "new_embeddings_computed": False,
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_json(OUTPUT / "results.json", {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(), **provenance,
        "threshold": None,
        "limitations": [
            "Small purposive sample; all neighbors and centroids depend on the selected cohort.",
            "Prior labels are subjective and description-based; not blinded or held out.",
            "No re-extraction, translation changes, model inference or parameter tuning.",
            "Centered scores do not share the original score scale; no threshold calibrated.",
            "Musical quality has not been independently established by a listening test.",
            "No application or production catalog changes.",
        ],
        "primary_22_artists": primary, "matched_audio_cohort_21_artists": matched,
    })
    write_json(OUTPUT / "embeddings.json", {
        **provenance, "primary_22_artists": primary_vectors,
        "matched_audio_cohort_21_artists": matched_vectors,
    })
    print("Primary 22 artists:", primary["summary"], flush=True)
    print("DE centered top 5:", primary["top_pairs"]["de_centered"][:5], flush=True)
    print("EN centered top 5:", primary["top_pairs"]["en_centered"][:5], flush=True)
    print("Language comparison:", primary["language_comparison"], flush=True)
    print("Matched 21 artists:", matched["summary"], flush=True)


if __name__ == "__main__":
    main()
