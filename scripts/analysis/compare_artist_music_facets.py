#!/usr/bin/env python3
"""Run the frozen German facet pilot and its additional-artist validation.

Run: .venv-analysis/bin/python -B scripts/analysis/compare_artist_music_facets.py
Uses cached weights offline. Writes only MusicFacetPilot results and embeddings.
"""

import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer

from compare_artist_music_profiles import read_json
from embed_artist_descriptions import plain_description


ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "artifacts/artist-similarity"
PILOT = DIRECTORY / "MusicProfilePilot"
FACET_PILOT = DIRECTORY / "MusicFacetPilot"
METHODS = ["whole_profile", "style_only", "weighted_facets"]


def weighted_score(scores, weights):
    """Unknown style prevents a recommendation; unknown facets add no evidence."""
    if "style" not in scores:
        return None, 0.0
    coverage = sum(weights[facet] for facet in scores)
    return sum(weights[facet] * value for facet, value in scores.items()) / coverage, coverage


def ranked_neighbors(query, candidates, scores):
    return sorted(
        (candidate for candidate in candidates
         if candidate != query and scores.get((query, candidate)) is not None),
        key=lambda candidate: (-scores[query, candidate], candidate),
    )


def evaluate(pairs, candidates, matrices, names):
    ranks = {method: {i: ranked_neighbors(i, candidates, matrix) for i in candidates}
             for method, matrix in matrices.items()}
    records, abstained = [], []
    for pair in pairs:
        a, b = pair["artist_ids"]
        record = {**pair, "artists": [names[a], names[b]]}
        if a not in candidates or b not in candidates:
            abstained.append({**record, "reason_for_abstention": "Missing explicit style evidence"})
            continue
        records.append({**record, **{method: {
            "score": matrix[a, b],
            "ranks": [ranks[method][a].index(b) + 1, ranks[method][b].index(a) + 1],
        } for method, matrix in matrices.items()}})
    summary = {}
    for method in matrices:
        positive = [p for p in records if p["judgment"] == "similar"]
        negative = [p for p in records if p["judgment"] == "different"]
        summary[method] = {
            "similar_pair_count": len(positive), "different_pair_count": len(negative),
            "similar_mean_rank": float(np.mean([r for p in positive for r in p[method]["ranks"]])),
            "similar_directional_top5": sum(r <= 5 for p in positive for r in p[method]["ranks"]),
            "different_directional_top5": sum(r <= 5 for p in negative for r in p[method]["ranks"]),
            "reviewed_score_auc": float(np.mean([
                float(p[method]["score"] > n[method]["score"])
                + 0.5 * float(p[method]["score"] == n[method]["score"])
                for p in positive for n in negative
            ])),
        }
    return {"candidate_count": len(candidates), "summary": summary,
            "pairs": records, "abstained_pairs": abstained,
            "top5": {method: {str(i): [{"artist_id": j, "name": names[j],
                                       "score": matrices[method][i, j]}
                                      for j in ranks[method][i][:5]] for i in candidates}
                     for method in matrices}}


def main():
    protocol, protocol_hash = read_json(FACET_PILOT / "protocol.json")
    original, original_hash = read_json(PILOT / "profiles.json")
    additional, additional_hash = read_json(FACET_PILOT / "validation_profiles.json")
    previous_vectors, _ = read_json(PILOT / "embeddings.json")
    baseline, baseline_hash = read_json(DIRECTORY / "artist_sentence_similarity_scores.json")
    backup, backup_hash = read_json(ROOT / original["source"])
    source, source_hash = read_json(ROOT / baseline["source_embeddings"])
    assert source_hash == baseline["source_embeddings_sha256"]
    assert original_hash == previous_vectors["source_hashes"]["profiles"]
    assert backup_hash == source["source"]["sha256"] == previous_vectors["source_hashes"]["backup"]
    assert protocol["methods"] == METHODS and protocol["language"] == "de"
    weights = protocol["weights"]
    assert np.isclose(sum(weights.values()), 1) and all(v > 0 for v in weights.values())
    assert weights["style"] > 0.5
    artists = original["artists"] + additional["artists"]
    names = {a["artist_id"]: a["name"] for a in artists}
    assert len(names) == len(artists)
    originals = {a["artist_id"] for a in original["artists"]}
    new_ids = {a["artist_id"] for a in additional["artists"]}
    by_id = {a["id"]: a for a in backup["artists"]}
    texts = {}
    for artist in artists:
        i = artist["artist_id"]
        assert by_id[i]["name"] == artist["name"]
        description = " ".join(plain_description(by_id[i]["description_de"]).split())
        for fact in artist["facts"]:
            assert " ".join(fact["evidence"].split()) in description, (artist["name"], fact)
        if artist["facts"]:
            texts[i, "whole_profile"] = " ".join(f["text"] for f in artist["facts"])
        for facet in weights:
            facts = [f["text"] for f in artist["facts"] if f["facet"] == facet]
            if facts:
                texts[i, facet] = " ".join(facts)
    usable = [i for i in names if (i, "whole_profile") in texts]
    common = [i for i in usable if (i, "style") in texts]
    assert len(usable) == 34 and len(common) == 33
    pairs_to_validate = protocol["validation_pairs"]
    assert all(new_ids.intersection(p["artist_ids"]) for p in pairs_to_validate)
    assert len({tuple(sorted(p["artist_ids"])) for p in pairs_to_validate}) == len(pairs_to_validate)
    vectors = {(a["artist_id"], "whole_profile"): np.asarray(a["de"], dtype=np.float64)
               for a in previous_vectors["artists"]}
    model_info = source["model"]
    model_path = (Path.home() / ".cache/huggingface/hub"
                  / f"models--{model_info['id'].replace('/', '--')}"
                  / "snapshots" / model_info["revision"])
    torch.set_num_threads(4)
    model = SentenceTransformer(str(model_path), local_files_only=True, device="cpu",
                               model_kwargs={"torch_dtype": torch.float32},
                               config_kwargs={"vision_config": None, "audio_config": None})
    assert model_info == previous_vectors["model"]
    assert model.prompts["SentenceSimilarity"] == source["prompt"] == previous_vectors["prompt"]
    missing = [key for key in texts if key not in vectors]
    assert all(len(model.tokenizer(source["prompt"] + texts[key])["input_ids"])
               <= model.max_seq_length for key in missing)
    print(f"Embedding {len(missing)} additional whole profiles and documented facets", flush=True)
    encoded = model.encode([texts[key] for key in missing], prompt_name="SentenceSimilarity",
                           batch_size=4, normalize_embeddings=True,
                           show_progress_bar=False, convert_to_numpy=True).astype(np.float64)
    for key, vector in zip(missing, encoded):
        vectors[key] = vector
    for vector in vectors.values():
        assert vector.shape == (768,) and np.isfinite(vector).all()
        assert np.isclose(np.linalg.norm(vector), 1, atol=1e-5)
        vector /= np.linalg.norm(vector)
    matrices = {method: {} for method in METHODS}
    facet_records = []
    for a in usable:
        for b in usable:
            if a == b:
                continue
            full = float(np.clip(vectors[a, "whole_profile"] @ vectors[b, "whole_profile"], -1, 1))
            shared = {facet: float(np.clip(vectors[a, facet] @ vectors[b, facet], -1, 1))
                      for facet in weights if (a, facet) in vectors and (b, facet) in vectors}
            weighted, coverage = weighted_score(shared, weights)
            matrices["whole_profile"][a, b] = full
            matrices["style_only"][a, b] = shared.get("style")
            matrices["weighted_facets"][a, b] = weighted
            if a < b:
                facet_records.append({"artist_ids": [a, b], "whole_profile": full,
                                      "facets": shared, "weighted_facets": weighted,
                                      "shared_weight": coverage})
    pilot_pairs = [{"artist_ids": p["artist_ids"], "judgment": p["judgment"], "reason": p["reason"]}
                   for p in baseline["reviewed_pairs"] if set(p["artist_ids"]) <= originals]
    pair_keys = {tuple(sorted(p["artist_ids"])) for p in pilot_pairs}
    pilot_pairs += [p for p in protocol["pilot_diagnostics"]
                    if tuple(sorted(p["artist_ids"])) not in pair_keys]
    pilot_common = [i for i in common if i in originals]
    result = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "source_hashes": {"protocol": protocol_hash, "original_profiles": original_hash,
                          "validation_profiles": additional_hash, "backup": backup_hash,
                          "baseline_scores": baseline_hash},
        "model": model_info, "prompt": source["prompt"], "weights": weights,
        "threshold": None, "usable_artist_count": len(usable), "common_candidate_count": len(common),
        "facet_coverage": {facet: sum((i, facet) in vectors for i in usable) for facet in weights},
        "excluded": [{"artist_id": i, "name": names[i],
                      "reason": "No explicit style" if i in usable else "No usable musical profile"}
                     for i in names if i not in common],
        "pilot": evaluate(pilot_pairs, pilot_common, matrices, names),
        "validation": evaluate(pairs_to_validate, common, matrices, names),
        "pairs": facet_records,
        "limitations": [
            "Purposive small sample and subjective assistant text judgments; no audio, independent listener or blinded validation.",
            "Validation artists were not in the first pilot, but the extractor knows prior festival reviews.",
            "All variants are evaluated on identical candidates with documented style; abstentions are reported separately.",
            "Evidence quotations are checked for source presence, not automatically for semantic entailment.",
            "Style fields can contain instrument/arrangement information; generic vocabulary can still dominate embeddings.",
            "Pair-dependent availability re-normalizes facet weights and changes evidence coverage.",
            "No threshold, weight tuning, full-festival export or production behavior change.",
        ],
    }
    (FACET_PILOT / "results.json").write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    (FACET_PILOT / "embeddings.json").write_text(json.dumps({
        "model": model_info, "prompt": source["prompt"], "source_hashes": result["source_hashes"],
        "items": [{"artist_id": i, "facet": facet, "text": texts[i, facet], "vector": vector.tolist()}
                  for (i, facet), vector in vectors.items()],
    }, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    print(json.dumps({"coverage": result["facet_coverage"], "excluded": result["excluded"],
                      "pilot": result["pilot"]["summary"],
                      "validation": result["validation"]["summary"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
