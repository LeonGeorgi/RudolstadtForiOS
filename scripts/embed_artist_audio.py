#!/usr/bin/env python3
"""Offline EmbeddingGemma 2 audio pilot using verified YouTube downloads.

Run with .codex-tmp/embeddinggemma-env/bin/python -B scripts/embed_artist_audio.py.
Only waveform samples enter the model. Writes experiment data, never app data.
Resume requires the same frozen protocol and verified source file hashes.
"""

import hashlib
import json
import subprocess
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch
import transformers
from sentence_transformers import SentenceTransformer

from compare_artist_music_profiles import rankings, read_json, review_summary


ROOT = Path(__file__).resolve().parents[1]
PILOT = ROOT / "Experiments/ArtistSimilarity/MusicProfilePilot"
OUTPUT = PILOT / "AudioEmbeddingGemma"
SAMPLE_RATE = 16000
WINDOW_SECONDS = 10
WINDOW_COUNT = 6


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(path)


def normalized(values):
    values = np.asarray(values, dtype=np.float64)
    norms = np.linalg.norm(values, axis=-1, keepdims=True)
    if not np.isfinite(values).all() or np.any(norms <= 1e-12):
        raise ValueError("Invalid or zero embedding")
    return values / norms


def window_starts(duration):
    if duration < WINDOW_SECONDS:
        raise ValueError("Recording is shorter than the fixed window")
    return np.clip(np.linspace(0.1, 0.9, WINDOW_COUNT) * duration - WINDOW_SECONDS / 2,
                   0, duration - WINDOW_SECONDS).tolist()


def decode_window(path, start):
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", str(start), "-i", str(path),
        "-t", str(WINDOW_SECONDS), "-ar", str(SAMPLE_RATE), "-ac", "1",
        "-f", "f32le", "pipe:1",
    ])
    samples = np.frombuffer(raw, dtype="<f4").copy()
    if len(samples) != SAMPLE_RATE * WINDOW_SECONDS or not np.isfinite(samples).all():
        raise ValueError(f"Incomplete or invalid audio window: {path}")
    return samples


def aggregate(recordings, ids, subset=None):
    songs = defaultdict(list)
    for recording in recordings:
        windows = np.asarray(recording["embeddings"], dtype=np.float64)
        if subset is not None:
            windows = windows[subset]
        songs[recording["artist_id"]].append(normalized(windows.mean(axis=0)))
    # Normalize songs first so every recording receives equal weight per artist.
    return np.stack([normalized(np.mean(songs[i], axis=0)) for i in ids])


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    downloads, download_hash = read_json(PILOT / "youtube_audio_downloads.json")
    text_results, results_hash = read_json(PILOT / "results.json")
    text_vectors, vectors_hash = read_json(PILOT / "embeddings.json")
    selected = [r for r in downloads["recordings"] if r["include_in_artist_embedding_pilot"]]
    ids = sorted({r["artist_id"] for r in selected})
    assert len(selected) == 24 and len(ids) == 21
    assert text_results["model"] == text_vectors["model"]
    model_info = {**text_vectors["model"], "active_modalities": ["audio"]}
    model_path = (Path.home() / ".cache/huggingface/hub"
                  / f"models--{model_info['id'].replace('/', '--')}"
                  / "snapshots" / model_info["revision"])
    for recording in selected:
        assert recording["status"] == "verified"
        assert hashlib.sha256((PILOT / recording["path"]).read_bytes()).hexdigest() == recording["sha256"]
    protocol = {
        "schema_version": 1, "model": model_info, "dimensions": 768,
        "device": "cpu", "dtype": "float32", "prompt": "",
        "sample_rate": SAMPLE_RATE, "channels": 1,
        "window_seconds": WINDOW_SECONDS, "windows_per_recording": WINDOW_COUNT,
        "window_centers": "Uniformly spaced from 10% to 90% of recording duration",
        "aggregation": "Normalize window vectors; normalize song mean; normalize equally weighted song mean per artist",
        "source_hashes": {"download_manifest": download_hash, "text_results": results_hash,
                          "text_embeddings": vectors_hash},
        "model_config_sha256": hashlib.sha256((model_path / "config.json").read_bytes()).hexdigest(),
        "artist_ids": ids, "recording_count": len(selected),
        "excluded": [r["path"] for r in downloads["recordings"] if not r["include_in_artist_embedding_pilot"]],
        "evaluation": "Frozen 15 prior description-based judgments; recompute all methods on the same 21 artists",
    }
    protocol_path = OUTPUT / "protocol.json"
    if protocol_path.exists():
        assert read_json(protocol_path)[0] == protocol, "Protocol changed; refusing to reuse embeddings"
    else:
        write_json(protocol_path, protocol)
    protocol_hash = read_json(protocol_path)[1]
    checkpoint_path = OUTPUT / "window_embeddings.json"
    completed = {}
    if checkpoint_path.exists():
        checkpoint, _ = read_json(checkpoint_path)
        assert checkpoint["protocol_sha256"] == protocol_hash
        completed = {r["path"]: r for r in checkpoint["recordings"]}
    pending = [r for r in selected if r["path"] not in completed]
    started = time.monotonic()
    if pending:
        torch.set_num_threads(4)
        model = SentenceTransformer(
            str(model_path), local_files_only=True, device="cpu",
            model_kwargs={"torch_dtype": torch.float32}, config_kwargs={"vision_config": None},
        )
        for recording in pending:
            starts = window_starts(float(recording["metadata"]["format"]["duration"]))
            windows = []
            for start in starts:
                vector = model.encode(
                    [{"audio": decode_window(PILOT / recording["path"], start)}],
                    prompt="", normalize_embeddings=True, convert_to_numpy=True,
                    show_progress_bar=False, batch_size=1,
                    processing_kwargs={"audio": {"sampling_rate": SAMPLE_RATE}},
                )
                assert vector.shape == (1, 768)
                assert np.allclose(np.linalg.norm(vector, axis=1), 1, atol=1e-5)
                windows.append(normalized(vector[0]).tolist())
            completed[recording["path"]] = {
                "artist_id": recording["artist_id"], "artist": recording["artist"],
                "title": recording["title"], "path": recording["path"],
                "sha256": recording["sha256"], "url": recording["url"],
                "window_start_seconds": starts, "embeddings": windows,
            }
            write_json(checkpoint_path, {"protocol_sha256": protocol_hash,
                                       "recordings": list(completed.values())})
            elapsed = time.monotonic() - started
            done = len(completed) - (len(selected) - len(pending))
            print(f"Audio {len(completed)}/{len(selected)}: {recording['artist']} — {recording['title']}"
                  f" | {elapsed:.0f}s elapsed, ~{elapsed / done * (len(pending) - done):.0f}s remaining", flush=True)
        del model

    recordings = [completed[r["path"]] for r in selected]
    audio = aggregate(recordings, ids)
    matrices = {"audio": np.clip(audio @ audio.T, -1, 1)}
    index = {artist_id: i for i, artist_id in enumerate(ids)}
    texts = {a["artist_id"]: a for a in text_vectors["artists"]}
    artists = {a["artist_id"]: a for a in text_results["artists"]}
    for language in ["de", "en"]:
        vectors = normalized([texts[i][language] for i in ids])
        matrices[language] = np.clip(vectors @ vectors.T, -1, 1)
    old = np.eye(len(ids))
    for artist_id in ids:
        for neighbor in artists[artist_id]["neighbors"]["full_description_de"]:
            if neighbor["artist_id"] in index:
                old[index[artist_id], index[neighbor["artist_id"]]] = neighbor["cosine"]
    assert np.allclose(old, old.T)
    matrices["full_description_de"] = old
    ranked = {method: rankings(matrix, ids) for method, matrix in matrices.items()}
    reviewed = []
    for pair in text_results["reviewed_pairs"]:
        a, b = pair["artist_ids"]
        assert a in index and b in index
        reviewed.append({key: pair[key] for key in ["artist_ids", "artists", "judgment", "reason"]} | {
            method: {"cosine": float(matrix[index[a], index[b]]),
                     "ranks": [ranked[method][a].index(b) + 1, ranked[method][b].index(a) + 1]}
            for method, matrix in matrices.items()
        })
    incoming = {method: Counter(j for neighbors in lists.values() for j in neighbors[:5])
                for method, lists in ranked.items()}
    halves = [aggregate(recordings, ids, slice(offset, None, 2)) for offset in [0, 1]]
    half_ranks = [rankings(v @ v.T, ids) for v in halves]
    stability = {
        "method": "Alternating windows: 1/3/5 versus 2/4/6, same recordings",
        "same_top1_count": sum(half_ranks[0][i][0] == half_ranks[1][i][0] for i in ids),
        "top5_mean_shared_count": float(np.mean([
            len(set(half_ranks[0][i][:5]) & set(half_ranks[1][i][:5])) for i in ids])),
        "same_artist_split_cosine_mean": float(np.mean(np.sum(halves[0] * halves[1], axis=1))),
    }
    cross_song = []
    for artist_id in ids:
        songs = [r for r in recordings if r["artist_id"] == artist_id]
        if len(songs) == 2:
            song_vectors = [normalized(np.mean(r["embeddings"], axis=0)) for r in songs]
            cross_song.append({"artist_id": artist_id, "artist": artists[artist_id]["name"],
                               "titles": [r["title"] for r in songs],
                               "cosine": float(song_vectors[0] @ song_vectors[1]),
                               "same_act": artist_id != 196})
    upper = np.triu_indices(len(ids), 1)
    result = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "protocol_sha256": protocol_hash, "model": model_info,
        "runtime": {"torch": torch.__version__, "transformers": transformers.__version__},
        "sample_size": len(ids), "recording_count": len(recordings),
        "window_count": len(recordings) * WINDOW_COUNT, "pair_count": len(ids) * (len(ids) - 1) // 2,
        "threshold": None,
        "limitations": [
            "Small purposive sample; rankings only within these 21 artists.",
            "Prior labels are subjective and description-based, not blinded audio listening judgments.",
            "Usually only one song; mixed live/studio recordings and low-quality compressed sources.",
            "Six excerpts may include speech or applause; no manual or learned speech removal.",
            "The Congos & Culture combines recordings from two bands, not two songs of one act.",
            "General multimodal model; this experiment does not establish music-specific perceptual quality.",
            "Alternating windows measure within-recording stability, not generalization to other songs.",
            "No production threshold calibration or application changes; no post-score parameter tuning.",
        ],
        "review_summary": {method: review_summary(reviewed, method) for method in matrices},
        "hub_summary": {method: {"max_top5_incoming": max(counts.values()),
                                 "artists_at_max": [artists[i]["name"] for i in ids if counts[i] == max(counts.values())],
                                 "cosine_median": float(np.median(matrices[method][upper])),
                                 "cosine_range": [float(matrices[method][upper].min()), float(matrices[method][upper].max())]}
                        for method, counts in incoming.items()},
        "audio_stability": stability, "two_recording_comparison": cross_song,
        "reviewed_pairs": reviewed,
        "artists": [{"artist_id": i, "name": artists[i]["name"],
                     "neighbors": {method: [{"artist_id": j, "name": artists[j]["name"],
                                             "cosine": float(matrix[index[i], index[j]])}
                                            for j in ranked[method][i]] for method, matrix in matrices.items()},
                     "top5_incoming": {method: counts[i] for method, counts in incoming.items()}}
                    for i in ids],
    }
    write_json(OUTPUT / "artist_embeddings.json", {
        "protocol_sha256": protocol_hash, "model": model_info,
        "artists": [{"artist_id": i, "embedding": audio[index[i]].tolist()} for i in ids],
    })
    write_json(OUTPUT / "results.json", result)
    print(json.dumps({"review_summary": result["review_summary"], "hub_summary": result["hub_summary"],
                      "audio_stability": stability, "two_recording_comparison": cross_song}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
