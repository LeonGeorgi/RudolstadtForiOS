#!/usr/bin/env python3
"""Plot the existing sklearn HDBSCAN tree with hdbscan's native plot helper.

Use the isolated experiment environment with hdbscan and matplotlib installed.
The fitted hierarchy and labels must match the saved PCA comparison exactly.
"""

import argparse
import hashlib
import json
import textwrap
from importlib.metadata import version

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from hdbscan.plots import CondensedTree
from matplotlib.patches import Ellipse
from sklearn.cluster import HDBSCAN
from sklearn.cluster._hdbscan._tree import _condense_tree
from sklearn.metrics.pairwise import cosine_distances

from analyze_artist_pca import DIRECTORY, ROOT, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dimensions", type=int, default=103)
    args = parser.parse_args()
    analysis_path = DIRECTORY / "artist_pca_analysis.json"
    analysis_bytes = analysis_path.read_bytes()
    analysis = json.loads(analysis_bytes)
    source_bytes = (ROOT / analysis["source_embeddings"]).read_bytes()
    if hashlib.sha256(source_bytes).hexdigest() != analysis["source_embeddings_sha256"]:
        raise ValueError("PCA source embeddings have changed")
    saved = next(run for run in analysis["comparison_runs"] if run["dimensions"] == args.dimensions)
    coordinates = np.asarray([artist["pca_coordinates"] for artist in analysis["artists"]])[:, :args.dimensions]
    distances = cosine_distances(coordinates)
    distances = (distances + distances.T) / 2
    np.fill_diagonal(distances, 0)
    estimator = HDBSCAN(**analysis["clustering_parameters"]).fit(distances)
    if estimator.labels_.tolist() != saved["labels"]:
        raise ValueError("Refitted tree must match the saved artist assignments")
    if not np.allclose(estimator.probabilities_, saved["membership_strengths"]):
        raise ValueError("Refitted membership strengths have changed")

    # Adapt field names only; retain the exact sklearn hierarchy and EOM labels.
    condensed = _condense_tree(estimator._single_linkage_tree_, estimator.min_cluster_size)
    native = np.empty(len(condensed), dtype=[("parent", np.intp), ("child", np.intp),
                                            ("lambda_val", np.float64), ("child_size", np.intp)])
    for target, source in [("parent", "parent"), ("child", "child"),
                           ("lambda_val", "value"), ("child_size", "cluster_size")]:
        native[target] = condensed[source]
    tree = CondensedTree(native, estimator.labels_)
    chosen = tree._select_clusters()
    if len(chosen) != saved["cluster_count"]:
        raise ValueError("Native plot selection must match the saved EOM cluster count")
    groups = []
    for label, node in enumerate(chosen):
        indices = np.flatnonzero(estimator.labels_ == label)
        point_rows = native[np.isin(native["child"], indices) & (native["child_size"] == 1)]
        if point_rows["parent"].min() != node:
            raise ValueError("Native plot labels must match the saved cluster IDs")
        groups.append({"cluster_id": label, "tree_node": int(node), "size": len(indices),
                       "members": [{"artist_id": analysis["artists"][index]["artist_id"],
                                    "name": analysis["artists"][index]["name"]} for index in indices]})

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "svg.fonttype": "none"})
    figure = plt.figure(figsize=(24, 13), facecolor="white")
    axis = figure.add_axes([0.04, 0.12, 0.51, 0.76])
    tree.plot(axis=axis, select_clusters=True, label_clusters=True,
              cmap="viridis", log_size=False, colorbar=True)
    # hdbscan 0.8.44 supplies one-element arrays for short-cluster ellipse
    # heights; current NumPy/Matplotlib require scalar drawing coordinates.
    for patch in axis.patches:
        if isinstance(patch, Ellipse):
            patch.height = float(np.asarray(patch.height).item())
    for annotation in axis.texts:
        annotation.set_position(tuple(float(np.asarray(value).item())
                                      for value in annotation.get_position()))
    axis.set_ylabel("λ = 1 / Mutual-Reachability-Distanz", fontsize=12)
    axis.set_title("Verdichteter Clusterbaum · rote Ellipsen markieren EOM-Cluster", loc="left", fontsize=12)
    figure.axes[1].set_ylabel("Anzahl Künstler im jeweiligen Ast", fontsize=10)
    for text in axis.texts:
        text.set_fontsize(9)
        text.set_bbox({"facecolor": "white", "edgecolor": "none", "alpha": 0.8, "pad": 1})
    midpoint = (len(groups) + 1) // 2
    for column, entries in enumerate([groups[:midpoint], groups[midpoint:]]):
        legend = figure.add_axes([0.59 + column * 0.20, 0.12, 0.19, 0.76])
        legend.axis("off")
        legend.set_title("Künstler je Cluster" if column == 0 else "Fortsetzung", loc="left", fontsize=12)
        blocks = [(group, textwrap.wrap(" · ".join(member["name"] for member in group["members"]), width=48))
                  for group in entries]
        total_lines = sum(len(lines) + 1.7 for _, lines in blocks)
        step = 0.96 / total_lines
        y = 0.97
        for group, lines in blocks:
            legend.text(0, y, f"{group['cluster_id']:02d}  ·  {group['size']} Künstler", fontsize=9,
                        fontweight="bold", va="top", transform=legend.transAxes)
            y -= step * 1.05
            for line in lines:
                legend.text(0, y, line, fontsize=8.3, va="top", transform=legend.transAxes)
                y -= step
            y -= step * 0.65
    figure.text(0.04, 0.955, "Festival-Künstler · HDBSCAN*-Clusterbaum", fontsize=23, fontweight="bold")
    figure.text(0.04, 0.918, f"{args.dimensions} PCA-Komponenten · EOM · Mindestgröße 2 · min_samples 2 · "
                f"{saved['cluster_count']} Cluster · {saved['noise_count']} Noise · 152 Künstler", fontsize=12)
    figure.text(0.04, 0.045, "Von oben nach unten: kleinere Distanzen / höhere Dichte. "
                "Breite und Farbe zeigen die Zahl der verbleibenden Künstler im Ast.", fontsize=11)
    figure.text(0.04, 0.02, "Die horizontalen Positionen dienen der Darstellung des Baums; "
                "sie sind keine musikalische Distanzachse.", fontsize=10, color="#555555")
    prefix = DIRECTORY / f"artist_pca{args.dimensions}_condensed_tree"
    figure.savefig(prefix.with_suffix(".png"), dpi=150, facecolor="white")
    figure.savefig(prefix.with_suffix(".svg"), facecolor="white")
    plt.close(figure)
    write_json(prefix.with_suffix(".json"), {
        "dimensions": args.dimensions, "source_analysis": str(analysis_path.relative_to(ROOT)),
        "source_analysis_sha256": hashlib.sha256(analysis_bytes).hexdigest(),
        "source_embeddings_sha256": analysis["source_embeddings_sha256"],
        "clustering_parameters": analysis["clustering_parameters"],
        "implementation": "sklearn HDBSCAN tree rendered using hdbscan.plots.CondensedTree.plot",
        "plot_runtime": {package: version(package) for package in ["hdbscan", "matplotlib"]},
        "cluster_count": len(groups), "noise_count": saved["noise_count"], "groups": groups,
        "tree": [{"parent": int(row["parent"]), "child": int(row["child"]),
                  "lambda_val": float(row["lambda_val"]), "child_size": int(row["child_size"])} for row in native],
    })
    print(f"Saved {prefix} (.png, .svg, .json); assignments match the saved PCA run")


if __name__ == "__main__":
    main()
