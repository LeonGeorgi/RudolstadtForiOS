#!/usr/bin/env python3
"""Save all official SentenceSimilarity scores and an exploratory threshold review."""

import hashlib
import json
from collections import Counter
from datetime import datetime, timezone

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from analyze_artist_pca import DIRECTORY, ROOT, write_json


THRESHOLD = 0.85
UNCERTAIN_FLOOR = 0.80
SIMILARITY_BOUNDARY = 0.81


def review_threshold(threshold, judged):
    counts = Counter()
    for pair in judged:
        if pair["judgment"] not in {"similar", "different"}:
            continue
        predicted = pair["cosine_similarity"] >= threshold
        actual = pair["judgment"] == "similar"
        counts[(predicted, actual)] += 1
    tp, fp = counts[(True, True)], counts[(True, False)]
    fn, tn = counts[(False, True)], counts[(False, False)]
    return {"threshold": float(threshold), "true_positive": tp, "false_positive": fp,
            "false_negative": fn, "true_negative": tn,
            "precision_on_reviewed_examples": tp / (tp + fp) if tp + fp else None,
            "recall_on_reviewed_examples": tp / (tp + fn),
            "balanced_accuracy_on_reviewed_examples": ((tp / (tp + fn)) + (tn / (tn + fp))) / 2}


def main():
    source_path = DIRECTORY / "2026_artist_sentence_similarity_embeddings.json"
    source_bytes = source_path.read_bytes()
    source = json.loads(source_bytes)
    if source["prompt_name"] != "SentenceSimilarity" or source["prompt"] != "task: sentence similarity | query: ":
        raise ValueError("Expected the official SentenceSimilarity prompt")
    artists = [artist for artist in source["artists"] if artist["vector"] is not None]
    matrix = np.asarray([artist["vector"] for artist in artists], dtype=np.float64)
    if matrix.shape != (len(artists), 768) or not np.isfinite(matrix).all():
        raise ValueError("Invalid vectors")
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    if not np.allclose(norms, 1, atol=1e-5):
        raise ValueError("Expected normalized model vectors")
    matrix /= norms
    scores = np.clip(matrix @ matrix.T, -1, 1)
    by_name = {artist["name"]: index for index, artist in enumerate(artists)}
    if len(by_name) != len(artists):
        raise ValueError("Duplicate artist names cannot be used for the review")
    judged, inputs = [], []
    reviewed_keys = set()
    for filename, phase in [("sentence_similarity_pair_judgments.json", "before_score_inspection"),
                            ("sentence_similarity_audit_judgments.json", "high_score_audit")]:
        path = DIRECTORY / filename
        contents = path.read_bytes()
        review = json.loads(contents)
        inputs.append({"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(contents).hexdigest(),
                       "phase": phase, "basis": review["basis"], "limitations": review["limitations"]})
        for pair in review["pairs"]:
            indices = [by_name[name] for name in pair["artists"]]
            key = tuple(sorted(indices))
            if indices[0] == indices[1] or key in reviewed_keys:
                raise ValueError("Duplicate or identical-artist reviewed pair")
            reviewed_keys.add(key)
            judged.append({**pair, "phase": phase, "artist_ids": [artists[i]["artist_id"] for i in indices],
                           "cosine_similarity": float(scores[indices[0], indices[1]])})
    upper = np.triu_indices(len(artists), 1)
    values = scores[upper]
    pairs = [{"artist_a_id": artists[i]["artist_id"], "artist_b_id": artists[j]["artist_id"],
              "cosine_similarity": float(score),
              "passes_provisional_similarity_boundary": bool(score >= SIMILARITY_BOUNDARY),
              "interpretation": "similarity_candidate" if score >= THRESHOLD else
                                "uncertain" if score >= UNCERTAIN_FLOOR else "weak_similarity_evidence"}
             for i, j, score in zip(upper[0], upper[1], values)]
    pairs.sort(key=lambda pair: pair["cosine_similarity"], reverse=True)
    thresholds = []
    for threshold in [0.80, 0.81, 0.82, 0.84, 0.85, 0.86, 0.87, 0.88, 0.90]:
        mask = scores >= threshold
        np.fill_diagonal(mask, False)
        thresholds.append({**review_threshold(threshold, judged),
                           "festival_pair_count": int(np.count_nonzero(values >= threshold)),
                           "artists_with_at_least_one_match": int(np.count_nonzero(mask.sum(axis=1)))})
    result = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "model": source["model"], "prompt": source["prompt"], "prompt_name": source["prompt_name"],
        "dimensions": 768, "dimensionality_reduction": None, "similarity_metric": "cosine",
        "source_embeddings": str(source_path.relative_to(ROOT)),
        "source_embeddings_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "artist_count": len(artists), "pair_count": len(pairs),
        "excluded_missing_vectors": [{"artist_id": artist["artist_id"], "name": artist["name"]}
                                     for artist in source["artists"] if artist["vector"] is None],
        "threshold_policy": {"provisional_binary_similarity_boundary": SIMILARITY_BOUNDARY,
                             "binary_boundary_selection": "Best balanced accuracy on the reviewed similar/different examples among the tested threshold grid; rounded exploratory estimate, not independent validation",
                             "recommendation_filter_threshold": THRESHOLD, "uncertain_floor": UNCERTAIN_FLOOR,
                             "status": "provisional, not a validated binary musical-similarity boundary",
                             "rationale": "0.80 admits roughly half of all pairs. 0.85 keeps a narrower recommendation candidate set while retaining examples such as Hotel Rimini/Florian Paul and Wowakin/Kapela Janiszewskich. Higher cutoffs lose these plausible matches and still retain known false positives.",
                             "below_threshold_meaning": "Weaker text-embedding evidence; not proof of different musical styles"},
        "score_distribution": {key: float(value) for key, value in zip(
            ["minimum", "p10", "median", "p90", "p95", "p99", "maximum"],
            np.quantile(values, [0, .1, .5, .9, .95, .99, 1]))},
        "review_inputs": inputs, "reviewed_pairs": judged, "threshold_comparison": thresholds,
        "limitations": ["Cosine scores are not probabilities or percentages of musical similarity.",
                       "Review judgments are subjective and description-based, not listener labels.",
                       "Example selection is not representative; the high-score audit is score-informed.",
                       "Reported precision and recall describe only these reviewed examples, not the festival as a whole.",
                       "Full descriptions include non-musical information; the threshold does not make non-musical entries comparable artists."],
        "artists": [{"artist_id": artist["artist_id"], "name": artist["name"]} for artist in artists],
        "pairs": pairs,
    }
    output = DIRECTORY / "artist_sentence_similarity_scores.json"
    write_json(output, result)

    figure, axes = plt.subplots(2, 1, figsize=(12, 7), gridspec_kw={"height_ratios": [2, 1.4]}, layout="constrained")
    axes[0].hist(values, bins=np.arange(.65, .921, .005), color="#778b9d", edgecolor="white", linewidth=.3)
    axes[0].set_ylabel("Anzahl Künstlerpaare")
    axes[0].set_title("SentenceSimilarity · alle 11.476 Festival-Paare", loc="left")
    rng = np.random.default_rng(17)
    for row, judgment, label, color in [(0, "different", "Unterschiedlicher Stil", "#b9423b"),
                                        (1, "similar", "Ähnlicher Stil", "#23826a"),
                                        (2, "uncertain", "Beschreibung unklar", "#8b759f")]:
        points = [pair["cosine_similarity"] for pair in judged if pair["judgment"] == judgment]
        axes[1].scatter(points, row + rng.uniform(-.12, .12, len(points)), color=color, s=42, alpha=.85)
    axes[1].set_yticks([0, 1, 2], ["Unterschiedlicher Stil", "Ähnlicher Stil", "Beschreibung unklar"])
    axes[1].set_ylim(-.5, 2.5)
    axes[1].set_title("Subjektive Prüfung anhand der Festivalbeschreibungen · kein Hörtest", loc="left", fontsize=11)
    for axis in axes:
        axis.axvspan(UNCERTAIN_FLOOR, THRESHOLD, color="#e4bd60", alpha=.18)
        axis.axvline(SIMILARITY_BOUNDARY, color="#25639f", linewidth=1.5, label="Vorläufige Trennschwelle: 0,81")
        axis.axvline(THRESHOLD, color="#23826a", linewidth=1.5, linestyle="--", label="Engerer Empfehlungsfilter: 0,85")
        axis.axvline(UNCERTAIN_FLOOR, color="#9a7937", linewidth=1, linestyle="--")
        axis.set_xlim(.65, .92)
        axis.spines[["top", "right"]].set_visible(False)
    axes[0].legend(frameon=False)
    axes[1].set_xlabel("Kosinusähnlichkeit · kein Prozentwert")
    figure.savefig(DIRECTORY / "sentence_similarity_threshold.png", dpi=170)
    figure.savefig(DIRECTORY / "sentence_similarity_threshold.svg")
    plt.close(figure)
    print(json.dumps({"saved": str(output), "reviewed_count": len(judged),
                      "distribution": result["score_distribution"], "thresholds": thresholds}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
