#!/usr/bin/env python3
"""Explore similarity of the small bundled festival artist image URLs.

Run with .venv-analysis/bin/python -B scripts/analysis/embed_artist_images.py.
Use --download-only to separate thumbnail network access from local inference.
Only img_thumb is downloaded; img_full, names and descriptions never enter the model.
Progress with elapsed time and a measured per-phase ETA is printed and saved as JSON.
"""

import argparse
import hashlib
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from urllib.parse import quote, urljoin, urlparse
from urllib.request import Request, urlopen

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "shared/src/commonMain/resources/FestivalBackup/2026_rudolstadt_data.json"
OUTPUT = ROOT / "artifacts/artist-similarity/ImageSimilarity"
CACHE = ROOT / "artifacts/cache/artist-image-similarity"
HOST = "https://www.rudolstadt-festival.de/"
REVISION = "914f7f89142e33e77833254d9c9b90c3cef7303b"
MODEL_ID = "google/embeddinggemma-2"


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(path)


class Progress:
    def __init__(self, phase, total):
        self.phase, self.total, self.started = phase, total, time.monotonic()
        self.update(0)

    def update(self, done, failed=0):
        elapsed = time.monotonic() - self.started
        eta = elapsed / done * (self.total - done) if done else None
        fraction = done / self.total if self.total else 1
        record = {"phase": self.phase, "done": done, "total": self.total,
                  "percent": round(fraction * 100, 1), "failed": failed,
                  "elapsed_seconds": round(elapsed, 1),
                  "estimated_remaining_seconds": round(eta, 1) if eta is not None else None}
        write_json(OUTPUT / "progress.json", record)
        bar = "=" * int(fraction * 24) + " " * (24 - int(fraction * 24))
        remaining = f"ca. {eta:.0f} s" if eta is not None else "wird gemessen"
        print(f"[{bar}] {record['percent']:5.1f}% {self.phase}: {done}/{self.total}"
              f" | vergangen {elapsed:.0f} s | Rest {remaining} | Fehler {failed}", flush=True)


def thumbnail_url(path):
    url = quote(urljoin(HOST, path), safe=":/%?=&")
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "www.rudolstadt-festival.de":
        raise ValueError("Unexpected thumbnail host")
    return url


def download(artist):
    i, url = artist["id"], thumbnail_url(artist["img_thumb"])
    path = CACHE / f"{i}.image"
    try:
        if path.is_file():
            content = path.read_bytes()
        else:
            request = Request(url, headers={"User-Agent": "Rudolstadt-Artist-Image-Experiment/1.0"})
            with urlopen(request, timeout=25) as response:
                if urlparse(response.url).hostname not in {"www.rudolstadt-festival.de", "rudolstadt-festival.de"}:
                    raise ValueError("Unexpected image redirect")
                content = response.read(5_000_001)
            if len(content) > 5_000_000:
                raise ValueError("Thumbnail exceeds 5 MB")
        with Image.open(BytesIO(content)) as image:
            image.load()
            width, height = image.size
        path.write_bytes(content)
        return {"artist_id": i, "name": artist["name"], "url": url,
                "path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(content).hexdigest(),
                "bytes": len(content), "width": width, "height": height, "status": "downloaded"}
    except Exception as error:
        return {"artist_id": i, "name": artist["name"], "url": url,
                "status": "failed", "error": f"{type(error).__name__}: {error}"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-only", action="store_true")
    parser.add_argument("--embed-only", action="store_true")
    parser.add_argument("--retry-failed", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    source_bytes = SOURCE.read_bytes()
    artists = sorted(json.loads(source_bytes)["artists"], key=lambda a: a["id"])
    assert len({a["id"] for a in artists}) == len(artists)
    if args.embed_only:
        saved = json.loads((OUTPUT / "manifest.json").read_text())
        assert saved["source_sha256"] == hashlib.sha256(source_bytes).hexdigest()
        manifest = saved["artists"]
        for artist in manifest:
            if artist["status"] == "downloaded":
                assert hashlib.sha256((ROOT / artist["path"]).read_bytes()).hexdigest() == artist["sha256"]
    else:
        manifest = []
        pending = artists
        if args.retry_failed:
            saved = json.loads((OUTPUT / "manifest.json").read_text())
            assert saved["source_sha256"] == hashlib.sha256(source_bytes).hexdigest()
            manifest = [a for a in saved["artists"] if a["status"] == "downloaded"]
            cached_ids = {a["artist_id"] for a in manifest}
            pending = [a for a in artists if a["id"] not in cached_ids]
        progress = Progress("Fehlende Thumbnails erneut laden" if args.retry_failed else "Thumbnails laden", len(pending))
        completed = 0
        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = [pool.submit(download, a) for a in pending]
            for future in as_completed(futures):
                manifest.append(future.result())
                completed += 1
                if completed % (1 if args.retry_failed else 8) == 0 or completed == len(pending):
                    progress.update(completed, sum(a["status"] == "failed" for a in manifest))
        manifest.sort(key=lambda a: a["artist_id"])
        write_json(OUTPUT / "manifest.json", {
            "source": str(SOURCE.relative_to(ROOT)), "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
            "image_field": "img_thumb", "artists": manifest,
        })
    if args.download_only:
        return

    import numpy as np
    import torch
    from sentence_transformers import SentenceTransformer

    usable = [a for a in manifest if a["status"] == "downloaded"]
    if not usable:
        raise RuntimeError("No thumbnails available; failures recorded in manifest.json")
    torch.set_num_threads(4)
    model_path = (Path.home() / ".cache/huggingface/hub"
                  / "models--google--embeddinggemma-2/snapshots" / REVISION)
    print("Lokales Bildmodell laden; Restzeit der Berechnung wird ab dem ersten Batch gemessen.", flush=True)
    model = SentenceTransformer(str(model_path), local_files_only=True, device="cpu",
                               model_kwargs={"torch_dtype": torch.float32},
                               config_kwargs={"audio_config": None})
    progress = Progress("Bilder einbetten", len(usable))
    vectors = []
    batch_size = 4
    for start in range(0, len(usable), batch_size):
        batch = usable[start:start + batch_size]
        images = []
        for artist in batch:
            with Image.open(ROOT / artist["path"]) as image:
                images.append(image.convert("RGB"))
        matrix = model.encode([{"image": image} for image in images], prompt="",
                              normalize_embeddings=True, batch_size=batch_size,
                              show_progress_bar=False, convert_to_numpy=True).astype(np.float64)
        assert matrix.shape == (len(batch), 768) and np.isfinite(matrix).all()
        assert np.allclose(np.linalg.norm(matrix, axis=1), 1, atol=1e-5)
        matrix /= np.linalg.norm(matrix, axis=1, keepdims=True)
        vectors.extend(matrix)
        progress.update(len(vectors))
        write_json(OUTPUT / "embeddings.partial.json", {
            "model": MODEL_ID, "revision": REVISION, "modality": "image_only", "prompt": "",
            "artists": [{"artist_id": a["artist_id"], "image_sha256": a["sha256"], "vector": v.tolist()}
                        for a, v in zip(usable, vectors)],
        })
    matrix = np.asarray(vectors)
    similarities = np.clip(matrix @ matrix.T, -1, 1)
    catalog = json.loads((ROOT / "shared/src/commonMain/resources/2026_artist_similarities.json").read_text())
    music_matches = catalog["similarArtistIDsByArtistID"]
    result_artists = []
    for i, artist in enumerate(usable):
        order = sorted((j for j in range(len(usable)) if j != i),
                       key=lambda j: (-similarities[i, j], usable[j]["artist_id"]))[:5]
        musical = set(music_matches.get(str(artist["artist_id"]), []))
        result_artists.append({**artist, "neighbors": [
            {"artist_id": usable[j]["artist_id"], "name": usable[j]["name"],
             "cosine": float(similarities[i, j]), "also_music_catalog": usable[j]["artist_id"] in musical}
            for j in order],
            "music_overlap_count": sum(usable[j]["artist_id"] in musical for j in order),
        })
    matches = sum(a["music_overlap_count"] for a in result_artists)
    results = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "model": MODEL_ID, "revision": REVISION, "active_modalities": ["text", "image"],
        "input_modality": "image_only", "prompt": "", "image_field": "img_thumb",
        "dimensions": 768, "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "artist_count": len(usable), "failed": [a for a in manifest if a["status"] != "downloaded"],
        "embedding_seconds": round(time.monotonic() - progress.started, 1),
        "music_overlap": {"matching_directed_neighbors": matches,
                          "total_directed_neighbors": sum(len(a["neighbors"]) for a in result_artists),
                          "catalog_threshold": catalog["minimumSimilarity"]},
        "limitations": ["Exploratory visual similarity, no musical validation.",
                       "Only the small images are used. Artist names and descriptions are display metadata only.",
                       "Musical overlap compares against the full description-based catalog at 0.85, not just the five displayed recommendations.",
                       "Failed images are explicitly excluded; no fallback to full-size images."],
        "artists": result_artists,
    }
    write_json(OUTPUT / "results.json", results)
    (OUTPUT / "embeddings.partial.json").replace(OUTPUT / "embeddings.json")
    progress.update(len(usable))
    print(json.dumps({"artists": len(usable), "failed": len(results["failed"]),
                      "embedding_seconds": results["embedding_seconds"],
                      "music_overlap": results["music_overlap"]}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
