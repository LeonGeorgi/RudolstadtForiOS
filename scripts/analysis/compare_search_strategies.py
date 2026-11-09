#!/usr/bin/env python3
"""Replay frozen planning scenarios to compare budgeted search strategies.

The previous CSV is the baseline, including its independent reference optima.
No reference solution or previous improved solution is ever used as a seed.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import statistics
import time
from pathlib import Path

from benchmark_schedule_planner import ROOT, RESOURCES, conflict_graph, current_greedy, load_dataset, prepare_request, solve, bits
from compare_duration_weights import UNITS_PER_POINT, weighted_graph
from simulate_planning_budgets import write_csv


def read_csv(path):
    def decode(value):
        if value == "":
            return None
        if value in ("True", "False"):
            return value == "True"
        try:
            return json.loads(value)
        except ValueError:
            return value
    with path.open() as file:
        return [{k: v if k == "chosen_ids" else decode(v) for k, v in row.items()}
                for row in csv.DictReader(file)]


def load_frozen(directory):
    profiles = [json.loads(line) for line in (directory / "profiles.jsonl").read_text().splitlines()]
    rows = read_csv(directory / "results.csv")
    return profiles, {(row["id"], row["budget"]): row for row in rows}


def request(dataset, adjacency, profile):
    scenario = profile["scenario"]
    ratings = {int(id): value for id, value in scenario["ratings"].items()}
    events, graph = prepare_request(dataset, ratings, scenario["saved"], scenario["now"], adjacency)
    initial = current_greedy(events, graph, ratings)
    assert [e.id for e in events] == profile["candidate_ids"]
    assert [events[i].id for i in bits(initial)] == profile["initial_ids"]
    return events, weighted_graph(events, graph.adjacent, ratings, "sqrt"), initial


def compare(directory, output, strategies, maximum, verify_count=12, limit=None):
    profiles, baseline = load_frozen(directory)
    metadata = json.loads((directory / "environment.json").read_text())
    if hashlib.sha256((RESOURCES / "stage_walk_distances.json").read_bytes()).hexdigest() != metadata["matrix_sha256"]:
        raise ValueError("Walking matrix changed since the frozen baseline")
    budgets = tuple(b for b in metadata["budgets"] if b <= maximum)
    if not budgets or budgets[-1] != maximum:
        raise ValueError("Maximum must be a checkpoint of the frozen baseline")
    output.mkdir(parents=True, exist_ok=True)
    rows, verification = [], []
    begun = time.perf_counter()
    for name in ("rudolstadt-2026", "fantasy-2027"):
        dataset = load_dataset(name)
        source = next(s for s in metadata["sources"] if s["name"] == name)
        if hashlib.sha256(dataset.source.read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError("Dataset changed since the frozen baseline")
        adjacency = conflict_graph(dataset.events, dataset.transfers)
        cases = [p for p in profiles if p["dataset"] == name]
        if limit:
            cases = [cases[round(i * (len(cases) - 1) / max(1, limit - 1))]
                     for i in range(min(limit, len(cases)))]
        verify_indices = {round(i * (len(cases) - 1) / max(1, verify_count - 1))
                          for i in range(min(verify_count, len(cases)))}
        for index, profile in enumerate(cases):
            events, graph, initial = request(dataset, adjacency, profile)
            if index in verify_indices:
                repeated = solve(graph, initial, seconds=None, operation_limit=maximum,
                                 checkpoints=budgets, strategy="baseline")
                for point in repeated.checkpoints:
                    old = baseline[profile["id"], point.budget]
                    ids = ";".join(str(events[i].id) for i in bits(point.chosen))
                    assert point.score == round(old["score"] * UNITS_PER_POINT)
                    assert ids == (old["chosen_ids"] or "")
                    assert point.operations == old["operations"]
                verification.append(profile["id"])
            for budget in budgets:
                rows.append({**baseline[profile["id"], budget], "strategy": "baseline"})
            for strategy in strategies:
                result = solve(graph, initial, seconds=None, operation_limit=maximum,
                               checkpoints=budgets, strategy=strategy)
                previous = graph.score(initial)
                for point in result.checkpoints:
                    assert graph.valid(point.chosen) and point.score >= previous
                    assert point.operations <= point.budget
                    if profile["reference_status"] == "optimal":
                        assert point.score <= profile["reference_score"] <= point.upper_bound
                    previous = point.score
                    old = baseline[profile["id"], point.budget]
                    rows.append({**old, "strategy": strategy, "operations": point.operations,
                                 "score": point.score / UNITS_PER_POINT,
                                 "upper_bound": point.upper_bound / UNITS_PER_POINT,
                                 "optimal": point.optimal, "nodes": point.nodes,
                                 "elapsed_ms": point.elapsed_ms, "phase": point.phase,
                                 "warm_start_score": result.warm_start_score / UNITS_PER_POINT,
                                 "warm_start_operations": result.warm_start_operations,
                                 "final_score": result.score / UNITS_PER_POINT,
                                 "score_index": 100 * point.score / graph.score(initial) if graph.score(initial) else None,
                                 "best_found_percent": 100 * point.score / result.score if result.score else 100,
                                 "chosen_ids": ";".join(str(events[i].id) for i in bits(point.chosen))})
            if (index + 1) % 20 == 0 or index == len(cases) - 1:
                print(f"{name}: {index + 1}/{len(cases)}, strategies={strategies}, "
                      f"elapsed={time.perf_counter() - begun:.1f}s", flush=True)
        write_csv(output / "results.csv", rows)
    environment = {"baseline_directory": str(directory), "strategies": strategies,
                   "maximum": maximum, "budgets": budgets, "limit": limit,
                   "elapsed_seconds": time.perf_counter() - begun,
                   "baseline_profiles_sha256": hashlib.sha256((directory / "profiles.jsonl").read_bytes()).hexdigest(),
                   "baseline_results_sha256": hashlib.sha256((directory / "results.csv").read_bytes()).hexdigest(),
                   "baseline_replayed_profiles": verification,
                   "code_hashes": {name: hashlib.sha256((Path(__file__).parent / name).read_bytes()).hexdigest()
                                   for name in ("benchmark_schedule_planner.py", "compare_search_strategies.py")}}
    (output / "environment.json").write_text(json.dumps(environment, indent=2) + "\n")
    summarize(rows, output)
    return rows


def summarize(rows, output):
    baseline = {(r["id"], r["budget"]): r for r in rows if r["strategy"] == "baseline"}
    # Hard cases are fixed solely from OLD results, before looking at improvements.
    hard_ids = {r["id"] for r in rows if r["strategy"] == "baseline" and r["kind"] == "factorial"
                and r["budget"] == 100000 and r["reference_status"] == "optimal"
                and r["reference_score"] and r["score"] * UNITS_PER_POINT / r["reference_score"] < .95}
    summaries = []
    for name in ("rudolstadt-2026", "fantasy-2027"):
        for cohort in ("regular", "hard", "seed-1", "stress"):
            for strategy in dict.fromkeys(r["strategy"] for r in rows):
                for budget in sorted({r["budget"] for r in rows}):
                    group = [r for r in rows if r["dataset"] == name and r["strategy"] == strategy
                             and r["budget"] == budget and
                             ((cohort == "regular" and r["kind"] == "factorial") or
                              (cohort == "hard" and r["id"] in hard_ids) or
                              (cohort == "seed-1" and r["seed"] == 1 and r["kind"] == "factorial") or
                              (cohort == "stress" and r["kind"] != "factorial"))]
                    if not group:
                        continue
                    known = [r for r in group if r["reference_status"] == "optimal" and r["reference_score"]]
                    quality = [100 * r["score"] * UNITS_PER_POINT / r["reference_score"] for r in known]
                    summaries.append({"dataset": name, "cohort": cohort, "strategy": strategy,
                                      "budget": budget, "profiles": len(group), "reference_profiles": len(known),
                                      "mean_score": statistics.mean(r["score"] for r in group),
                                      "mean_optimum_percent": statistics.mean(quality) if quality else None,
                                      "min_optimum_percent": min(quality) if quality else None,
                                      "wins": sum(r["score"] > baseline[r["id"], budget]["score"] + 1e-8 for r in group),
                                      "losses": sum(r["score"] < baseline[r["id"], budget]["score"] - 1e-8 for r in group),
                                      "optimal": sum(r["optimal"] for r in group),
                                      "median_ms": statistics.median(r["elapsed_ms"] for r in group)})
    write_csv(output / "summary.csv", summaries)
    regressions = [{"id": r["id"], "dataset": r["dataset"], "kind": r["kind"],
                    "strategy": r["strategy"], "budget": r["budget"],
                    "old_score": baseline[r["id"], r["budget"]]["score"],
                    "new_score": r["score"],
                    "delta": r["score"] - baseline[r["id"], r["budget"]]["score"]}
                   for r in rows if r["strategy"] != "baseline"
                   and r["score"] < baseline[r["id"], r["budget"]]["score"] - 1e-8]
    if regressions:
        write_csv(output / "regressions.csv", regressions)
    lines = ["# Vergleich verbesserter Budgetsuche", "",
             "Gleiche eingefrorene Profile, Startpläne, Quadratwurzel-Gewichte und Operationsdefinition wie im vorigen Experiment. Referenzen dienen ausschließlich der Bewertung.", "",
             "| Festival | Kohorte | Strategie | Budget | Fälle | Ø Anteil am Optimum | Schlechtester Fall | Besser / schlechter als bisher |",
             "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for r in summaries:
        if r["budget"] not in (1000, 10000, 100000, 3000000) or r["cohort"] not in ("regular", "hard"):
            continue
        quality = f"{r['mean_optimum_percent']:.3f}%" if r['mean_optimum_percent'] is not None else "—"
        worst = f"{r['min_optimum_percent']:.3f}%" if r['min_optimum_percent'] is not None else "—"
        lines.append(f"| {r['dataset']} | {r['cohort']} | {r['strategy']} | {r['budget']:,} | "
                     f"{r['profiles']} | {quality} | {worst} | {r['wins']} / {r['losses']} |")
    lines += ["", "## Strategien und faire Zählung", "",
              "- baseline: unveränderte vorherige Suche. Die früheren Scores werden übernommen und repräsentative Profile erneut bis zum maximalen Budget geprüft (IDs, Scores und Operationszahlen).",
              "- active-cover: Bitsets für die verbleibenden Kandidaten; Konfliktcliquen liefern dieselbe Art gültiger Obergrenze. Kleine Gewichte werden im Prefix zuerst abgelegt, damit die umgekehrt durchlaufene Suche hochwertige Konzerte früher verzweigt.",
              "- improved: zusätzlich vervollständigt jeder Suchknoten seinen Teilplan mit einer Greedy-Auswahl auf den verbleibenden Kandidaten. Diese gültigen Gesamtpläne verbessern die untere Schranke früh.",
              "- repair: zusätzlich zwei maximal vollständige Reparaturrunden nach den unveränderten sechs Startheuristiken. Ein ausgelassener Auftritt wird eingesetzt, kompatible bisherige Konzerte bleiben, freie Plätze werden neu gefüllt. Abbruch nach einer Runde ohne Verbesserung. Das ist eine zusätzliche Heuristik zur Verbesserung des Incumbents, kein globaler Optimalitätsnachweis.",
              "- Jede Kandidatenprüfung in Reparatur, Vervollständigung, Schrankenbau und Verzweigung zählt. Auch das erneute Ableiten der Prefix-Schranken aus den Konfliktcliquen zählt pro Kandidat. Sortieren bleibt wie zuvor außerhalb der Zählung. Operationszahlen sind keine CPU-Zyklen; Zeiten werden ergänzend gemessen.",
              "- Die ersten sechs Startheuristiken sind identisch. Jede Strategie erhält ein eigenes vollständiges Budget ab demselben alten Greedy-Plan. Neue Strategien erhalten keine alten B&B-Ergebnisse und keine Referenzlösungen als Startplan.",
              "- hard: reguläre Profile, bei denen die ALTE Suche bei 100.000 Prüfungen weniger als 95 % des bewiesenen Optimums erreicht hat. Die Fallauswahl hängt nicht vom Ergebnis der neuen Strategien ab.",
              "- Vorversuche zu Schrankenbau und Reihenfolge verwendeten dichte Profile beider bisherigen Seeds; der Reparaturvorversuch verwendete Seed 0. Seed 1 wird separat ausgewiesen, ist aber keine vollständig unberührte Holdout-Stichprobe. Verschlechterungen werden ausdrücklich gezählt.",
              "- Optimalitätsanteile schließen unbekannte Referenzoptima und Optimum 0 aus. Gewinner/Verlierer beziehen alle Profile der jeweiligen Kohorte ein. Stressfälle sind von den regulären Profilen getrennt.",
              "- Rohdaten: results.csv. Kohorten, Regresse, Schranken und Zeitmessungen: summary.csv. Code- und Baseline-Hashes sowie nachgespielte Baseline-Fälle: environment.json.", ""]
    if regressions:
        lines += ["## Einzelne Rückschritte", "",
                  "Eine andere Suchreihenfolge garantiert bei einem begrenzten Budget keine Dominanz auf jedem Profil. Diese Rückschritte sind vollständig in regressions.csv erfasst:", "",
                  "| Profil | Strategie | Budget | Alter Score | Neuer Score |",
                  "| --- | --- | ---: | ---: | ---: |"]
        for r in regressions:
            lines.append(f"| {r['id']} | {r['strategy']} | {r['budget']:,} | "
                         f"{r['old_score']:.3f} | {r['new_score']:.3f} |")
        lines += [""]
    (output / "report.md").write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=ROOT / "artifacts/planner-simulation")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/planner-search-comparison")
    parser.add_argument("--strategies", nargs="+", choices=("active-cover", "improved", "repair"), default=("repair",))
    parser.add_argument("--maximum", type=int, default=3000000)
    parser.add_argument("--verify-count", type=int, default=12, help="Baseline replay cases per dataset")
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    compare(args.baseline, args.output, args.strategies, args.maximum, args.verify_count, args.limit)


if __name__ == "__main__":
    main()
