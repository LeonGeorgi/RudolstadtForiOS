#!/usr/bin/env python3
"""Analyze PCA variance and EOM clustering for all festival Clustering vectors.

Keep the minimum number of components explaining at least 90% of variance.
Save the projection, full variance spectrum, comparison runs and reduced vectors.
"""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import sklearn
from sklearn.cluster import HDBSCAN
from sklearn.decomposition import PCA
from sklearn.metrics.pairwise import cosine_distances


ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "artifacts/artist-similarity"
TARGET_VARIANCE = 0.90


def write_json(path, value):
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(path)


def clustering_summary(matrix, parameters):
    distances = cosine_distances(matrix)
    distances = (distances + distances.T) / 2
    np.fill_diagonal(distances, 0)
    estimator = HDBSCAN(**parameters).fit(distances)
    labels = estimator.labels_
    sizes = [int(np.count_nonzero(labels == label)) for label in sorted(set(labels) - {-1})]
    return {
        "cluster_count": len(sizes), "cluster_sizes": sizes,
        "noise_count": int(np.count_nonzero(labels == -1)),
        "labels": labels.tolist(), "membership_strengths": estimator.probabilities_.tolist(),
    }


def main():
    source_path = DIRECTORY / "2026_artist_clustering_embeddings.json"
    source_bytes = source_path.read_bytes()
    source = json.loads(source_bytes)
    source_hash = hashlib.sha256(source_bytes).hexdigest()
    baseline_path = DIRECTORY / "artist_clustering_prompt_hdbscan_min2.json"
    baseline_bytes = baseline_path.read_bytes()
    baseline = json.loads(baseline_bytes)
    if baseline["inputs"][0]["sha256"] != source_hash:
        raise ValueError("Baseline refers to different embeddings")
    parameters = baseline["parameters"]
    if parameters["min_cluster_size"] != 2 or parameters["min_samples"] != 2:
        raise ValueError("Expected the agreed minimum size and min_samples of two")
    if parameters["cluster_selection_method"] != "eom":
        raise ValueError("Expected EOM extraction")

    artists = [artist for artist in source["artists"] if artist["vector"] is not None]
    matrix = np.asarray([artist["vector"] for artist in artists], dtype=np.float64)
    if matrix.shape != (len(artists), source["dimensions"]) or not np.isfinite(matrix).all():
        raise ValueError("Invalid source vectors")
    # Center, but do not standardize features or whiten component variances.
    pca = PCA(svd_solver="full", whiten=False).fit(matrix)
    coordinates = pca.transform(matrix)
    cumulative = np.cumsum(pca.explained_variance_ratio_)
    thresholds = {str(target): int(np.searchsorted(cumulative, target) + 1)
                  for target in [0.50, 0.80, 0.90, 0.95, 0.99]}
    selected = thresholds[str(TARGET_VARIANCE)]
    rank = int(np.linalg.matrix_rank(matrix - pca.mean_))
    counts = sorted(set([10, 20, 30, 50, rank] +
                        [thresholds[str(target)] for target in [0.80, 0.90, 0.95]]))
    runs = []
    for count in counts:
        summary = clustering_summary(coordinates[:, :count], parameters)
        runs.append({"dimensions": count, "retained_variance": float(cumulative[count - 1]),
                     **summary})

    centered = clustering_summary(matrix - pca.mean_, parameters)
    full_projection = next(run for run in runs if run["dimensions"] == rank)
    if centered["labels"] != full_projection["labels"]:
        raise ValueError("Full PCA must agree with the centering-only control")
    created_at = datetime.now(timezone.utc).isoformat()
    projection = {
        "method": "PCA", "solver": "full SVD", "centered": True,
        "feature_standardization": False, "whiten": False,
        "original_dimensions": source["dimensions"], "retained_dimensions": selected,
        "selection_rule": "Smallest component count retaining at least 90% of variance",
        "retained_variance": float(cumulative[selected - 1]),
        "normalization_after_projection": "L2 normalization per artist",
        "source_embeddings": str(source_path.relative_to(ROOT)),
        "source_embeddings_sha256": source_hash,
        "fitted_projection": "artifacts/artist-similarity/artist_pca_analysis.json",
    }
    analysis = {
        "schema_version": 1, "created_at": created_at,
        "runtime": {"numpy": np.__version__, "scikit_learn": sklearn.__version__},
        "model": source["model"], "prompt": source["prompt"], "prompt_name": source["prompt_name"],
        "source_embeddings": projection["source_embeddings"], "source_embeddings_sha256": source_hash,
        "baseline": {"path": str(baseline_path.relative_to(ROOT)),
                     "sha256": hashlib.sha256(baseline_bytes).hexdigest(),
                     "cluster_count": baseline["cluster_count"], "noise_count": baseline["noise_count"],
                     "cluster_sizes": [cluster["size"] for cluster in baseline["clusters"]]},
        "artist_count": len(artists), "centered_rank": rank,
        "eigenvalue_interpretation": "Covariance eigenvalues measure variance in principal directions, not musical relevance or the importance of individual original embedding coordinates",
        "pca": {**projection, "mean": pca.mean_.tolist(), "components": pca.components_.tolist(),
                "eigenvalues": pca.explained_variance_.tolist(),
                "explained_variance_ratios": pca.explained_variance_ratio_.tolist(),
                "cumulative_explained_variance": cumulative.tolist(),
                "components_needed_for_variance": thresholds},
        "clustering_parameters": parameters, "distance": "1 - cosine similarity in centered PCA coordinates",
        "centering_only_control": centered, "comparison_runs": runs,
        "artists": [{"artist_id": artist["artist_id"], "name": artist["name"],
                     "pca_coordinates": row.tolist()} for artist, row in zip(artists, coordinates)],
        "limitations": ["No musical quality validation has been performed.",
                       "Centering itself changes cosine distances, even without dimensionality reduction.",
                       "The variance threshold was selected independently of cluster counts."],
    }
    reduced = coordinates[:, :selected].copy()
    norms = np.linalg.norm(reduced, axis=1, keepdims=True)
    if not np.isfinite(reduced).all() or np.any(norms == 0):
        raise ValueError("Invalid projected vectors")
    reduced /= norms
    vectors = {artist["artist_id"]: row.tolist() for artist, row in zip(artists, reduced)}
    output = {**source, "created_at": created_at, "dimensions": selected,
              "dimensionality_reduction": projection,
              "artists": [{**artist, "vector": vectors.get(artist["artist_id"])}
                          for artist in source["artists"]]}
    write_json(DIRECTORY / "artist_pca_analysis.json", analysis)
    write_json(DIRECTORY / "2026_artist_clustering_pca90_embeddings.json", output)
    print(json.dumps({"selected_dimensions": selected, "variance_thresholds": thresholds,
                      "runs": [{key: run[key] for key in ["dimensions", "retained_variance", "cluster_count", "cluster_sizes", "noise_count"]}
                               for run in runs]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
