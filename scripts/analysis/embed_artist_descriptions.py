#!/usr/bin/env python3
"""Embed the bundled 2026 descriptions for a local artist-similarity experiment.

Run with .venv-analysis/bin/python scripts/analysis/embed_artist_descriptions.py
Install with pip install 'sentence-transformers[image]>=6.1' transformers torch.
The downloaded model is loaded locally; no festival data is uploaded.
"""

import argparse
import hashlib
import json
import platform
from datetime import datetime, timezone
from html import unescape
from html.parser import HTMLParser
from importlib.metadata import version
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "shared/src/commonMain/resources/FestivalBackup/2026_rudolstadt_data.json"
OUTPUT = ROOT / "artifacts/artist-similarity/2026_artist_embeddings.json"
MODEL_ID = "google/embeddinggemma-2"
MODEL_REVISION = "914f7f89142e33e77833254d9c9b90c3cef7303b"
PROMPT = (
    "task: sentence similarity based on musical style, "
    "instrumentation, rhythm and vocals | query: "
)


class DescriptionText(HTMLParser):
    """Preserve all description text, including paragraph and line boundaries."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)

    def handle_starttag(self, tag, attrs):
        if tag in {"br", "p", "div", "li"}:
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in {"p", "div", "li"}:
            self.parts.append("\n")


def plain_description(value):
    parser = DescriptionText()
    parser.feed(value or "")
    parser.close()
    return "\n".join(
        line for raw in "".join(parser.parts).splitlines()
        if (line := " ".join(raw.split()))
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt-name", choices=["Clustering", "SentenceSimilarity"])
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    source_bytes = SOURCE.read_bytes()
    artists = sorted(json.loads(source_bytes)["artists"], key=lambda artist: artist["id"])
    ids = [artist["id"] for artist in artists]
    if len(ids) != len(set(ids)):
        raise ValueError("Source contains duplicate artist IDs")

    records = []
    for artist in artists:
        description = plain_description(artist.get("description_de"))
        language = "de"
        if not description:
            description = plain_description(artist.get("description_en"))
            language = "en"
        records.append({
            "artist_id": artist["id"],
            "name": unescape(artist["name"]),
            "category": artist["category"],
            "hidden_from_artist_list": artist["hide_artist"],
            "status": "embedded" if description else "missing_description",
            "description_language": language if description else None,
            "input_text": description or None,
            "input_sha256": hashlib.sha256(description.encode()).hexdigest() if description else None,
            "input_token_count": None,
            "vector": None,
        })

    cache = Path.home() / ".cache/huggingface/hub"
    model_path = cache / "models--google--embeddinggemma-2/snapshots" / MODEL_REVISION
    torch.set_num_threads(4)
    model = SentenceTransformer(
        str(model_path),
        local_files_only=True,
        device="cpu",
        model_kwargs={"torch_dtype": torch.float32},
        config_kwargs={"vision_config": None, "audio_config": None},
    )
    prompt = model.prompts[args.prompt_name] if args.prompt_name else PROMPT
    prompt_options = {"prompt_name": args.prompt_name} if args.prompt_name else {"prompt": prompt}
    usable = [record for record in records if record["input_text"]]
    for record in usable:
        count = len(model.tokenizer(prompt + record["input_text"])["input_ids"])
        record["input_token_count"] = count
        if count > model.max_seq_length:
            raise ValueError(f"Description would be truncated: {record['artist_id']} ({count} tokens)")

    print(f"Embedding {len(usable)}/{len(records)} artists on CPU; maximum input: "
          f"{max(record['input_token_count'] for record in usable)} tokens", flush=True)
    for start in range(0, len(usable), 4):
        batch = usable[start:start + 4]
        vectors = model.encode(
            [record["input_text"] for record in batch],
            **prompt_options,
            normalize_embeddings=True,
            batch_size=4,
            show_progress_bar=False,
            convert_to_numpy=True,
        )
        if vectors.shape != (len(batch), 768) or not np.isfinite(vectors).all():
            raise ValueError("Model returned invalid vectors")
        if not np.allclose(np.linalg.norm(vectors, axis=1), 1.0, atol=1e-5):
            raise ValueError("Model returned vectors that are not normalized")
        for record, vector in zip(batch, vectors):
            record["vector"] = vector.tolist()
        print(f"Embedded {start + len(batch)}/{len(usable)}", flush=True)

    result = {
        "schema_version": 1,
        "festival_year": 2026,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": {
            "kind": "bundled_festival_backup",
            "path": str(SOURCE.relative_to(ROOT)),
            "sha256": hashlib.sha256(source_bytes).hexdigest(),
        },
        "model": {"id": MODEL_ID, "revision": MODEL_REVISION, "active_modalities": ["text"]},
        "prompt": prompt,
        "prompt_name": args.prompt_name,
        "description_policy": "Full German description; English fallback; HTML removed and entities decoded; no summarization or truncation",
        "dimensions": 768,
        "normalized": True,
        "similarity_metric": "cosine",
        "inference": {"device": "cpu", "dtype": "float32", "batch_size": 4},
        "runtime": {
            "python": platform.python_version(),
            **{package: version(package) for package in ["torch", "transformers", "sentence-transformers", "pillow", "torchvision"]},
        },
        "artist_count": len(records),
        "embedded_count": len(usable),
        "artists": records,
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(output)
    print(f"Saved {output} ({output.stat().st_size:,} bytes)", flush=True)


if __name__ == "__main__":
    main()
