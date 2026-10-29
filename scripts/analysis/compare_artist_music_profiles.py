#!/usr/bin/env python3
"""Compare frozen DE/EN music profiles with existing full-description scores.

Run with .venv-analysis/bin/python -B scripts/analysis/compare_artist_music_profiles.py.
Uses the cached model offline and writes only MusicProfilePilot experiment files.
Ranks are within the selected sample; no production threshold is calibrated here.
"""

import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch
from scipy.stats import spearmanr
from sentence_transformers import SentenceTransformer

from embed_artist_descriptions import plain_description


ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "artifacts/artist-similarity"
PILOT = DIRECTORY / "MusicProfilePilot"


def read_json(path):
    content = path.read_bytes()
    return json.loads(content), hashlib.sha256(content).hexdigest()


def rankings(matrix, ids):
    return {
        artist_id: [ids[j] for j in sorted(
            (j for j in range(len(ids)) if j != i),
            key=lambda j: (-matrix[i, j], ids[j]),
        )]
        for i, artist_id in enumerate(ids)
    }


def review_summary(pairs, method):
    positives = [p for p in pairs if p["judgment"] == "similar"]
    negatives = [p for p in pairs if p["judgment"] == "different"]
    positive_scores = [p[method]["cosine"] for p in positives]
    negative_scores = [p[method]["cosine"] for p in negatives]
    comparisons = [float(a > b) + 0.5 * float(a == b)
                   for a in positive_scores for b in negative_scores]
    return {
        "similar_pair_count": len(positives),
        "different_pair_count": len(negatives),
        "similar_pair_directional_top5_count": sum(
            rank <= 5 for p in positives for rank in p[method]["ranks"]
        ),
        "different_pair_directional_top5_count": sum(
            rank <= 5 for p in negatives for rank in p[method]["ranks"]
        ),
        "similar_pair_mean_rank": float(np.mean([
            rank for p in positives for rank in p[method]["ranks"]
        ])),
        "reviewed_pair_score_auc": float(np.mean(comparisons)),
    }


def main():
    profiles, profile_hash = read_json(PILOT / "profiles.json")
    translations, translation_hash = read_json(PILOT / "english_profiles.json")
    backup, backup_hash = read_json(ROOT / profiles["source"])
    baseline, baseline_hash = read_json(DIRECTORY / "artist_sentence_similarity_scores.json")
    source, source_hash = read_json(ROOT / baseline["source_embeddings"])
    catalog, _ = read_json(ROOT / "shared/src/commonMain/resources/2026_artist_similarities.json")
    assert baseline_hash == catalog["provenance"]["sourceScoresSHA256"]
    assert source_hash == baseline["source_embeddings_sha256"]
    assert backup_hash == source["source"]["sha256"]
    assert source["prompt_name"] == "SentenceSimilarity"
    artists_by_id = {a["id"]: a for a in backup["artists"]}
    assert len({a["artist_id"] for a in profiles["artists"]}) == len(profiles["artists"])
    artists = []
    for profile in profiles["artists"]:
        artist = artists_by_id[profile["artist_id"]]
        assert artist["name"] == profile["name"]
        description = " ".join(plain_description(artist["description_de"]).split())
        for fact in profile["facts"]:
            assert " ".join(fact["evidence"].split()) in description, (
                profile["name"], fact["evidence"]
            )
        if profile["status"] == "usable":
            assert profile["facts"]
            artists.append({
                "artist_id": profile["artist_id"], "name": profile["name"],
                "de": " ".join(f["text"] for f in profile["facts"]),
                "en": translations["profiles"][str(profile["artist_id"])],
            })
        else:
            assert not profile["facts"]
    ids = [a["artist_id"] for a in artists]
    assert set(translations["profiles"]) == {str(i) for i in ids}
    model_info = source["model"]
    model_path = (Path.home() / ".cache/huggingface/hub"
                  / f"models--{model_info['id'].replace('/', '--')}"
                  / "snapshots" / model_info["revision"])
    torch.set_num_threads(4)
    model = SentenceTransformer(
        str(model_path), local_files_only=True, device="cpu",
        model_kwargs={"torch_dtype": torch.float32},
        config_kwargs={"vision_config": None, "audio_config": None},
    )
    assert model.prompts["SentenceSimilarity"] == source["prompt"]
    matrices, vectors = {}, {}
    for language in ["de", "en"]:
        texts = [a[language] for a in artists]
        assert all(len(model.tokenizer(source["prompt"] + text)["input_ids"])
                   <= model.max_seq_length for text in texts)
        print(f"Embedding {len(texts)} frozen {language.upper()} profiles", flush=True)
        matrix = model.encode(
            texts, prompt_name="SentenceSimilarity", normalize_embeddings=True,
            batch_size=4, show_progress_bar=False, convert_to_numpy=True,
        ).astype(np.float64)
        assert matrix.shape == (len(ids), source["dimensions"])
        assert np.isfinite(matrix).all()
        assert np.allclose(np.linalg.norm(matrix, axis=1), 1, atol=1e-5)
        matrix /= np.linalg.norm(matrix, axis=1, keepdims=True)
        vectors[language] = matrix
        matrices[language] = np.clip(matrix @ matrix.T, -1, 1)
    index = {artist_id: i for i, artist_id in enumerate(ids)}
    old = np.eye(len(ids))
    for pair in baseline["pairs"]:
        a, b = pair["artist_a_id"], pair["artist_b_id"]
        if a in index and b in index:
            old[index[a], index[b]] = old[index[b], index[a]] = pair["cosine_similarity"]
    matrices["full_description_de"] = old
    ranked = {method: rankings(matrix, ids) for method, matrix in matrices.items()}
    reviewed = []
    for pair in baseline["reviewed_pairs"]:
        a, b = pair["artist_ids"]
        if a not in index or b not in index:
            continue
        reviewed.append({
            "artist_ids": [a, b], "artists": pair["artists"],
            "judgment": pair["judgment"], "reason": pair["reason"],
            **{method: {
                "cosine": float(matrix[index[a], index[b]]),
                "ranks": [ranked[method][a].index(b) + 1, ranked[method][b].index(a) + 1],
            } for method, matrix in matrices.items()},
        })
    upper = np.triu_indices(len(ids), 1)
    de_values, en_values = matrices["de"][upper], matrices["en"][upper]
    incoming = {
        method: Counter(j for neighbors in lists.values() for j in neighbors[:5])
        for method, lists in ranked.items()
    }
    results = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "source_hashes": {"profiles": profile_hash, "translations": translation_hash,
                          "backup": backup_hash, "baseline_scores": baseline_hash},
        "model": model_info, "prompt": source["prompt"],
        "sample_size": len(ids), "pair_count": len(de_values),
        "excluded": [p for p in profiles["artists"] if p["status"] != "usable"],
        "threshold": None,
        "limitations": [
            "Purposively selected small sample; all rankings are within this sample, not the full festival.",
            "Manual assistant extraction and translation, aware of prior judgments; not blinded or held out.",
            "Existing judgments are subjective and description-based, not listening-test labels.",
            "Scores from shorter profiles are not calibrated against the existing 0.85 threshold.",
            "No post-score edits, tuning, new model training, audio analysis or production changes.",
        ],
        "review_summary": {method: review_summary(reviewed, method) for method in matrices},
        "language_comparison": {
            "pair_score_spearman": float(spearmanr(de_values, en_values).statistic),
            "mean_absolute_pair_score_difference": float(np.mean(np.abs(de_values - en_values))),
            "same_top1_count": sum(ranked["de"][i][0] == ranked["en"][i][0] for i in ids),
            "top5_mean_shared_count": float(np.mean([
                len(set(ranked["de"][i][:5]) & set(ranked["en"][i][:5])) for i in ids
            ])),
            "same_artist_cross_language_cosine": {
                str(i): float(vectors["de"][index[i]] @ vectors["en"][index[i]]) for i in ids
            },
        },
        "reviewed_pairs": reviewed,
        "artists": [{**a,
            "neighbors": {method: [{"artist_id": j, "name": artists_by_id[j]["name"],
                                     "cosine": float(matrices[method][index[a['artist_id']], index[j]])}
                                    for j in ranked[method][a["artist_id"]]] for method in matrices},
            "top5_incoming": {method: counts[a["artist_id"]] for method, counts in incoming.items()},
        } for a in artists],
    }
    (PILOT / "results.json").write_text(json.dumps(results, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    (PILOT / "embeddings.json").write_text(json.dumps({
        "model": model_info, "prompt": source["prompt"], "source_hashes": results["source_hashes"],
        "artists": [{"artist_id": i, "de": vectors["de"][index[i]].tolist(),
                     "en": vectors["en"][index[i]].tolist()} for i in ids],
    }, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    print(json.dumps({"review_summary": results["review_summary"],
                      "language_comparison": results["language_comparison"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
