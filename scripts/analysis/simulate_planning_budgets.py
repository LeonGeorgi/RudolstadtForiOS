#!/usr/bin/env python3
"""Deterministic operation-budget experiment for the sqrt-duration planner.

Standard-library simulation; optional SciPy/HiGHS provides an independent
reference AFTER searching, never as a seed. See --help and the generated report.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
import math
import platform
import random
import statistics
import time
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

from benchmark_schedule_planner import (
    ROOT, RESOURCES, ZONE, bits, conflict_graph, current_greedy, load_dataset,
    prepare_request, solve, transition_conflict,
)
from compare_duration_weights import UNITS_PER_POINT, weighted_graph


BUDGETS = (0, 10, 30, 100, 300, 1000, 3000, 10000, 30000, 100000,
           300000, 1000000, 3000000)
RATING_MIXES = {"mostly-one": (.65, .25, .10), "balanced": (1, 1, 1),
                "mostly-three": (.10, .25, .65)}
SAVED_COUNTS = (0, 2, 6, 12)
DENSITIES = (.15, .35, .7, 1.0)


@dataclass(frozen=True)
class Scenario:
    id: str
    dataset: str
    kind: str
    density: float
    mix: str
    saved_requested: int
    time: str
    seed: int
    ratings: dict[int, int]
    saved: tuple[int, ...]
    now: float


def profile_seed(*parts):
    return int.from_bytes(hashlib.sha256("|".join(map(str, parts)).encode()).digest()[:8], "big")


def compatible_saves(dataset, ratings, seed, count, mode="mixed", forced=()):
    rng = random.Random(profile_seed(dataset.name, seed, mode, "saves"))
    events = [e for e in dataset.events if e.eligible]
    rng.shuffle(events)
    if mode == "rated":
        events.sort(key=lambda e: -ratings.get(e.artist, 0))
    if mode == "unrated":
        events = [e for e in events if not ratings.get(e.artist, 0)]
    selected = [next(e for e in dataset.events if e.id == id) for id in forced]
    for event in events:
        if len(selected) >= count:
            break
        if any(e.artist == event.artist for e in selected):
            continue
        if all(not transition_conflict(event, other, dataset.transfers) for other in selected):
            selected.append(event)
    return tuple(e.id for e in selected)


def scenarios(dataset, seeds):
    artists = sorted({e.artist for e in dataset.events if e.eligible})
    days = sorted({e.day for e in dataset.events})
    planning_times = {
        "before": min(e.start for e in dataset.events) - 1,
        "middle": datetime.fromisoformat(days[len(days) // 2] + "T12:00:00").replace(tzinfo=ZONE).timestamp(),
    }
    for density, mix, seed in itertools.product(DENSITIES, RATING_MIXES, range(seeds)):
        rng = random.Random(profile_seed(dataset.name, density, mix, seed, "ratings"))
        selected = rng.sample(artists, round(len(artists) * density))
        ratings = dict(zip(selected, rng.choices((1, 2, 3), weights=RATING_MIXES[mix], k=len(selected))))
        # Saved sets are nested at 0/2/6/12 for the SAME ratings and seed.
        saved = compatible_saves(dataset, ratings, seed, max(SAVED_COUNTS),
                                 mode="rated" if seed % 2 == 0 else "mixed")
        for requested, (when, now) in itertools.product(SAVED_COUNTS, planning_times.items()):
            id = f"{dataset.name}/d{density}/{mix}/saved{requested}/{when}/seed{seed}"
            yield Scenario(id, dataset.name, "factorial", density, mix, requested,
                           when, seed, ratings, saved[:requested], now)
    # Explicit awkward cases are reported separately from the balanced grid.
    eligible = [e for e in dataset.events if e.eligible]
    for seed in range(seeds):
        rng = random.Random(profile_seed(dataset.name, seed, "stress"))
        ratings = {a: rng.choice((1, 2, 3)) for a in rng.sample(artists, len(artists) // 2)}
        overlapping = next((a, b) for a, b in itertools.combinations(eligible, 2)
                           if a.artist != b.artist and a.day == b.day
                           and min(a.start + a.duration * 60, b.start + b.duration * 60) > max(a.start, b.start))
        repeated = next((a, b) for a, b in itertools.combinations(eligible, 2)
                        if a.artist == b.artist and not transition_conflict(a, b, dataset.transfers))
        cases = {
            "conflicting-saves": (ratings, tuple(e.id for e in overlapping)),
            "repeat-saved-artist": (ratings, tuple(e.id for e in repeated)),
            "unrated-saves": (ratings, compatible_saves(dataset, ratings, seed, 6, "unrated")),
            "all-three": ({a: 3 for a in artists}, ()),
        }
        for label, (values, saved) in cases.items():
            when = "before" if seed % 2 == 0 else "middle"
            yield Scenario(f"{dataset.name}/stress/{label}/seed{seed}", dataset.name,
                           label, len(values) / len(artists), "stress", len(saved),
                           when, seed, values, saved, planning_times[when])


def milp_reference(graph, seconds):
    if seconds <= 0:
        return {"reference_status": "disabled"}
    import numpy as np
    from scipy.optimize import Bounds, LinearConstraint, milp
    from scipy.sparse import coo_matrix
    if not graph.weights:
        return {"reference_status": "optimal", "reference_score": 0,
                "reference_upper": 0, "reference_ms": 0}
    edges = [(i, j) for i, row in enumerate(graph.adjacent) for j in bits(row) if j < i]
    rows, columns = [], []
    for index, (i, j) in enumerate(edges):
        rows.extend((index, index))
        columns.extend((i, j))
    matrix = coo_matrix((np.ones(len(rows)), (rows, columns)),
                        shape=(len(edges), len(graph.weights))).tocsc()
    started = time.perf_counter()
    result = milp(-np.array(graph.weights, dtype=float),
                  integrality=np.ones(len(graph.weights)), bounds=Bounds(0, 1),
                  constraints=LinearConstraint(matrix, -np.inf, 1),
                  options={"time_limit": seconds, "mip_rel_gap": 0.0})
    chosen = None
    if result.x is not None:
        chosen = sum(1 << i for i, v in enumerate(result.x) if v > .5)
        if not graph.valid(chosen):
            raise AssertionError("Independent reference returned an invalid rounded plan")
    dual = getattr(result, "mip_dual_bound", None)
    return {"reference_status": "optimal" if result.status == 0 else f"status-{result.status}",
            "reference_score": graph.score(chosen) if chosen is not None else None,
            "reference_upper": -float(dual) if dual is not None and math.isfinite(dual) else None,
            "reference_ms": (time.perf_counter() - started) * 1000}


def evaluate(dataset, scenario, adjacency, budgets, reference_seconds):
    events, original = prepare_request(dataset, scenario.ratings, scenario.saved, scenario.now, adjacency)
    initial = current_greedy(events, original, scenario.ratings)
    graph = weighted_graph(events, original.adjacent, scenario.ratings, "sqrt")
    result = solve(graph, initial, seconds=None, operation_limit=max(budgets), checkpoints=budgets)
    previous = graph.score(initial)
    for checkpoint in result.checkpoints:
        assert graph.valid(checkpoint.chosen)
        assert checkpoint.score >= previous
        assert checkpoint.operations <= checkpoint.budget
        selected = [events[i] for i in bits(checkpoint.chosen)]
        assert all(e.start >= scenario.now and e.id not in scenario.saved for e in selected)
        assert len({e.artist for e in selected}) == len(selected)
        assert all(not transition_conflict(e, saved, dataset.transfers)
                   for e in selected for saved in dataset.events
                   if saved.id in scenario.saved and saved.eligible)
        previous = checkpoint.score
    reference = milp_reference(graph, reference_seconds)
    if reference["reference_status"] == "optimal":
        assert result.score <= reference["reference_score"]
        assert result.upper_bound >= reference["reference_score"]
    context = {"id": scenario.id, "dataset": scenario.dataset, "kind": scenario.kind,
               "density": scenario.density, "mix": scenario.mix, "saved_requested": scenario.saved_requested,
               "saved_count": len(scenario.saved), "time": scenario.time, "seed": scenario.seed,
               "rated_artists": len(scenario.ratings), "candidates": len(events),
               "initial_score": graph.score(initial) / UNITS_PER_POINT,
               "warm_start_score": result.warm_start_score / UNITS_PER_POINT,
               "warm_start_operations": result.warm_start_operations,
               "warm_start_completed": result.warm_start_operations > 0 or not events,
               "final_score": result.score / UNITS_PER_POINT,
               **reference}
    rows = []
    for checkpoint in result.checkpoints:
        row = {**context, "budget": checkpoint.budget, "operations": checkpoint.operations,
               "score": checkpoint.score / UNITS_PER_POINT,
               "upper_bound": checkpoint.upper_bound / UNITS_PER_POINT,
               "optimal": checkpoint.optimal, "nodes": checkpoint.nodes,
               "elapsed_ms": checkpoint.elapsed_ms, "phase": checkpoint.phase,
               "chosen_ids": ";".join(str(events[i].id) for i in bits(checkpoint.chosen))}
        if context["initial_score"]:
            row["score_index"] = 100 * row["score"] / context["initial_score"]
        else:
            row["score_index"] = None
        row["best_found_percent"] = 100 * row["score"] / context["final_score"] if context["final_score"] else 100
        rows.append(row)
    replay = {"scenario": asdict(scenario), "candidate_ids": [e.id for e in events],
              "initial_ids": [events[i].id for i in bits(initial)],
              "final_ids": [events[i].id for i in bits(result.chosen)], **context}
    return rows, replay


def write_csv(path, rows):
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows):
    summaries = []
    for dataset in sorted({r["dataset"] for r in rows}):
        for budget in sorted({r["budget"] for r in rows}):
            group = [r for r in rows if r["dataset"] == dataset and r["budget"] == budget and r["kind"] == "factorial"]
            indexed = [r["score_index"] for r in group if r["score_index"] is not None]
            referenced = [r for r in group if r["reference_status"] == "optimal" and r.get("reference_score", 0)]
            summaries.append({"dataset": dataset, "budget": budget, "profiles": len(group),
                              "indexed_profiles": len(indexed), "mean_score": statistics.mean(r["score"] for r in group),
                              "mean_index": statistics.mean(indexed) if indexed else 100,
                              "median_index": statistics.median(indexed) if indexed else 100,
                              "mean_best_found_percent": statistics.mean(r["best_found_percent"] for r in group),
                              "reference_profiles": len(referenced),
                              "mean_optimum_percent": statistics.mean(
                                  100 * r["score"] * UNITS_PER_POINT / r["reference_score"]
                                  for r in referenced) if referenced else None,
                              "reached_reference_optimum": sum(
                                  round(r["score"] * UNITS_PER_POINT) == r["reference_score"]
                                  for r in referenced),
                              "improved": sum(r["score"] > r["initial_score"] for r in group),
                              "optimal": sum(r["optimal"] for r in group),
                              "median_ms": statistics.median(r["elapsed_ms"] for r in group),
                              "p95_ms": sorted(r["elapsed_ms"] for r in group)[math.ceil(.95 * len(group)) - 1]})
    return summaries


def report(rows, replays, metadata, output):
    summary = summarize(rows)
    write_csv(output / "summary.csv", summary)
    lines = ["# Operationsbudget und Planqualität", "",
             f"{len(replays)} Szenarien, {len(rows)} Budget-Messpunkte. Score: Herzen² × √(Dauer / 60), auf 1/120 Punkt gerundet.", "",
             "## Auswertung des balancierten Szenarienrasters", "",
             "| Festival | Budget | Fälle | Ø Score | Ø Index (Start = 100) | Bessere Pläne | Optimal bewiesen | Median / p95 Zeit |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for r in summary:
        lines.append(f"| {r['dataset']} | {r['budget']:,} | {r['profiles']} | {r['mean_score']:.2f} | "
                     f"{r['mean_index']:.2f} | {r['improved']} | {r['optimal']} | "
                     f"{r['median_ms']:.2f} / {r['p95_ms']:.2f} ms |")
    reference_cases = [r for r in replays if r["reference_status"] != "disabled"]
    proved = [r for r in reference_cases if r["reference_status"] == "optimal"]
    if reference_cases:
        lines += ["", "## Unabhängige Referenz", "",
                  f"SciPy/HiGHS wurde nach der Suche auf {len(reference_cases)} Fällen ausgeführt; "
                  f"in {len(proved)} Fällen wurde ein Optimum nachgewiesen. Referenzergebnisse wurden niemals als Startplan verwendet.", "",
                  "Die folgende Qualität ist der Mittelwert individueller Anteile am nachgewiesenen Optimum. Leerfälle mit Optimum 0 und nicht bewiesene Referenzen sind ausgeschlossen.", "",
                  "| Festival | Budget | Referenzfälle | Ø Anteil am Optimum | Optimum erreicht |",
                  "| --- | ---: | ---: | ---: | ---: |"]
        for r in summary:
            if r["mean_optimum_percent"] is not None:
                lines.append(f"| {r['dataset']} | {r['budget']:,} | {r['reference_profiles']} | "
                             f"{r['mean_optimum_percent']:.3f}% | {r['reached_reference_optimum']} |")
    lines += ["", "## Versuchsaufbau und Grenzen", "",
              "- Vollfaktoriell: 2 Programme × 4 Anteile bewerteter Künstler (15/35/70/100 %) × 3 Bewertungsverteilungen × 4 Speicherstände (0/2/6/12) × 2 Planungszeitpunkte × Zufallsseeds. Dazu vier getrennte Stressfälle je Programm/Seed.",
              "- Bewertungsverteilungen für 1/2/3 Herzen: überwiegend 1 Herz (65/25/10 %), ausgeglichen, überwiegend 3 Herzen (10/25/65 %). Bewertungen und gespeicherte Konzerte sind synthetisch, keine echten Nutzerprofile.",
              "- Bei gleichem Programm, Bewertungen und Seed sind gespeicherte Mengen verschachtelt. Gerade Seeds speichern bevorzugt hoch bewertete Künstler, ungerade Seeds mischen auch unbewertete Künstler. Reguläre Speicherstände sind zeitlich/wegen der Transfers kompatibel und enthalten verschiedene Künstler.",
              "- Stressfälle: widersprüchliche gespeicherte Konzerte, mehrfach gespeicherter Künstler, unbewertete gespeicherte Künstler, alle Künstler mit drei Herzen. Diese Fälle werden nicht in die Hauptkurven gemischt.",
              "- Operation = eine Kandidatenprüfung in Startheuristik, Clique-Cover-Schranke oder Verzweigung. Jeder solche Schleifendurchlauf zählt, auch ein bereits ausgeschlossener Kandidat. Die sechs Startheuristiken sind im Budget enthalten. Sortierung, Datenkonvertierung, Konfliktgraph, Initialplan und einzelne Maschineninstruktionen der Bitsets zählen nicht mit. Operationszahlen sind keine CPU-Zyklen.",
              "- Jede Kurve ist EIN deterministischer Suchlauf mit Checkpoints. Größere Budgets setzen dieselbe Suche fort; sie starten weder neu noch mit einer anderen Lösung. Nach bewiesenem Optimum bleibt die Kurve konstant. Der Index ist pro Profil Score / Score des bisherigen Greedy-Plans × 100, danach arithmetisch gemittelt. Profile mit Startscore null werden nur aus dem Index ausgeschlossen; Rohscore-Auswertungen enthalten sie.",
              "- Score umfasst nur zusätzliche Empfehlungen. Gespeicherte Veranstaltungen bleiben unverändert feste Vorgaben. Vorhandene Konflikte zwischen gespeicherten Konzerten werden nicht stillschweigend behoben; neue Empfehlungen dürfen mit keinem davon kollidieren. Gespeicherte Künstler werden nicht zusätzlich empfohlen.",
              "- Die gesamte Festivaldauer wird gemeinsam geplant. Künstlerkonflikte verbinden auch unterschiedliche Tage. Vor oder mitten im Festival zu planen ändert nur den Filter zukünftiger Empfehlungen; gespeicherte vergangene Konzerte bleiben berücksichtigt wie im bestehenden Planer.",
              "- Höchster gefundener Score ist keine Garantie für das globale Optimum. Eine flache Kurve kann eine gute Lösung oder eine Suche ohne weitere Fortschritte bedeuten. B&B-Schranken und unabhängige Referenzstatus stehen in den Rohdaten.",
              "- Alle 310 Rudolstadt-Dauern sind geschätzt, die 500 Dauern des Fantasy-Testfestivals sind explizit hinterlegt. Es handelt sich um einen Modellvergleich, nicht um gemessene Zufriedenheit.",
              "- Laufzeiten sind ergänzende Einzelmessungen auf diesem Rechner; Betriebssystemlast beeinflusst sie. Operationsbudgets und Score-Ergebnisse sind deterministisch. Keine Laufzeitprognose für iOS oder Android.", "",
              "## Reproduktion", "", "```sh",
              f"python3 scripts/analysis/simulate_planning_budgets.py --seeds {metadata['seeds']} --budgets "
              + " ".join(map(str, metadata['budgets'])) + f" --reference-seconds {metadata['reference_seconds']}",
              "```", "", "Rohdaten: results.csv; jedes Profil mit IDs/Bewertungen: profiles.jsonl; Eingabe- und Code-Hashes: environment.json.", ""]
    (output / "report.md").write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=int, default=2)
    parser.add_argument("--budgets", nargs="+", type=int, default=BUDGETS)
    parser.add_argument("--reference-seconds", type=float, default=.1)
    parser.add_argument("--limit", type=int, help="Only for small pilot runs; omit for the full grid")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/planner-simulation")
    args = parser.parse_args()
    if args.seeds <= 0 or min(args.budgets) < 0 or args.reference_seconds < 0:
        parser.error("Invalid seeds, budgets or reference time")
    args.output.mkdir(parents=True, exist_ok=True)
    all_rows, replays, sources = [], [], []
    started = time.perf_counter()
    for name in ("rudolstadt-2026", "fantasy-2027"):
        dataset = load_dataset(name)
        graph_started = time.perf_counter()
        adjacency = conflict_graph(dataset.events, dataset.transfers)
        sources.append({"name": name, "path": str(dataset.source.relative_to(ROOT)),
                        "sha256": hashlib.sha256(dataset.source.read_bytes()).hexdigest(),
                        "graph_ms": (time.perf_counter() - graph_started) * 1000})
        cases = list(scenarios(dataset, args.seeds))
        if args.limit:
            # Evenly sample across density/mix/saves/time, not only the easy prefix.
            cases = [cases[round(i * (len(cases) - 1) / max(1, args.limit - 1))]
                     for i in range(min(args.limit, len(cases)))]
        for index, case in enumerate(cases):
            rows, replay = evaluate(dataset, case, adjacency, tuple(sorted(set(args.budgets))), args.reference_seconds)
            all_rows.extend(rows)
            replays.append(replay)
            if (index + 1) % 10 == 0 or index == len(cases) - 1:
                print(f"{name}: {index + 1}/{len(cases)} scenarios; "
                      f"elapsed {time.perf_counter() - started:.1f}s; "
                      f"last {replay['candidates']} candidates, "
                      f"{replay['initial_score']:.1f}→{replay['final_score']:.1f}", flush=True)
        # Keep completed datasets on disk even if a later run is interrupted.
        write_csv(args.output / "results.csv", all_rows)
        (args.output / "profiles.jsonl").write_text("".join(json.dumps(p) + "\n" for p in replays))
    code_paths = [Path(__file__), Path(__file__).with_name("benchmark_schedule_planner.py"),
                  Path(__file__).with_name("compare_duration_weights.py")]
    metadata = {"python": platform.python_version(), "platform": platform.platform(),
                "seeds": args.seeds, "budgets": sorted(set(args.budgets)),
                "reference_seconds": args.reference_seconds, "pilot_limit": args.limit,
                "elapsed_seconds": time.perf_counter() - started, "sources": sources,
                "source_hashes": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in code_paths},
                "matrix_sha256": hashlib.sha256((RESOURCES / "stage_walk_distances.json").read_bytes()).hexdigest()}
    if args.reference_seconds:
        import scipy
        metadata["scipy_version"] = scipy.__version__
    (args.output / "environment.json").write_text(json.dumps(metadata, indent=2) + "\n")
    report(all_rows, replays, metadata, args.output)


if __name__ == "__main__":
    main()
