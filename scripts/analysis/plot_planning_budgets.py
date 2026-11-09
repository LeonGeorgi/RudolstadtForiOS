#!/usr/bin/env python3
"""Create standalone research plots from simulate_planning_budgets.py output."""

import argparse
import csv
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("MPLCONFIGDIR", str(ROOT / "artifacts/planner-simulation/.mplconfig"))
os.environ.setdefault("XDG_CACHE_HOME", str(ROOT / "artifacts/planner-simulation/.cache"))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


COLORS = ("#176b9b", "#b35819", "#2d8057", "#8155a5")
NAMES = {"rudolstadt-2026": "Rudolstadt · 310 Konzerte",
         "fantasy-2027": "Testfestival · 500 Konzerte"}


def load(directory):
    with (directory / "results.csv").open() as file:
        rows = list(csv.DictReader(file))
    for row in rows:
        for key in ("budget", "saved_count", "saved_requested"):
            row[key] = int(row[key])
        for key in ("score", "initial_score"):
            row[key] = float(row[key])
        row["reference_score"] = float(row["reference_score"]) if row.get("reference_score") else None
        row["score_index"] = float(row["score_index"]) if row["score_index"] else None
    return [r for r in rows if r["kind"] == "factorial"]


def decorate(axis, budgets):
    axis.set_xscale("log")
    ticks = [b for b in (0, 100, 1000, 10000, 100000, 1000000, 3000000) if b in budgets]
    labels = {0: "Start", 100: "100", 1000: "1 Tsd.", 10000: "10 Tsd.",
              100000: "100 Tsd.", 1000000: "1 Mio.", 3000000: "3 Mio."}
    axis.set_xticks([b + 1 for b in ticks], [labels[b] for b in ticks])
    axis.minorticks_off()
    axis.grid(axis="y", color="#d7dde2", linewidth=.7)
    axis.set_axisbelow(True)
    axis.spines[["top", "right"]].set_visible(False)
    axis.spines[["left", "bottom"]].set_color("#8c969e")
    axis.set_xlabel("Operationsbudget · Kandidatenprüfungen (logarithmische Achse)", labelpad=12)
    axis.margins(x=.025)


def save(figure, directory, name):
    figure.savefig(directory / f"{name}.png", dpi=180, facecolor="white")
    figure.savefig(directory / f"{name}.svg", facecolor="white")
    plt.close(figure)


def plot(directory):
    rows = load(directory)
    budgets = sorted({r["budget"] for r in rows})
    x = [b + 1 for b in budgets]
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 12,
                         "axes.labelsize": 12, "axes.titlesize": 14,
                         "figure.titlesize": 19, "svg.fonttype": "none"})
    figure, axis = plt.subplots(figsize=(11.5, 6.8))
    figure.subplots_adjust(left=.10, right=.97, top=.80, bottom=.23)
    figure.suptitle("Wie viel Score bringt ein größeres Operationsbudget?", y=.97, fontweight="normal")
    figure.text(.10, .875, "Herzen² × √(Dauer / 60)  ·  Ausgangsplan = 100 %", fontsize=12)
    for index, name in enumerate(NAMES):
        group = [r for r in rows if r["dataset"] == name and r["score_index"] is not None]
        samples = [[r["score_index"] for r in group if r["budget"] == b] for b in budgets]
        mean = np.array([np.mean(v) for v in samples])
        low = [np.quantile(v, .25) for v in samples]
        high = [np.quantile(v, .75) for v in samples]
        n = len({r["id"] for r in group})
        axis.fill_between(x, low, high, color=COLORS[index], alpha=.12, linewidth=0)
        axis.plot(x, mean, color=COLORS[index], marker=("o", "s")[index], markersize=4,
                  linewidth=2.3, label=f"{NAMES[name]} · {n} Profile")
    axis.axhline(100, color="#7e8992", linewidth=.8)
    if max(budgets) >= 3000:
        axis.axvline(3001, color="#7e8992", linestyle="--", linewidth=.9)
        axis.text(3001 * 1.12, .04, "Ab hier sind alle\nStartheuristiken abgeschlossen",
                  transform=axis.get_xaxis_transform(), fontsize=10, va="bottom")
    decorate(axis, budgets)
    axis.set_ylabel("Score relativ zum bisherigen Plan (%)", labelpad=12)
    axis.legend(loc="upper left", frameon=False, fontsize=11)
    figure.text(.10, .075, "Linien: Mittelwert der individuellen Score-Indizes. Flächen: mittlere 50 % der Profile.", fontsize=10)
    figure.text(.10, .040, "384 reguläre Szenarien; weitere 16 Stressfälle separat ausgewertet. Eine flache Kurve beweist keine Optimalität.", fontsize=10)
    save(figure, directory, "budget-score-index")

    figure, axis = plt.subplots(figsize=(11.5, 6.8))
    figure.subplots_adjust(left=.10, right=.97, top=.80, bottom=.23)
    figure.suptitle("Operationsbudget und tatsächlich erreichte Planqualität", y=.97)
    figure.text(.10, .875, "Score relativ zum unabhängig nachgewiesenen Optimum · 100 % = optimal", fontsize=12)
    for index, name in enumerate(NAMES):
        group = [r for r in rows if r["dataset"] == name and r["reference_status"] == "optimal"
                 and r["reference_score"] and r["reference_score"] > 0]
        if not group:
            continue
        samples = [[100 * r["score"] * 120 / r["reference_score"] for r in group if r["budget"] == b]
                   for b in budgets]
        mean = [np.mean(v) for v in samples]
        n = len({r["id"] for r in group})
        axis.fill_between(x, [np.quantile(v, .25) for v in samples],
                          [np.quantile(v, .75) for v in samples], color=COLORS[index], alpha=.12, linewidth=0)
        axis.plot(x, mean, color=COLORS[index], marker=("o", "s")[index], markersize=4,
                  linewidth=2.3, label=f"{NAMES[name]} · {n} Profile")
    axis.axhline(100, color="#7e8992", linewidth=.8)
    if max(budgets) >= 3000:
        axis.axvline(3001, color="#7e8992", linestyle="--", linewidth=.9)
        axis.text(3001 * 1.12, .04, "Startheuristiken abgeschlossen;\ndanach nur Branch-and-Bound",
                  transform=axis.get_xaxis_transform(), fontsize=10, va="bottom")
    decorate(axis, budgets)
    axis.set_ylabel("Erreichter Score / optimaler Score (%)", labelpad=12)
    handles, labels = axis.get_legend_handles_labels()
    figure.legend(handles, labels, loc="upper left", bbox_to_anchor=(.09, .845),
                  ncol=2, frameon=False, fontsize=10)
    figure.text(.10, .075, "Linien: Mittelwert. Flächen: mittlere 50 % der Profile. Unbewiesene Referenzen und Leerfälle ausgeschlossen.", fontsize=10)
    figure.text(.10, .040, "384 reguläre Szenarien + 16 separate Stressfälle · gleiche Bewertungen und Speicherstände bei jedem Budget.", fontsize=10)
    save(figure, directory, "budget-score-optimum")

    figure, axes = plt.subplots(1, 2, figsize=(13, 6.6), sharex=True)
    figure.subplots_adjust(left=.07, right=.98, top=.74, bottom=.23, wspace=.25)
    figure.suptitle("Score nach Anzahl gespeicherter Konzerte", y=.97, fontweight="normal")
    figure.text(.07, .865, "Durchschnittlicher Score zusätzlicher Empfehlungen · 48 Profile pro Kurve", fontsize=12)
    for axis, name in zip(axes, NAMES):
        for color, saved in zip(COLORS, (0, 2, 6, 12)):
            group = [r for r in rows if r["dataset"] == name and r["saved_requested"] == saved]
            mean = [np.mean([r["score"] for r in group if r["budget"] == b]) for b in budgets]
            axis.plot(x, mean, color=color, marker="o", markersize=3, linewidth=2,
                      label=f"{saved} gespeichert")
        decorate(axis, budgets)
        axis.set_xticks([b + 1 for b in (0, 1000, 100000, 3000000) if b in budgets],
                        [label for b, label in ((0, "Start"), (1000, "1 Tsd."),
                                               (100000, "100 Tsd."), (3000000, "3 Mio.")) if b in budgets])
        axis.set_xlabel("Operationsbudget (logarithmisch)")
        axis.set_title(NAMES[name], loc="left", pad=14)
        axis.set_ylim(bottom=0)
        axis.set_ylabel("Score (Punkte)")
    handles, labels = axes[0].get_legend_handles_labels()
    figure.legend(handles, labels, loc="upper left", bbox_to_anchor=(.06, .845), ncol=4, frameon=False, fontsize=11)
    figure.text(.07, .075, "Je Kurve: gleiche Verteilung von Bewertungen, Künstleranteilen und Planungszeitpunkten.", fontsize=10)
    figure.text(.07, .040, "Gespeicherte Konzerte sind feste Vorgaben und zählen nicht zum dargestellten Zusatzscore.", fontsize=10)
    save(figure, directory, "budget-score-points")

    figure, axes = plt.subplots(1, 2, figsize=(13, 6.6), sharex=True, sharey=True)
    figure.subplots_adjust(left=.07, right=.98, top=.74, bottom=.23, wspace=.12)
    figure.suptitle("Mehr bewertete Künstler verändern die Schwierigkeit", y=.97)
    figure.text(.07, .865, "Score relativ zum nachgewiesenen Optimum · gleiche Verteilung der Speicherstände", fontsize=12)
    for axis, name in zip(axes, NAMES):
        for color, density in zip(COLORS, (.15, .35, .7, 1.0)):
            group = [r for r in rows if r["dataset"] == name and float(r["density"]) == density
                     and r["reference_status"] == "optimal" and r["reference_score"] and r["reference_score"] > 0]
            mean = [np.mean([100 * r["score"] * 120 / r["reference_score"]
                             for r in group if r["budget"] == b]) for b in budgets]
            axis.plot(x, mean, color=color, marker="o", markersize=3, linewidth=2,
                      label=f"{density:.0%} bewertet")
        decorate(axis, budgets)
        axis.set_xticks([b + 1 for b in (0, 1000, 100000, 3000000) if b in budgets],
                        [label for b, label in ((0, "Start"), (1000, "1 Tsd."),
                                               (100000, "100 Tsd."), (3000000, "3 Mio.")) if b in budgets])
        axis.set_xlabel("Operationsbudget (logarithmisch)")
        axis.set_title(NAMES[name], loc="left", pad=14)
        axis.set_ylabel("Erreichter Score / Optimum (%)")
        axis.axhline(100, color="#7e8992", linewidth=.8)
    handles, labels = axes[0].get_legend_handles_labels()
    figure.legend(handles, labels, loc="upper left", bbox_to_anchor=(.06, .845), ncol=4, frameon=False, fontsize=11)
    figure.text(.07, .075, "Mittelwerte über Bewertungsverteilungen, 0/2/6/12 gespeicherte Konzerte, zwei Planungszeitpunkte und zwei Seeds.", fontsize=10)
    figure.text(.07, .040, "Unbewiesene Referenzen und Leerfälle ausgeschlossen. Stressfälle separat im Bericht.", fontsize=10)
    save(figure, directory, "budget-score-density")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="?", default=ROOT / "artifacts/planner-simulation")
    args = parser.parse_args()
    plot(args.directory)
    environment = {"matplotlib": matplotlib.__version__, "numpy": np.__version__}
    (args.directory / "plot-environment.json").write_text(json.dumps(environment, indent=2) + "\n")


if __name__ == "__main__":
    main()
