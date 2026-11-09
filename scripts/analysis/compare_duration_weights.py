#!/usr/bin/env python3
"""Compare duration objectives on the existing offline planning prototype.

No app changes or extra dependencies. All models equal rating² at 60 minutes.
Run: python3 scripts/analysis/compare_duration_weights.py
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import platform
import statistics
from dataclasses import asdict
from pathlib import Path

from benchmark_schedule_planner import (
    ROOT, Graph, Event, Transfer, bits, conflict_graph, current_greedy,
    load_dataset, prepare_request, profiles, solve,
)


MODELS = ("artist-only", "linear", "sqrt", "half-base-half-linear")
UNITS_PER_POINT = 120
FORMULAS = {
    "artist-only": "rating²",
    "linear": "rating² × minutes / 60",
    "sqrt": "rating² × sqrt(minutes / 60)",
    "half-base-half-linear": "rating² × (0.5 + 0.5 × minutes / 60)",
}


def event_weight(event, rating, model):
    """Integer weights keep bounds exact; sqrt is rounded to 1/120 point."""
    if model not in MODELS:
        raise ValueError(f"Unknown duration model: {model}")
    if rating not in (1, 2, 3) or event.duration is None or event.duration <= 0:
        raise ValueError("Expected positive rating 1–3 and resolved positive duration")
    square, minutes = rating ** 2, event.duration
    if model == "artist-only":
        return 120 * square
    if model == "linear":
        return 2 * square * minutes
    if model == "sqrt":
        return round(120 * square * math.sqrt(minutes / 60))
    return square * (60 + minutes)


def weighted_graph(events, adjacency, ratings, model):
    return Graph(adjacency, tuple(event_weight(e, ratings[e.artist], model) for e in events))


def plan_metrics(events, chosen, ratings):
    selected = [events[i] for i in bits(chosen)]
    result = {"concerts": len(selected), "music_minutes": sum(e.duration for e in selected)}
    for rating in (1, 2, 3):
        matching = [e for e in selected if ratings[e.artist] == rating]
        result[f"r{rating}_concerts"] = len(matching)
        result[f"r{rating}_minutes"] = sum(e.duration for e in matching)
    result["mean_duration"] = result["music_minutes"] / len(selected) if selected else 0
    return result


def miniature_example():
    # Same artist has a mini and a full concert; three 1-heart acts fill the
    # remainder with a two-minute buffer between concerts on the same stage.
    events = [Event(1, 1, "1", 18 * 3600, "2026-07-03", 1080, 15),
              Event(2, 1, "1", 18 * 3600, "2026-07-03", 1080, 90)]
    for id, minute in ((3, 1097), (4, 1119), (5, 1141)):
        events.append(Event(id, id, "1", minute * 60, "2026-07-03", minute, 20))
    ratings = {1: 3, 3: 1, 4: 1, 5: 1}
    adjacency = conflict_graph(events, {("1", "1"): Transfer(0, 0, "sameStage")})
    results = []
    for model in MODELS:
        graph = weighted_graph(events, adjacency, ratings, model)
        result = solve(graph, seconds=None)
        results.append({"model": model, "chosen_ids": [events[i].id for i in bits(result.chosen)],
                        "score": result.score / UNITS_PER_POINT,
                        "full_favorite_score": graph.weights[1] / UNITS_PER_POINT,
                        "mini_and_fillers_score": graph.score(0b11101) / UNITS_PER_POINT,
                        "optimal": result.optimal})
    return results


def compare(datasets, seeds, budget, output):
    output.mkdir(parents=True, exist_ok=True)
    rows, details, metadata = [], [], []
    for dataset in datasets:
        adjacency = conflict_graph(dataset.events, dataset.transfers)
        metadata.append({"name": dataset.name, "events": len(dataset.events),
                         "source": str(dataset.source.relative_to(ROOT)),
                         "source_sha256": hashlib.sha256(dataset.source.read_bytes()).hexdigest(),
                         "estimated_durations": sum(e.duration is None for e in dataset.raw_events)})
        for label, seed, ratings, saved, now in profiles(dataset, seeds):
            events, baseline_graph = prepare_request(dataset, ratings, saved, now, adjacency)
            initial = current_greedy(events, baseline_graph, ratings)
            graphs = {model: weighted_graph(events, baseline_graph.adjacent, ratings, model)
                      for model in MODELS}
            # Search each objective independently, then share feasible solutions
            # as incumbents. This reduces search-order effects when comparing
            # different objectives; no objective loses to the common first pool.
            first = {model: solve(graph, initial, budget) for model, graph in graphs.items()}
            pool = [initial, *(result.chosen for result in first.values())]
            final = {}
            for model, graph in graphs.items():
                incumbent = max(pool, key=graph.score)
                final[model] = solve(graph, incumbent, budget)
            baseline = final["artist-only"].chosen
            baseline_metrics = plan_metrics(events, baseline, ratings)
            baseline_by_artist = {events[i].artist: events[i] for i in bits(baseline)}
            for model, result in final.items():
                graph = graphs[model]
                assert graph.valid(result.chosen)
                assert result.score >= max(map(graph.score, pool))
                metrics = plan_metrics(events, result.chosen, ratings)
                paired_swaps = [events[i].duration - baseline_by_artist[events[i].artist].duration
                                for i in bits(result.chosen)
                                if events[i].artist in baseline_by_artist
                                and events[i].id != baseline_by_artist[events[i].artist].id]
                row = {"dataset": dataset.name, "profile": label, "seed": seed, "model": model,
                       "candidates": len(events), **metrics,
                       "delta_r3_minutes": metrics["r3_minutes"] - baseline_metrics["r3_minutes"],
                       "delta_r3_concerts": metrics["r3_concerts"] - baseline_metrics["r3_concerts"],
                       "delta_r1_minutes": metrics["r1_minutes"] - baseline_metrics["r1_minutes"],
                       "changed_selection": result.chosen != baseline,
                       "longer_repeat_choices": sum(delta > 0 for delta in paired_swaps),
                       "shorter_repeat_choices": sum(delta < 0 for delta in paired_swaps),
                       "score": result.score / UNITS_PER_POINT,
                       "upper_bound": result.upper_bound / UNITS_PER_POINT,
                       "optimal": result.optimal,
                       "gap_percent": 100 * (result.upper_bound - result.score) / result.upper_bound
                                      if result.upper_bound else 0,
                       "search_ms": first[model].elapsed_ms + result.elapsed_ms}
                rows.append(row)
                details.append({**row, "ratings": ratings, "saved": saved, "now": now,
                                "events": [asdict(events[i]) for i in bits(result.chosen)],
                                "baseline_ids": [events[i].id for i in bits(baseline)]})
            linear = rows[-3]
            print(f"{dataset.name:16} {label:17} seed={seed} n={len(events):3} "
                  f"linear: favorite minutes {baseline_metrics['r3_minutes']}→{linear['r3_minutes']}; "
                  f"favorite artists {baseline_metrics['r3_concerts']}→{linear['r3_concerts']}", flush=True)
    environment = {"python": platform.python_version(), "platform": platform.platform(),
                   "seeds": seeds, "budget_seconds_per_pass": budget, "passes": 2,
                   "models": FORMULAS, "units_per_point": UNITS_PER_POINT,
                   "datasets": metadata,
                   "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   "planner_sha256": hashlib.sha256((Path(__file__).parent / "benchmark_schedule_planner.py").read_bytes()).hexdigest()}
    with (output / "results.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    (output / "details.json").write_text(json.dumps(
        {"environment": environment, "miniature": miniature_example(), "runs": details}, indent=2) + "\n")
    write_report(rows, environment, output)
    return rows


def write_report(rows, environment, output):
    lines = ["# Duration weighting experiment", "",
             "All four objectives equal rating² at 60 minutes. This changes what a good plan means; scores across objectives are not a common quality scale.", "",
             "| Objective | Formula | Full favorite: 90 min | Mini favorite: 15 min + three 20-min 1-heart acts | Choice |",
             "| --- | --- | ---: | ---: | --- |"]
    for result in miniature_example():
        lines.append(f"| {result['model']} | {FORMULAS[result['model']]} | "
                     f"{result['full_favorite_score']:.3f} | {result['mini_and_fillers_score']:.3f} | "
                     f"{'full favorite' if result['chosen_ids'] == [2] else 'mini + fillers'} |")
    lines += ["", "## Paired festival profiles", "",
              "Minutes count additional recommendations only; fixed saved events are identical across objectives.", "",
              "| Dataset | Objective | Cases | Plans changed | Mean favorite minutes | Change vs artist-only | Change in favorite artist count | Change in 1-heart minutes | Proven optimal |",
              "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for dataset in environment["datasets"]:
        for model in MODELS:
            group = [r for r in rows if r["dataset"] == dataset["name"] and r["model"] == model]
            mean = lambda key: statistics.mean(r[key] for r in group)
            lines.append(f"| {dataset['name']} | {model} | {len(group)} | "
                         f"{sum(r['changed_selection'] for r in group)} | {mean('r3_minutes'):.1f} | "
                         f"{mean('delta_r3_minutes'):+.1f} | {mean('delta_r3_concerts'):+.2f} | "
                         f"{mean('delta_r1_minutes'):+.1f} | {sum(r['optimal'] for r in group)} |")
    lines += ["", "## Interpretation and limits", "",
              "- Linear weighting values each minute by rating²: 9 units per minute at three hearts, 4 at two hearts and 1 at one heart. A 60-minute favorite is worth as much as 540 minutes of 1-heart concerts; this is a utility comparison, not a claim that both plans fit the same time window.",
              "- Longer concerts of the same artist get more weight. The one-appearance-per-artist constraint, fixed saves, future filter, transfers and arrival buffers stay unchanged.",
              "- Linear utility has no bonus for meeting a new artist. Splitting the same amount of equally rated listening time among several artists is neutral before transfers. It may therefore recommend fewer different artists.",
              "- Square-root and half-base models keep a relative bonus for short appearances/discovery. Their parameters are illustrative product choices, not calibrated user preferences.",
              "- Duration increases have no hard priority. A sufficiently valuable competing combination can still outweigh the longer favorite. This is intentional for an additive objective.",
              "- Rudolstadt 2026 has 310 inferred durations (mostly 60 or 90 minutes); the Fantasy fixture has 500 explicit durations. Optimizing a duration estimate does not establish the actual length of the concert.",
              "- Profiles reuse the prior deterministic generators. The same ratings, saves, candidate concerts and conflict graph are used for every objective within a profile. They are synthetic profiles, not real user data.",
              "- To reduce optimization-quality confounding, each objective gets two independent budgeted passes. The second starts from the best plan under its own objective in the common first-pass pool. An artist-only second-pass solution can still improve after that pool is shared. Nonoptimal outcomes are provisional search results, not exact evidence of the objective's global preference.",
              "- All weights are positive integers, in units of 1/120 displayed point. Only the square-root formula needs rounding. The solver's bounds remain exact for these integer weights.",
              "- Small illustrative cases are solved to proven optimality. Festival results include optimality status and remaining upper bounds per run in results.csv; no claim is made that all are optimal.",
              "- Search timing is Python on this computer and excludes input/graph preparation. It is not a mobile performance prediction.", "",
              "## Reproduce", "", "```sh",
              "python3 -m unittest discover -s scripts/analysis -p '*duration_weights_test.py'",
              f"python3 scripts/analysis/compare_duration_weights.py --seeds {environment['seeds']} --budget {environment['budget_seconds_per_pass']}",
              "```", "", "Selected concerts, inputs, source hashes and environment: details.json. Per-profile metrics: results.csv.", ""]
    (output / "report.md").write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=int, default=5)
    parser.add_argument("--budget", type=float, default=.1, help="Seconds per objective per pass")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/planner-duration-weights")
    args = parser.parse_args()
    if args.seeds <= 0 or not math.isfinite(args.budget) or args.budget <= 0:
        parser.error("Seeds and finite budgets must be positive")
    compare([load_dataset(name) for name in ("rudolstadt-2026", "fantasy-2027")],
            args.seeds, args.budget, args.output)


if __name__ == "__main__":
    main()
