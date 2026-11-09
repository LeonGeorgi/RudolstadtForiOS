#!/usr/bin/env python3
"""Plot controlled old/new search comparisons on the frozen scenarios."""

import argparse
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("MPLCONFIGDIR", str(ROOT / "artifacts/planner-simulation/.mplconfig"))
os.environ.setdefault("XDG_CACHE_HOME", str(ROOT / "artifacts/planner-simulation/.cache"))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from compare_search_strategies import read_csv
from plot_planning_budgets import decorate, save, NAMES


def plot(directory):
    rows = read_csv(directory / "results.csv")
    baseline = [r for r in rows if r["strategy"] == "baseline"]
    hard = {r["id"] for r in baseline if r["kind"] == "factorial" and r["budget"] == 100000
            and r["reference_status"] == "optimal" and r["reference_score"]
            and r["score"] * 120 / r["reference_score"] < .95}
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 12,
                         "axes.labelsize": 12, "axes.titlesize": 14,
                         "figure.titlesize": 19, "svg.fonttype": "none"})
    budgets = sorted({r["budget"] for r in rows})
    x = [b + 1 for b in budgets]
    for cohort in ("hard", "regular"):
        figure, axes = plt.subplots(1, 2, figsize=(12.5, 6.8), sharey=True)
        figure.subplots_adjust(left=.07, right=.98, top=.74, bottom=.24, wspace=.12)
        title = ("Bessere Pläne auf den bisher schwierigen Profilen" if cohort == "hard"
                 else "Alte und verbesserte Suche auf allen regulären Profilen")
        figure.suptitle(title, y=.97)
        figure.text(.07, .875, "Gleiche Profile, Startpläne, Score-Gewichte und Zählung der Kandidatenprüfungen", fontsize=11)
        for axis, name in zip(axes, NAMES):
            cases = [r for r in rows if r["dataset"] == name and r["kind"] == "factorial"
                     and (cohort == "regular" or r["id"] in hard)
                     and r["reference_status"] == "optimal" and r["reference_score"]]
            n = len({r["id"] for r in cases})
            for strategy, label, color, style in (("baseline", "Bisher", "#7e8992", "--"),
                                                  ("repair", "Verbessert", "#176b9b", "-")):
                data = [r for r in cases if r["strategy"] == strategy]
                samples = [[100 * r["score"] * 120 / r["reference_score"]
                            for r in data if r["budget"] == b] for b in budgets]
                mean = [np.mean(v) for v in samples]
                axis.plot(x, mean, color=color, linestyle=style, marker="o", markersize=3,
                          linewidth=2.2, label=label)
                if strategy == "repair":
                    axis.fill_between(x, [np.quantile(v, .10) for v in samples],
                                      [np.quantile(v, .90) for v in samples],
                                      color=color, alpha=.10, linewidth=0)
            decorate(axis, budgets)
            ticks = [(0, "Start"), (1000, "1 Tsd."), (10000, "10 Tsd."),
                     (100000, "100 Tsd."), (3000000, "3 Mio.")]
            axis.set_xticks([b + 1 for b, _ in ticks if b in budgets],
                            [label for b, label in ticks if b in budgets])
            axis.set_title(f"{NAMES[name]} · {n} Profile", loc="left", fontsize=12, pad=15)
            axis.set_xlabel("Operationsbudget (logarithmisch)")
            axis.axhline(100, color="#9ba4ab", linewidth=.8)
        axes[0].set_ylabel("Score / nachgewiesenes Optimum (%)")
        handles, labels = axes[0].get_legend_handles_labels()
        figure.legend(handles, labels, loc="upper left", bbox_to_anchor=(.06, .84),
                      ncol=2, frameon=False, fontsize=11)
        first = ("Schwierige Profile: alte Suche erreicht bei 100.000 Prüfungen weniger als 95 % des Optimums."
                 if cohort == "hard" else "384 reguläre Profile; unbewiesene Referenzen und Leerfälle ausgeschlossen. 16 Stressfälle separat im Bericht.")
        figure.text(.07, .09, first, fontsize=10)
        figure.text(.07, .055, "Linien: Mittelwert. Blaue Fläche: 10.–90. Perzentil der verbesserten Suche; Referenzlösungen dienen nur der Bewertung.", fontsize=10)
        figure.text(.07, .02, "Verbessert: aktive Bitsets + neue Suchreihenfolge + gültige Planvervollständigung + begrenzte Reparaturheuristik.", fontsize=10)
        save(figure, directory, f"search-comparison-{cohort}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="?", default=ROOT / "artifacts/planner-search-comparison")
    args = parser.parse_args()
    plot(args.directory)


if __name__ == "__main__":
    main()
