#!/usr/bin/env python3
"""Offline MWIS prototype; does not change the app or any festival/profile data.

Run from anywhere: python3 scripts/analysis/benchmark_schedule_planner.py
Uses only the standard library. See the generated report for assumptions.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import platform
import random
import statistics
import time
from dataclasses import dataclass, replace
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / "shared/src/commonMain/resources"
ZONE = ZoneInfo("Europe/Berlin")


def bits(mask: int):
    while mask:
        bit = mask & -mask
        yield bit.bit_length() - 1
        mask ^= bit


@dataclass(frozen=True)
class Event:
    id: int
    artist: int
    place: str
    start: float
    day: str
    start_minutes: int
    duration: int | None = None
    eligible: bool = True

    @property
    def order(self):
        # Matches RecommendationPlanner's dayNumber/startMinutes/id ordering.
        return int(self.day[-2:]), self.start_minutes, self.id


@dataclass(frozen=True)
class Transfer:
    meters: float
    minutes: int
    source: str


def air_distance(a, b):
    if not all(math.isfinite(x) for x in (*a, *b)):
        return None
    if any(not (-90 <= p[0] <= 90 and -180 <= p[1] <= 180) or p == (0, 0)
           for p in (a, b)):
        return None
    lat1, lat2 = math.radians(a[0]), math.radians(b[0])
    dlat, dlon = lat2 - lat1, math.radians(b[1] - a[1])
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 6_371_000 * 2 * math.atan2(math.sqrt(h), math.sqrt(max(0, 1 - h)))


class Walking:
    """Port of WalkingDistanceMatrix + TransferEstimator, default policies."""

    def __init__(self, locations, distances):
        self.locations = locations
        self.edges = {}
        for a, targets in distances.items():
            for b, distance in targets.items():
                if math.isfinite(distance) and 0 <= distance <= 100_000:
                    best = min(distance, self.edges.get(a, {}).get(b, math.inf))
                    self.edges.setdefault(a, {})[b] = best
                    self.edges.setdefault(b, {})[a] = best
        self.known_cache = {}

    def distance(self, a, b):
        if a == b:
            return 0 if a in self.edges else None
        if b in self.edges.get(a, {}):
            return self.edges[a][b]  # Kotlin also prefers a supplied direct edge.
        if a not in self.edges or b not in self.edges:
            return None
        remaining = set(self.edges) & (set(self.locations) | {a, b})
        costs = {a: 0}
        while remaining:
            current = min(remaining, key=lambda p: (costs.get(p, math.inf), int(p)))
            cost = costs.get(current)
            if cost is None:
                return None
            if current == b:
                return cost
            remaining.remove(current)
            for target, edge in self.edges[current].items():
                if target in remaining and cost + edge < costs.get(target, math.inf):
                    costs[target] = cost + edge
        return None

    def known(self, a, b):
        if (a, b) not in self.known_cache:
            distance = self.distance(a, b)
            air = air_distance(self.locations[a], self.locations[b])
            self.known_cache[a, b] = (
                None if distance is not None and air is not None and distance + 100 < air
                else distance
            )
        return self.known_cache[a, b]

    def anchors(self, place):
        if place in self.edges:
            return [(place, 0)]
        choices = []
        for other in self.locations:
            if other != place and other in self.edges:
                air = air_distance(self.locations[place], self.locations[other])
                if air is not None and air <= 300:
                    choices.append((other, air * 1.5))
        return sorted(choices, key=lambda item: (item[1], int(item[0])))[:3]

    def estimate(self, a, b):
        if a == b:
            return Transfer(0, 0, "sameStage")
        if a not in self.locations or b not in self.locations:
            return None
        known = self.known(a, b)
        if known is not None:
            return Transfer(known, max(1, math.ceil(known / 80)), "knownRoute")
        choices = []
        for x, cx in self.anchors(a):
            for y, cy in self.anchors(b):
                distance = self.known(x, y)
                if distance is not None:
                    choices.append((cx + distance + cy, "anchoredEstimate"))
        if not choices or (a not in self.edges and b not in self.edges):
            air = air_distance(self.locations[a], self.locations[b])
            if air is not None:
                choices.append((air * 1.5, "directCoordinateEstimate"))
        if not choices:
            return None
        distance, source = min(choices, key=lambda item: (item[0], item[1] != "anchoredEstimate"))
        if not math.isfinite(distance) or not 0 <= distance <= 100_000:
            return None
        return Transfer(distance, max(1, math.ceil(distance / 80)), source)


def resolve_durations(events):
    """Same stage/gap-based estimates as Kotlin DurationResolver."""
    resolved = {e.id: e.duration for e in events if e.duration is not None}
    for place in {e.place for e in events}:
        following = None
        for event in sorted((e for e in events if e.place == place),
                            key=lambda e: (e.start, e.id), reverse=True):
            if event.duration is None:
                minutes = 60
                gap = (following.start - event.start) / 60 if following else None
                if gap is not None and gap > 0:
                    rounded = math.floor(gap / 30) * 30
                    half = math.floor(gap / 2 / 30) * 30
                    estimate = (gap if rounded < 30 else rounded if rounded < 60
                                else gap / 2 if half < 30 else half if half <= 90
                                else 60 if gap > 300 else 90)
                    minutes = int(gap) if gap < 60 else max(60, int(estimate))
                if minutes > 0:
                    resolved[event.id] = minutes
            following = event
    return [replace(e, duration=resolved.get(e.id)) for e in events]


def transition_conflict(a, b, transfers, requires_known=True):
    """Recommendation policy: 2-minute arrival buffer, no missed minutes.

    Estimated transfers that are too tight become 'unknown' in Kotlin;
    capability-backed planning rejects those too (requiresKnownTransfers).
    """
    a, b = sorted((a, b), key=lambda e: (e.start, e.start + (e.duration or 60) * 60, e.id))
    if a.day != b.day:
        return False
    a_end, b_end = a.start + (a.duration or 60) * 60, b.start + (b.duration or 60) * 60
    if math.ceil(max(0, min(a_end, b_end) - max(a.start, b.start)) / 60) > 0:
        return True
    transfer = transfers.get((a.place, b.place))
    if transfer is None:
        return requires_known
    available = math.floor((b.start - a_end) / 60 - 2)
    late = transfer.minutes > available
    estimated = transfer.source in {"anchoredEstimate", "directCoordinateEstimate"}
    return late and (requires_known or not estimated)


@dataclass
class Dataset:
    name: str
    events: list[Event]
    raw_events: list[Event]
    artists: dict[int, str]
    locations: dict
    matrix: dict
    transfers: dict
    source: Path


def load_dataset(name):
    fantasy = name == "fantasy-2027"
    source = (ROOT / "shared/src/debugResources/FantasyFestival/program.json" if fantasy
              else RESOURCES / "FestivalBackup/2026_rudolstadt_data.json")
    data = json.loads(source.read_text())
    locations = {str(s["id"]): (s.get("latitude", s.get("lat", math.nan)),
                                s.get("longitude", s.get("lon", math.nan))) for s in data["stages"]}
    artists = {a["id"]: a["name"] for a in data["artists"] if a.get("name", "").strip()}
    stages = {str(s["id"]) for s in data["stages"]
              if (s.get("nameDE") if fantasy else s.get("title", "")).strip()}
    raw = []
    for record in data["events"]:
        if fantasy:
            start = datetime.fromisoformat(record["start"]).astimezone(ZONE)
            artist, place = record["artistID"], str(record["stageID"])
        else:
            value = record.get("start", {})
            if value.get("date"):
                start = datetime.fromisoformat(value["date"]).replace(tzinfo=ZoneInfo(value["timezone"]))
                start = start.astimezone(ZONE)
            else:
                start = datetime.strptime(record["day"] + " " + record["time"], "%d.%m.%Y %H:%M").replace(tzinfo=ZONE)
            if start.year != 2026:
                raise ValueError("Unsupported out-of-year record; use the Kotlin converter")
            artist, place = record["artist"], str(record["stage"])
        logical_date = start.date() - timedelta(days=start.hour < 5)
        midnight = datetime.combine(logical_date, datetime.min.time(), ZONE)
        minutes = int((start.timestamp() - midnight.timestamp()) / 60)
        raw.append(Event(record["id"], artist, place, start.timestamp(), str(logical_date),
                         minutes, record.get("durationMinutes"), artist in artists and place in stages))
    matrix = {} if fantasy else json.loads((RESOURCES / "stage_walk_distances.json").read_text())
    walking = Walking(locations, matrix)
    transfers = {(a, b): walking.estimate(a, b) for a in locations for b in locations}
    return Dataset(name, resolve_durations(raw), raw, artists, locations, matrix, transfers, source)


@dataclass(frozen=True)
class Graph:
    adjacent: tuple[int, ...]
    weights: tuple[int, ...]

    @property
    def mask(self):
        return (1 << len(self.weights)) - 1

    def score(self, chosen):
        return sum(self.weights[i] for i in bits(chosen))

    def valid(self, chosen):
        return not chosen & ~self.mask and all(not self.adjacent[i] & chosen for i in bits(chosen))


def conflict_graph(events, transfers):
    adjacent = [0] * len(events)
    for i, a in enumerate(events):
        for j in range(i):
            b = events[j]
            if a.artist == b.artist or transition_conflict(a, b, transfers):
                adjacent[i] |= 1 << j
                adjacent[j] |= 1 << i
    return tuple(adjacent)


def prepare_request(dataset, ratings, saved, now, adjacent):
    events = dataset.events
    saved_indices = [i for i, e in enumerate(events) if e.eligible and e.id in saved]
    saved_artists = {events[i].artist for i in saved_indices}
    # Saved duplicates are allowed by the app. Only new recommendations are unique.
    candidates = [i for i, e in enumerate(events)
                  if e.eligible and ratings.get(e.artist, 0) > 0 and e.id not in saved
                  and e.artist not in saved_artists and e.start >= now
                  and not any(transition_conflict(events[s], e, dataset.transfers) for s in saved_indices)]
    local = {old: i for i, old in enumerate(candidates)}
    graph = Graph(tuple(sum(1 << local[j] for j in bits(adjacent[old]) if j in local)
                        for old in candidates),
                  tuple(ratings[events[i].artist] ** 2 for i in candidates))
    return [events[i] for i in candidates], graph


def current_greedy(events, graph, ratings):
    """Exact candidate-level port, including the current local improvement loop."""
    groups = {}
    priority = sorted(range(len(events)), key=lambda i: (-graph.weights[i], events[i].order))
    for i in priority:
        groups.setdefault(events[i].artist, []).append(i)
    chosen = 0
    for artist in sorted(groups, key=lambda a: (-ratings[a], a)):
        for i in groups[artist]:
            if not graph.adjacent[i] & chosen:
                chosen |= 1 << i
                break
    improved = True
    while improved:
        improved = False
        for i in priority:
            if not chosen & (1 << i):
                conflicts = graph.adjacent[i] & chosen
                if graph.weights[i] > graph.score(conflicts):
                    chosen = (chosen & ~conflicts) | (1 << i)
                    improved = True
    return chosen


@dataclass(frozen=True)
class SearchCheckpoint:
    budget: int
    operations: int
    chosen: int
    score: int
    upper_bound: int
    optimal: bool
    nodes: int
    elapsed_ms: float
    phase: str


@dataclass(frozen=True)
class SearchResult:
    chosen: int
    score: int
    warm_start_score: int
    upper_bound: int
    optimal: bool
    nodes: int
    elapsed_ms: float
    operations: int = 0
    warm_start_operations: int = 0
    checkpoints: tuple[SearchCheckpoint, ...] = ()


def solve(graph, initial=0, seconds=1.0, *, operation_limit=None, checkpoints=(),
          strategy="baseline"):
    """Weighted independent set using bitsets and a weighted clique-cover bound.

    A clique contains mutually conflicting events: at most its highest weight
    can contribute. Partitioning candidates into cliques therefore gives an
    admissible upper bound. Prefix bounds prune include/exclude DFS branches.
    Optional deterministic budget: one operation is a candidate inspection
    in a warm start, clique cover or branch. Input preparation, sorting and
    bitset machine instructions are not counted as separate operations.
    Strategies preserve the original baseline and progressively add active
    clique covers, feasible completions at search nodes, and incumbent repair.
    """
    if not graph.valid(initial):
        raise ValueError("The initial selection is not independent")
    if any(w <= 0 for w in graph.weights):
        raise ValueError("This prototype expects positive candidate weights")
    if strategy not in ("baseline", "active-cover", "improved", "repair"):
        raise ValueError("Unknown search strategy")
    if operation_limit is not None and operation_limit < 0:
        raise ValueError("Operation limit must be nonnegative")
    budgets = tuple(sorted(set(checkpoints)))
    if budgets and (operation_limit is None or budgets[0] < 0 or budgets[-1] > operation_limit):
        raise ValueError("Checkpoints must be within the operation limit")
    started = time.perf_counter()
    deadline = started + seconds if seconds is not None else math.inf
    best, best_score = initial, graph.score(initial)
    nodes = 0
    pending = [sum(graph.weights)]  # Remains valid even if interrupted before coloring.
    operations, warm_operations = 0, 0
    warm_start_score = best_score
    phase = "warm-start"
    recorded = []
    checkpoint_index = 0
    best_upper = sum(graph.weights)

    class BudgetReached(Exception):
        pass

    def upper_bound():
        nonlocal best_upper
        available = pending[1:] if len(pending) > 1 else pending
        best_upper = min(best_upper, max([best_score, *available]))
        return max(best_score, best_upper)

    def record(budget, complete=False):
        upper = best_score if complete else upper_bound()
        recorded.append(SearchCheckpoint(
            budget, operations, best, best_score, upper, upper == best_score,
            nodes, (time.perf_counter() - started) * 1000,
            "complete" if complete else phase))

    def spend():
        nonlocal operations, checkpoint_index
        if checkpoint_index < len(budgets) and operations == budgets[checkpoint_index]:
            record(budgets[checkpoint_index])
            checkpoint_index += 1
        if operations >= operation_limit:
            raise BudgetReached
        operations += 1

    # Record the alternative starts separately so their gains are not
    # misattributed to branch-and-bound. All of this work uses the same budget.
    degrees = [a.bit_count() for a in graph.adjacent]
    # Stable ordering: expensive/high-degree events go first into clique covers.
    rank = sorted(range(len(graph.weights)),
                  key=lambda i: (-graph.weights[i], -graph.adjacent[i].bit_count(), i))

    def cover(mask):
        order, bounds = [], []
        total = 0
        while mask:
            available, maximum = mask, 0
            for v in rank:
                if operation_limit is not None:
                    spend()
                bit = 1 << v
                if available & bit:
                    weight = graph.weights[v]
                    total += max(0, weight - maximum)
                    maximum = max(maximum, weight)
                    order.append(v)
                    bounds.append(total)
                    mask ^= bit
                    available &= mask & graph.adjacent[v]
        return order, bounds

    def active_cover(mask):
        # Partition into conflict cliques using active bitsets. Removed vertices
        # are skipped by bit operations rather than repeatedly inspected.
        cliques = []
        while mask:
            available, clique, maximum = mask, [], 0
            while available:
                if operation_limit is not None:
                    spend()
                bit = available & -available
                v = bit.bit_length() - 1
                clique.append(v)
                maximum = max(maximum, graph.weights[v])
                mask ^= bit
                available &= mask & graph.adjacent[v]
            cliques.append((maximum, clique))
        # Search visits the reverse of this order: high-value choices first.
        cliques.sort(key=lambda pair: pair[0])
        order, bounds, total = [], [], 0
        for _, clique in cliques:
            maximum = 0
            for v in sorted(clique, key=lambda v: (graph.weights[v], v)):
                if operation_limit is not None:
                    spend()
                weight = graph.weights[v]
                total += max(0, weight - maximum)
                maximum = max(maximum, weight)
                order.append(v)
                bounds.append(total)
        return order, bounds

    def complete_plan(mask, chosen, score):
        nonlocal best, best_score
        priority = []
        for v in bits(mask):
            if operation_limit is not None:
                spend()
            degree = (graph.adjacent[v] & mask).bit_count()
            priority.append((-graph.weights[v] / (degree + 1), -graph.weights[v], v))
        priority.sort()
        for _, _, v in priority:
            if operation_limit is not None:
                spend()
            bit = 1 << v
            if mask & bit:
                chosen |= bit
                score += graph.weights[v]
                mask &= ~graph.adjacent[v] & ~bit
                if score > best_score:
                    best, best_score = chosen, score

    def repair_plan():
        # Force an alternative concert, retain compatible incumbent concerts,
        # then fill the newly available slots. Feasible plans only; no local
        # bound is ever presented as a global optimality proof.
        priority = sorted(range(len(graph.weights)),
                          key=lambda v: (-graph.weights[v], degrees[v], v))
        for _ in range(2):
            before = best_score
            for v in priority:
                if seconds is not None and time.perf_counter() >= deadline:
                    raise BudgetReached
                if operation_limit is not None:
                    spend()
                bit = 1 << v
                if best & bit:
                    continue
                chosen, score = bit, graph.weights[v]
                blocked = graph.adjacent[v] | bit
                compatible = best & ~blocked
                for u in bits(compatible):
                    if operation_limit is not None:
                        spend()
                    chosen |= 1 << u
                    score += graph.weights[u]
                    blocked |= graph.adjacent[u] | (1 << u)
                if score > best_score:
                    # A repair may already improve the score before filling.
                    update_incumbent(chosen, score)
                complete_plan(graph.mask & ~blocked, chosen, score)
            if best_score == before:
                break

    def update_incumbent(chosen, score):
        nonlocal best, best_score
        if score > best_score:
            best, best_score = chosen, score

    def expand(mask, chosen, score):
        nonlocal nodes, best, best_score
        nodes += 1
        if score > best_score:
            best, best_score = chosen, score
        if not mask:
            return
        if time.perf_counter() >= deadline:
            raise BudgetReached
        if strategy in ("improved", "repair"):
            complete_plan(mask, chosen, score)
        order, bounds = cover(mask) if strategy == "baseline" else active_cover(mask)
        pending.append(score + bounds[-1])
        for pos in range(len(order) - 1, -1, -1):
            if operation_limit is not None:
                spend()
            pending[-1] = score + bounds[pos]
            if pending[-1] <= best_score:
                break
            if time.perf_counter() >= deadline:
                raise BudgetReached
            v = order[pos]
            bit = 1 << v
            expand(mask & ~graph.adjacent[v] & ~bit, chosen | bit, score + graph.weights[v])
            mask &= ~bit
        pending.pop()

    try:
        for exponent in (1.0, .5, 0.0):
            for reverse_ties in (False, True):
                if time.perf_counter() >= deadline:
                    raise BudgetReached
                order = sorted(range(len(graph.weights)), key=lambda i: (
                    -graph.weights[i] / (degrees[i] + 1) ** exponent,
                    degrees[i], -i if reverse_ties else i))
                chosen = 0
                for v in order:
                    if operation_limit is not None:
                        spend()
                    if not graph.adjacent[v] & chosen:
                        chosen |= 1 << v
                score = graph.score(chosen)
                if score > best_score:
                    best, best_score = chosen, score
                warm_start_score = best_score
        warm_operations = operations
        if strategy == "repair":
            phase = "repair"
            repair_plan()
        phase = "search"
        expand(graph.mask, 0, 0)
        upper = best_score
        complete = True
    except BudgetReached:
        # The first cover bounds the whole root. Deeper entries bound pending
        # siblings. Capture them before unwinding; do not claim optimality.
        upper = upper_bound()
        complete = False
    while checkpoint_index < len(budgets):
        record(budgets[checkpoint_index], complete=complete)
        checkpoint_index += 1
    return SearchResult(best, best_score, warm_start_score, upper, upper == best_score, nodes,
                        (time.perf_counter() - started) * 1000, operations, warm_operations,
                        tuple(recorded))


def profiles(dataset, seeds):
    artists = sorted({e.artist for e in dataset.events if e.eligible})
    first = min(e.start for e in dataset.events)
    mid = sorted({e.day for e in dataset.events})[len({e.day for e in dataset.events}) // 2]
    mid_start = datetime.fromisoformat(mid + "T12:00:00").replace(tzinfo=ZONE).timestamp()
    for seed in range(seeds):
        for label, density in [("sparse", .15), ("medium", .35), ("dense", .7),
                               ("all-mixed", 1), ("saved", .35), ("mid-festival", .35)]:
            rng = random.Random(seed * 101 + 2026)
            ratings = {a: rng.choice((1, 2, 3)) for a in artists if rng.random() < density}
            saved = []
            if label == "saved":
                for event in rng.sample(dataset.events, len(dataset.events)):
                    if event.eligible and all(not transition_conflict(event, other, dataset.transfers)
                                             for other in dataset.events if other.id in saved):
                        saved.append(event.id)
                    if len(saved) == 4:
                        break
            yield label, seed, ratings, saved, mid_start if label == "mid-festival" else first - 1
    yield "all-three-hearts", 0, {a: 3 for a in artists}, [], first - 1


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def benchmark(datasets, seeds, budgets, output):
    output.mkdir(parents=True, exist_ok=True)
    rows, examples, metadata = [], [], []
    for dataset in datasets:
        started = time.perf_counter()
        adjacency = conflict_graph(dataset.events, dataset.transfers)
        graph_ms = (time.perf_counter() - started) * 1000
        metadata.append({"dataset": dataset.name, "events": len(dataset.events),
                         "artists": len(dataset.artists), "eligible": sum(e.eligible for e in dataset.events),
                         "program_graph_ms": graph_ms, "source": str(dataset.source.relative_to(ROOT)),
                         "sha256": hashlib.sha256(dataset.source.read_bytes()).hexdigest()})
        for label, seed, ratings, saved, now in profiles(dataset, seeds):
            started = time.perf_counter()
            events, graph = prepare_request(dataset, ratings, saved, now, adjacency)
            prepare_ms = (time.perf_counter() - started) * 1000
            started = time.perf_counter()
            greedy = current_greedy(events, graph, ratings)
            greedy_ms = (time.perf_counter() - started) * 1000
            greedy_score = graph.score(greedy)
            for budget in budgets:
                result = solve(graph, greedy, budget)
                assert graph.valid(result.chosen) and result.score >= greedy_score
                chosen_events = [events[i] for i in bits(result.chosen)]
                assert all(e.start >= now and e.id not in saved for e in chosen_events)
                assert len({e.artist for e in chosen_events}) == len(chosen_events)
                assert all(not transition_conflict(e, s, dataset.transfers)
                           for e in chosen_events for s in dataset.events if s.id in saved and s.eligible)
                row = {"dataset": dataset.name, "profile": label, "seed": seed,
                       "budget_ms": budget * 1000, "rated_artists": len(ratings), "saved": len(saved),
                       "candidates": len(events), "greedy_score": greedy_score,
                       "warm_start_score": result.warm_start_score,
                       "bnb_score": result.score, "upper_bound": result.upper_bound,
                       "optimal": result.optimal,
                       "gain_percent": 100 * (result.score - greedy_score) / greedy_score if greedy_score else 0,
                       "gap_percent": 100 * (result.upper_bound - result.score) / result.upper_bound if result.upper_bound else 0,
                       "greedy_ms": greedy_ms, "prepare_ms": prepare_ms,
                       "search_ms": result.elapsed_ms, "nodes": result.nodes}
                rows.append(row)
                def describe(mask):
                    return [{"id": events[i].id, "artist": dataset.artists.get(events[i].artist, "?"),
                             "start": datetime.fromtimestamp(events[i].start, ZONE).isoformat(),
                             "duration": events[i].duration, "weight": graph.weights[i]} for i in bits(mask)]
                examples.append({**row, "ratings": ratings, "saved_ids": saved, "now": now,
                                 "greedy": describe(greedy), "bnb": describe(result.chosen)})
            print(f"{dataset.name:16} {label:17} seed={seed:2} n={len(events):3} "
                  f"greedy={greedy_score:3} bnb={result.score:3} upper={result.upper_bound:3} "
                  f"{result.elapsed_ms:8.2f}ms optimal={result.optimal}", flush=True)
    with (output / "results.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    environment = {"python": platform.python_version(), "platform": platform.platform(),
                   "machine": platform.machine(), "clock": "perf_counter", "seeds": seeds,
                   "budgets_seconds": budgets, "datasets": metadata,
                   "walking_matrix_sha256": hashlib.sha256((RESOURCES / "stage_walk_distances.json").read_bytes()).hexdigest()}
    (output / "details.json").write_text(json.dumps({"environment": environment, "runs": examples}, indent=2) + "\n")
    write_report(rows, environment, output)
    return rows


def write_report(rows, environment, output):
    lines = ["# Branch-and-Bound: Python experiment", "",
             f"Python {environment['python']}; {environment['platform']}; {environment['machine']}.", "",
             "| Dataset | Search budget | Cases | Proven optimal | Better than greedy | Better than warm start | Mean score gain | Search median / p95 | Worst remaining gap |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for name in dict.fromkeys(r["dataset"] for r in rows):
        for budget in dict.fromkeys(r["budget_ms"] for r in rows):
            group = [r for r in rows if r["dataset"] == name and r["budget_ms"] == budget]
            timings = [r["search_ms"] for r in group]
            lines.append(f"| {name} | {budget:g} ms | {len(group)} | {sum(r['optimal'] for r in group)} | "
                         f"{sum(r['bnb_score'] > r['greedy_score'] for r in group)} | "
                         f"{sum(r['bnb_score'] > r['warm_start_score'] for r in group)} | "
                         f"{statistics.mean(r['gain_percent'] for r in group):.2f}% | "
                         f"{statistics.median(timings):.2f} / {percentile(timings, .95):.2f} ms | "
                         f"{max(r['gap_percent'] for r in group):.2f}% |")
    lines += ["", "## Model and interpretation", "",
              "- Same objective as the app: sum of artist rating squared (positive ratings 1–3).",
              "- Conflict edges represent same artist (across all festival days), overlap, insufficient transfer time or unknown transfer.",
              "- Saved eligible concerts are fixed, including past ones; their artists and temporal/transfer conflicts are excluded. The search scores only additional recommendations.",
              "- Capability-backed policy: 2-minute arrival buffer, no missed minutes, unknown transfers block recommendations. Estimates are treated like the existing Kotlin policy with requiresKnownTransfers=true.",
              "- Rudolstadt durations and transfer estimates port DurationResolver and TransferEstimator. Fantasy uses its published fixture durations and coordinate estimates, with an empty route matrix, matching its isolated provider.",
              "- Berlin timezone and 05:00 festival-day boundary. Whole festival is solved jointly; there is no unsafe independent per-day split.",
              "- Profiles are deterministic synthetic inputs, not real user data: 15%, 35%, 70%, or 100% of eligible artists rated uniformly 1–3; four fixed concerts; or planning from noon of the middle festival day. One extra profile rates everybody three hearts.",
              "- Baseline ports the existing artist-priority greedy algorithm including its single-event improvement loop, using the same precomputed conflicts.",
              "- B&B starts from that baseline, tries six cheap deterministic alternative greedy orders (weight / (degree+1)^p, p=0,0.5,1, with two tie orders), and uses Python integer bitsets and weighted clique-cover upper bounds. Warm-start score is recorded separately; its work is included in the search budget. optimal=true only when lower and upper bounds agree; gaps use (upper−score)/upper.",
              "- Each budget run starts independently from greedy; the longer run is not a continuation. The budget covers search only and is cooperative; clique-cover computation can exceed the deadline slightly.",
              "- Score gain is the unweighted mean per-profile gain relative to greedy. It measures the defined objective, not visitor satisfaction.",
              "- Timings are single measurements on this computer, not iPhone/Android performance predictions. CSV also records greedy and request preparation time.", "",
              "## Program graph preparation", "",
              "Pairwise program conflicts are precomputed once per dataset and reused across profiles. This cost is not included in search timings.", ""]
    for dataset in environment["datasets"]:
        lines.append(f"- {dataset['dataset']}: {dataset['events']} events, {dataset['artists']} artists, "
                     f"{dataset['eligible']} eligible events; graph {dataset['program_graph_ms']:.2f} ms; source SHA-256 `{dataset['sha256']}`.")
    lines += ["", "## Reproduce", "", "```sh",
              "python3 -m unittest discover -s scripts/analysis -p 'benchmark_schedule_planner_test.py'",
              f"python3 scripts/analysis/benchmark_schedule_planner.py --seeds {environment['seeds']} --budgets "
              + " ".join(str(b) for b in environment["budgets_seconds"]),
              "```", "", "Raw rows: results.csv. Selected concerts, ratings, seeds, source hashes and environment: details.json.", ""]
    (output / "report.md").write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--datasets", nargs="+", choices=["rudolstadt-2026", "fantasy-2027"],
                        default=["rudolstadt-2026", "fantasy-2027"])
    parser.add_argument("--seeds", type=int, default=10)
    parser.add_argument("--budgets", nargs="+", type=float, default=[.1, 1.0], help="Search budgets in seconds")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/planner-benchmark")
    args = parser.parse_args()
    if args.seeds <= 0 or any(not math.isfinite(b) or b <= 0 for b in args.budgets):
        parser.error("Seeds and finite search budgets must be positive")
    benchmark([load_dataset(name) for name in args.datasets], args.seeds, args.budgets, args.output)


if __name__ == "__main__":
    main()
