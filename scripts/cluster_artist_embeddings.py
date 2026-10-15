#!/usr/bin/env python3
"""Cluster the existing artist vectors with HDBSCAN* and EOM extraction.

Run with .codex-tmp/embeddinggemma-env/bin/python scripts/cluster_artist_embeddings.py.
Uses cosine distances on the supplied vectors, including saved PCA projections.
"""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import sklearn
from sklearn.cluster import HDBSCAN
from sklearn.metrics.pairwise import cosine_distances


ROOT = Path(__file__).resolve().parent.parent
DIRECTORY = ROOT / "Experiments/ArtistSimilarity"


def read_input(path):
    contents = path.read_bytes()
    return json.loads(contents), {
        "path": str(path.relative_to(ROOT)),
        "sha256": hashlib.sha256(contents).hexdigest(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--festival-scope", choices=["stage", "all"], default="stage")
    parser.add_argument("--exclude-references", action="store_true")
    parser.add_argument("--min-cluster-size", type=int, default=5)
    parser.add_argument("--min-samples", type=int)
    parser.add_argument("--embeddings", type=Path, default=DIRECTORY / "2026_artist_embeddings.json")
    parser.add_argument("--output", type=Path, default=DIRECTORY / "artist_hdbscan_clusters.json")
    args = parser.parse_args()
    festival, festival_input = read_input(args.embeddings.resolve())
    inputs = [festival_input]
    references = None
    if args.festival_scope == "stage" or not args.exclude_references:
        references, reference_input = read_input(DIRECTORY / "replay_stage_artist_matches.json")
        inputs.append(reference_input)
        if festival["model"] != references["model"] or festival["prompt"] != references["prompt"]:
            raise ValueError("Festival and reference embeddings are incompatible")
        if festival_input["sha256"] != references["inputs"]["festival_embeddings_sha256"]:
            raise ValueError("Festival embeddings have changed since the stage comparison")

    stage_ids = set(references["stage_filter"]["stage_artist_ids"]) if references else set()
    records, vectors, missing_vectors = [], [], []
    for artist in festival["artists"]:
        if args.festival_scope == "stage" and artist["artist_id"] not in stage_ids:
            continue
        if artist["vector"] is None:
            missing_vectors.append({"artist_id": artist["artist_id"], "name": artist["name"]})
            continue
        records.append({"id": f"festival:{artist['artist_id']}", "name": artist["name"],
                        "kind": "festival", "artist_id": artist["artist_id"]})
        vectors.append(artist["vector"])
    if not args.exclude_references:
        for artist in references["artists"]:
            records.append({"id": f"reference:{artist['id']}", "name": artist["name"],
                            "kind": "reference", "artist_id": artist["id"]})
            vectors.append(artist["vector"])

    matrix = np.asarray(vectors, dtype=np.float64)
    if matrix.shape != (len(records), festival["dimensions"]) or not np.isfinite(matrix).all():
        raise ValueError("Invalid embedding dimensions or non-finite values")
    if not np.allclose(np.linalg.norm(matrix, axis=1), 1.0, atol=1e-5):
        raise ValueError("Embeddings must be normalized")
    distances = cosine_distances(matrix)
    distances = (distances + distances.T) / 2
    np.fill_diagonal(distances, 0)
    # Keep EOM extraction; override density parameters only when requested.
    estimator = HDBSCAN(metric="precomputed", algorithm="brute", copy=True,
                        min_cluster_size=args.min_cluster_size, min_samples=args.min_samples,
                        cluster_selection_method="eom")
    labels = estimator.fit_predict(distances)
    for record, label, strength in zip(records, labels, estimator.probabilities_):
        record["cluster_id"] = int(label)
        record["membership_strength"] = float(strength)
    clusters = []
    for label in sorted(set(labels) - {-1}):
        indices = np.flatnonzero(labels == label)
        medoid = indices[np.argmin(distances[np.ix_(indices, indices)].sum(axis=1))]
        clusters.append({"cluster_id": int(label), "size": len(indices),
                         "medoid_id": records[medoid]["id"],
                         "members": [records[index] for index in indices]})

    parameters = estimator.get_params()
    result = {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "method": "HDBSCAN* with Excess of Mass (EOM) cluster extraction",
        "implementation": "sklearn.cluster.HDBSCAN",
        "runtime": {"scikit_learn": sklearn.__version__, "numpy": np.__version__},
        "parameters": parameters,
        "effective_min_samples": parameters["min_samples"] if parameters["min_samples"] is not None else parameters["min_cluster_size"],
        "min_samples_includes_point_itself": True,
        "distance": "cosine distance (1 - cosine similarity), supplied as a full distance matrix",
        "dimensionality_reduction": festival.get("dimensionality_reduction"),
        "model": festival["model"], "prompt": festival["prompt"],
        "prompt_name": festival.get("prompt_name"),
        "dimensions": festival["dimensions"],
        "festival_scope": args.festival_scope,
        "includes_reference_artists": not args.exclude_references,
        "inputs": inputs,
        "excluded_missing_vectors": missing_vectors,
        "artist_count": len(records), "cluster_count": len(clusters),
        "noise_count": int(np.count_nonzero(labels == -1)),
        "membership_strength_description": "HDBSCAN membership strength, not a calibrated probability of musical similarity",
        "clusters": clusters,
        "noise": [record for record in records if record["cluster_id"] == -1],
        "artists": records,
    }
    output = args.output.resolve()
    temporary = output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(output)
    for cluster in clusters:
        print(f"Cluster {cluster['cluster_id']} ({cluster['size']}): "
              + "; ".join(member["name"] for member in cluster["members"]))
    print(f"Noise ({result['noise_count']}): " + "; ".join(member["name"] for member in result["noise"]))
    print(f"Saved {output}")


if __name__ == "__main__":
    main()
