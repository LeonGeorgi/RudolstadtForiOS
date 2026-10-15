#!/usr/bin/env python3
"""Embed the researched reference descriptions and compare with festival vectors.

Run with .codex-tmp/embeddinggemma-env/bin/python scripts/match_reference_artists.py
Uses the same local model, precision, dimensions, and prompt as the festival export.
"""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer

from embed_artist_descriptions import ROOT


DIRECTORY = ROOT / "Experiments/ArtistSimilarity"
DESCRIPTIONS = DIRECTORY / "reference_artist_descriptions.json"
FESTIVAL_VECTORS = DIRECTORY / "2026_artist_embeddings.json"
OUTPUT = DIRECTORY / "reference_artist_matches.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptions", type=Path, default=DESCRIPTIONS)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    descriptions = args.descriptions.resolve()
    output = args.output.resolve()
    reference_bytes = descriptions.read_bytes()
    festival_bytes = FESTIVAL_VECTORS.read_bytes()
    reference_data = json.loads(reference_bytes)
    festival_data = json.loads(festival_bytes)
    references = reference_data["artists"]
    festival_artists = [artist for artist in festival_data["artists"] if artist["vector"] is not None]
    dimensions = festival_data["dimensions"]
    prompt = festival_data["prompt"]
    matrix = np.asarray([artist["vector"] for artist in festival_artists], dtype=np.float64)
    if matrix.shape != (len(festival_artists), dimensions) or not np.isfinite(matrix).all():
        raise ValueError("Festival export contains invalid vectors")
    if not np.allclose(np.linalg.norm(matrix, axis=1), 1.0, atol=1e-5):
        raise ValueError("Festival vectors must be normalized")

    model_info = festival_data["model"]
    model_path = (
        Path.home() / ".cache/huggingface/hub"
        / f"models--{model_info['id'].replace('/', '--')}"
        / "snapshots" / model_info["revision"]
    )
    torch.set_num_threads(4)
    model = SentenceTransformer(
        str(model_path), local_files_only=True, device="cpu",
        model_kwargs={"torch_dtype": torch.float32},
        config_kwargs={"vision_config": None, "audio_config": None},
    )
    for artist in references:
        count = len(model.tokenizer(prompt + artist["description"])["input_ids"])
        artist["input_token_count"] = count
        if count > model.max_seq_length:
            raise ValueError(f"Description would be truncated: {artist['name']}")
    vectors = model.encode(
        [artist["description"] for artist in references],
        prompt=prompt, normalize_embeddings=True, batch_size=4,
        show_progress_bar=False, convert_to_numpy=True,
    )
    if vectors.shape != (len(references), dimensions) or not np.isfinite(vectors).all():
        raise ValueError("Model returned invalid reference vectors")
    if not np.allclose(np.linalg.norm(vectors, axis=1), 1.0, atol=1e-5):
        raise ValueError("Reference vectors are not normalized")

    similarities = vectors.astype(np.float64) @ matrix.T
    all_matches = []
    for row, (artist, vector) in enumerate(zip(references, vectors)):
        artist["vector"] = vector.tolist()
        artist["input_sha256"] = hashlib.sha256(artist["description"].encode()).hexdigest()
        matches = [{
            "reference_id": artist["id"],
            "reference_name": artist["name"],
            "festival_artist_id": candidate["artist_id"],
            "festival_artist_name": candidate["name"],
            "festival_artist_category": candidate["category"],
            "similarity": float(similarities[row, column]),
        } for column, candidate in enumerate(festival_artists)]
        matches.sort(key=lambda match: (-match["similarity"], match["festival_artist_id"]))
        artist["top_20_matches"] = matches[:20]
        all_matches.extend(matches)
        best = matches[0]
        print(f"{artist['name']}: {best['festival_artist_name']} ({best['similarity']:.6f})", flush=True)
    all_matches.sort(key=lambda match: (
        -match["similarity"], match["reference_id"], match["festival_artist_id"]
    ))
    result = {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "festival_year": festival_data["festival_year"],
        "model": model_info,
        "prompt": prompt,
        "dimensions": dimensions,
        "normalized": True,
        "similarity_metric": "cosine",
        "inference": festival_data["inference"],
        "runtime": festival_data["runtime"],
        "reference_description_policy": reference_data["description_policy"],
        "inputs": {
            "reference_descriptions": str(descriptions.relative_to(ROOT)),
            "reference_descriptions_sha256": hashlib.sha256(reference_bytes).hexdigest(),
            "festival_embeddings": str(FESTIVAL_VECTORS.relative_to(ROOT)),
            "festival_embeddings_sha256": hashlib.sha256(festival_bytes).hexdigest(),
        },
        "festival_artist_filter": "All artists with vectors, including street, dance and festival-plus entries",
        "festival_artist_count": len(festival_artists),
        "reference_artist_count": len(references),
        "comparison_count": len(all_matches),
        "artists": references,
        "top_20_matches_overall": all_matches[:20],
        "all_matches": all_matches,
    }
    temporary = output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(output)
    print(f"Saved {output}", flush=True)
    print(json.dumps(result["top_20_matches_overall"], ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
