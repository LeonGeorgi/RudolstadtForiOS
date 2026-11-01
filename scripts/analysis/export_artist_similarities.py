"""Export the saved SentenceSimilarity scores as a compact, offline app resource."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/artist-similarity/artist_sentence_similarity_scores.json"
EMBEDDINGS = ROOT / "artifacts/artist-similarity/2026_artist_sentence_similarity_embeddings.json"


def ranked_artist_ids(pairs, threshold):
    matches = {}
    for pair in pairs:
        score = pair["cosine_similarity"]
        if score < threshold:
            continue
        first, second = pair["artist_a_id"], pair["artist_b_id"]
        matches.setdefault(first, []).append((second, score))
        matches.setdefault(second, []).append((first, score))
    return {
        str(artist_id): [candidate_id for candidate_id, _ in sorted(
            matches[artist_id], key=lambda match: (-match[1], match[0])
        )]
        for artist_id in sorted(matches)
    }


def main():
    source_bytes = SOURCE.read_bytes()
    scores = json.loads(source_bytes)
    embedding_bytes = EMBEDDINGS.read_bytes()
    embeddings = json.loads(embedding_bytes)
    assert hashlib.sha256(embedding_bytes).hexdigest() == scores["source_embeddings_sha256"]
    assert scores["prompt_name"] == "SentenceSimilarity"
    threshold = scores["threshold_policy"]["recommendation_filter_threshold"]
    year = embeddings["festival_year"]
    result = {
        "festivalYear": year,
        "minimumSimilarity": threshold,
        "provenance": {
            "model": scores["model"],
            "promptName": scores["prompt_name"],
            "sourceScoresSHA256": hashlib.sha256(source_bytes).hexdigest(),
            "thresholdStatus": "Provisional description-based recommendation filter",
        },
        "similarArtistIDsByArtistID": ranked_artist_ids(scores["pairs"], threshold),
    }
    output = ROOT / f"shared/src/commonMain/resources/{year}_artist_similarities.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Saved ranked matches for {len(result['similarArtistIDsByArtistID'])} artists at {threshold} to {output}")


if __name__ == "__main__":
    main()
