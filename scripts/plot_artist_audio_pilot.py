#!/usr/bin/env python3
"""Plot comparable audio/text cosine matrices from the completed audio pilot."""

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.cluster.hierarchy import leaves_list, linkage
from scipy.spatial.distance import squareform


DIRECTORY = (Path(__file__).resolve().parents[1]
             / "Experiments/ArtistSimilarity/MusicProfilePilot/AudioEmbeddingGemma")


def main():
    results = json.loads((DIRECTORY / "results.json").read_text())
    artists = results["artists"]
    ids = [a["artist_id"] for a in artists]
    index = {artist_id: i for i, artist_id in enumerate(ids)}
    matrices = {}
    for method in ["audio", "de"]:
        matrix = np.eye(len(ids))
        for artist in artists:
            for neighbor in artist["neighbors"][method]:
                matrix[index[artist["artist_id"]], index[neighbor["artist_id"]]] = neighbor["cosine"]
        assert np.allclose(matrix, matrix.T)
        matrices[method] = matrix
    distances = np.clip(1 - matrices["audio"], 0, 2)
    np.fill_diagonal(distances, 0)
    order = leaves_list(linkage(squareform(distances, checks=True), method="average"))
    labels = [artists[i]["name"] for i in order]
    upper = np.triu_indices(len(ids), 1)
    minimum = np.floor(min(matrix[upper].min() for matrix in matrices.values()) * 10) / 10
    figure, axes = plt.subplots(1, 2, figsize=(18, 12), layout="constrained")
    cmap = plt.get_cmap("viridis").copy()
    cmap.set_bad("#eeeeee")
    for axis, method, title in zip(axes, ["audio", "de"], ["Audioausschnitte", "Extrahierte Musikprofile (Deutsch)"]):
        matrix = matrices[method][np.ix_(order, order)]
        matrix = np.ma.array(matrix, mask=np.eye(len(ids), dtype=bool))
        image = axis.imshow(matrix, cmap=cmap, vmin=minimum, vmax=1)
        axis.set_title(title, fontsize=15, pad=14)
        axis.set_xticks(range(len(ids)), labels, rotation=90, fontsize=9)
        axis.set_yticks(range(len(ids)), labels if method == "audio" else [""] * len(ids), fontsize=10)
        axis.tick_params(length=0)
    figure.colorbar(image, ax=axes, shrink=0.55, label="Kosinusähnlichkeit · gemeinsame Farbskala")
    figure.suptitle("Musikalische Ähnlichkeit mit EmbeddingGemma 2", fontsize=20)
    figure.supxlabel("21 Künstler · 24 Aufnahmen × 6 Ausschnitte à 10 Sekunden · Reihenfolge nach Audio gruppiert\n"
                       "Grau: Selbstvergleich · höhere Werte sind keine kalibrierte Empfehlungsschwelle", fontsize=11)
    figure.savefig(DIRECTORY / "audio_vs_music_profiles.png", dpi=160)
    figure.savefig(DIRECTORY / "audio_vs_music_profiles.svg")
    plt.close(figure)


if __name__ == "__main__":
    main()
