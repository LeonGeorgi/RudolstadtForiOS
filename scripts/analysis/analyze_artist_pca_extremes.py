#!/usr/bin/env python3
"""Compare EOM clustering at 10, 5, 3 and 2 dimensions using the saved PCA fit."""

import hashlib
import json
from datetime import datetime, timezone

import numpy as np

from analyze_artist_pca import DIRECTORY, ROOT, clustering_summary, write_json


def main():
    analysis_path = DIRECTORY / "artist_pca_analysis.json"
    analysis_bytes = analysis_path.read_bytes()
    analysis = json.loads(analysis_bytes)
    source_path = ROOT / analysis["source_embeddings"]
    source_bytes = source_path.read_bytes()
    source = json.loads(source_bytes)
    if hashlib.sha256(source_bytes).hexdigest() != analysis["source_embeddings_sha256"]:
        raise ValueError("PCA fit refers to different embeddings")
    artists = [artist for artist in source["artists"] if artist["vector"] is not None]
    if [artist["artist_id"] for artist in artists] != [artist["artist_id"] for artist in analysis["artists"]]:
        raise ValueError("PCA coordinates and source artist order differ")
    coordinates = np.asarray([artist["pca_coordinates"] for artist in analysis["artists"]])
    parameters = analysis["clustering_parameters"]
    if (parameters["cluster_selection_method"], parameters["min_cluster_size"], parameters["min_samples"]) != ("eom", 2, 2):
        raise ValueError("Expected the agreed EOM settings")
    runs = []
    for count in [10, 5, 3, 2]:
        projected = coordinates[:, :count].copy()
        norms = np.linalg.norm(projected, axis=1, keepdims=True)
        if not np.isfinite(projected).all() or np.any(norms == 0):
            raise ValueError("Invalid projected vectors")
        projected /= norms
        summary = clustering_summary(projected, parameters)
        records = [{"artist_id": artist["artist_id"], "name": artist["name"],
                    "vector": vector.tolist(), "cluster_id": label, "membership_strength": strength}
                   for artist, vector, label, strength in zip(
                       artists, projected, summary["labels"], summary["membership_strengths"])]
        clusters = [{"cluster_id": label, "size": summary["labels"].count(label),
                     "artist_ids": [record["artist_id"] for record in records if record["cluster_id"] == label]}
                    for label in sorted(set(summary["labels"]) - {-1})]
        run = {"dimensions": count,
               "retained_variance": analysis["pca"]["cumulative_explained_variance"][count - 1],
               "cluster_count": summary["cluster_count"], "noise_count": summary["noise_count"],
               "cluster_sizes": summary["cluster_sizes"], "clusters": clusters,
               "noise_artist_ids": [record["artist_id"] for record in records if record["cluster_id"] == -1],
               "artists": records}
        runs.append(run)
        print(json.dumps({key: run[key] for key in ["dimensions", "retained_variance", "cluster_count", "noise_count", "cluster_sizes"]}))
    result = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "method": "HDBSCAN* with EOM extraction after PCA reduction",
        "model": source["model"], "prompt": source["prompt"], "prompt_name": source["prompt_name"],
        "source_embeddings": analysis["source_embeddings"],
        "source_embeddings_sha256": analysis["source_embeddings_sha256"],
        "pca_fit": {"path": str(analysis_path.relative_to(ROOT)),
                    "sha256": hashlib.sha256(analysis_bytes).hexdigest(),
                    "reused_existing_fit": True, "centered": True, "whiten": False},
        "clustering_parameters": parameters, "artist_count": len(artists),
        "excluded_missing_vectors": [{"artist_id": artist["artist_id"], "name": artist["name"]}
                                     for artist in source["artists"] if artist["vector"] is None],
        "distance": "1 - cosine similarity in centered PCA coordinates",
        "normalized": True,
        "limitations": ["Variance retained is measured before per-artist normalization.",
                       "Cosine distances compare directions and ignore radial differences; at two dimensions only angular position remains.",
                       "Musical quality of the clusters has not been validated."],
        "runs": runs,
    }
    output = DIRECTORY / "artist_pca_extreme_clusters.json"
    write_json(output, result)
    print(f"Saved {output}")


if __name__ == "__main__":
    main()
