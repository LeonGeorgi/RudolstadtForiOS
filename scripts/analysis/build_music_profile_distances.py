#!/usr/bin/env python3
"""Build a music-focused distance from affinities to fixed musical anchors.

This exploratory profile is inferred from existing text embeddings. It does not
replace audio analysis or validation against listener judgments.
"""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import euclidean_distances


ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "artifacts/artist-similarity"


def main():
    source_path = DIRECTORY / "2026_artist_embeddings.json"
    anchors_path = DIRECTORY / "music_distance_anchors.json"
    source_bytes, anchor_bytes = source_path.read_bytes(), anchors_path.read_bytes()
    source, specification = json.loads(source_bytes), json.loads(anchor_bytes)
    artists = [artist for artist in source["artists"] if artist["vector"] is not None]
    matrix = np.asarray([artist["vector"] for artist in artists], dtype=np.float64)
    matrix /= np.linalg.norm(matrix, axis=1, keepdims=True)
    anchors = [dict(anchor, group=group["id"]) for group in specification["groups"]
               for anchor in group["anchors"]]
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
    for anchor in anchors:
        count = len(model.tokenizer(source["prompt"] + anchor["description"])["input_ids"])
        if count > model.max_seq_length:
            raise ValueError(f"Anchor would be truncated: {anchor['id']}")
    vectors = model.encode(
        [anchor["description"] for anchor in anchors], prompt=source["prompt"],
        normalize_embeddings=True, batch_size=4, show_progress_bar=False,
        convert_to_numpy=True,
    ).astype(np.float64)
    vectors /= np.linalg.norm(vectors, axis=1, keepdims=True)
    affinities = matrix @ vectors.T
    profiles = np.empty_like(affinities)
    weighted_profiles = np.empty_like(affinities)
    for group in specification["groups"]:
        indices = [i for i, anchor in enumerate(anchors) if anchor["group"] == group["id"]]
        values = affinities[:, indices]
        # Compare relative musical tendencies rather than uniformly high scores.
        profiles[:, indices] = values - values.mean(axis=1, keepdims=True)
        # RMS within each facet makes its weight independent of anchor count.
        weighted_profiles[:, indices] = profiles[:, indices] * np.sqrt(group["weight"] / len(indices))
    distances = euclidean_distances(weighted_profiles)
    np.fill_diagonal(distances, 0)
    if not np.isfinite(distances).all() or np.any(distances < 0):
        raise ValueError("Invalid musical profile distances")
    records = []
    for row, artist in enumerate(artists):
        records.append({
            "id": f"festival:{artist['artist_id']}", "name": artist["name"],
            "profile": profiles[row].tolist(),
            "anchor_affinities": affinities[row].tolist(),
        })
    result = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "method": "Weighted Euclidean distance between relative musical anchor affinity profiles",
        "formula": "r[a,g,k] = cosine(artist[a], anchor[g,k]) - mean_k cosine(artist[a], anchor[g,k]); d(a,b) = sqrt(sum_g w[g] * mean_k (r[a,g,k] - r[b,g,k])**2)",
        "profile_dimensions": len(anchors),
        "dimensionality_reduction": "Projection onto fixed musical anchor directions; no PCA or UMAP",
        "model": model_info, "prompt": source["prompt"],
        "source_embeddings": str(source_path.relative_to(ROOT)),
        "source_embeddings_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "anchor_specification": str(anchors_path.relative_to(ROOT)),
        "anchor_specification_sha256": hashlib.sha256(anchor_bytes).hexdigest(),
        "weight_policy": specification["weight_policy"],
        "limitations": [
            "Musical affinities are model-derived scores, not genre probabilities.",
            "The profile remains based on complete description embeddings; biography and writing style can still influence it.",
            "Missing musical information cannot be recovered reliably from the embedding.",
            "This distance has not been validated against listener judgments; clusters are exploratory.",
        ],
        "groups": [{"id": group["id"], "weight": group["weight"]}
                   for group in specification["groups"]],
        "anchors": [dict(anchor, vector=vector.tolist()) for anchor, vector in zip(anchors, vectors)],
        "artists": records, "distances": distances.tolist(),
    }
    output = DIRECTORY / "artist_music_profile_distances.json"
    temporary = output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(output)
    print(f"Saved {len(artists)} musical profiles with {len(anchors)} anchors: {output}")


if __name__ == "__main__":
    main()
