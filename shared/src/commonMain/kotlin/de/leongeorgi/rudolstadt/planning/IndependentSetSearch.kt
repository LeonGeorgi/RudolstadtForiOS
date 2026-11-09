package de.leongeorgi.rudolstadt.planning

import kotlin.math.sqrt

internal data class IndependentSelection(val indices: List<Int>, val operations: Int)

private class SearchStopped : RuntimeException()

/** Fixed-budget weighted independent set: greedy starts, repair, then branch-and-bound. */
internal fun independentSet(
    adjacent: Array<Set<Int>>,
    weights: IntArray,
    initial: Set<Int>,
    cancelled: () -> Boolean,
): IndependentSelection? {
    val all = weights.indices.toSet()
    var best = initial.toSet()
    var bestScore = best.sumOf { weights[it].toLong() }
    var operations = 0
    var aborted = false

    fun checkCancellation() {
        if (cancelled()) {
            aborted = true
            throw SearchStopped()
        }
    }
    fun inspect() {
        if (operations == 10_000) throw SearchStopped()
        if ((operations and 63) == 0) checkCancellation()
        operations++
    }
    fun improve(chosen: Set<Int>, score: Long) {
        if (score > bestScore) {
            best = chosen.toSet()
            bestScore = score
        }
    }
    fun fill(order: List<Int>, candidates: Set<Int>, selected: Set<Int>, selectedScore: Long) {
        val remaining = candidates.toMutableSet()
        val chosen = selected.toMutableSet()
        var score = selectedScore
        improve(chosen, score)
        for (v in order) {
            inspect()
            if (remaining.remove(v)) {
                chosen.add(v)
                score += weights[v]
                remaining.removeAll(adjacent[v])
                improve(chosen, score)
            }
        }
    }
    fun complete(candidates: Set<Int>, chosen: Set<Int>, score: Long) {
        val priority = candidates.associateWith { v ->
            inspect()
            -weights[v].toDouble() / (adjacent[v].count { it in candidates } + 1)
        }
        val order =
            candidates.sortedWith(
                compareBy<Int> { priority.getValue(it) }
                    .thenByDescending { weights[it] }
                    .thenBy { it }
            )
        fill(order, candidates, chosen, score)
    }
    fun cover(candidates: Set<Int>): Pair<List<Int>, LongArray> {
        val remaining = candidates.toMutableSet()
        val cliques = mutableListOf<Pair<Int, List<Int>>>()
        while (remaining.isNotEmpty()) {
            val available = remaining.toMutableSet()
            val clique = mutableListOf<Int>()
            var maximum = 0
            while (available.isNotEmpty()) {
                inspect()
                val v = available.first()
                clique.add(v)
                maximum = maxOf(maximum, weights[v])
                remaining.remove(v)
                available.retainAll(remaining)
                available.retainAll(adjacent[v])
            }
            cliques.add(maximum to clique)
        }
        val order = mutableListOf<Int>()
        val bounds = mutableListOf<Long>()
        var total = 0L
        for ((_, clique) in cliques.sortedBy { it.first }) {
            var maximum = 0
            for (v in clique.sortedWith(compareBy<Int> { weights[it] }.thenBy { it })) {
                inspect()
                total += maxOf(0, weights[v] - maximum)
                maximum = maxOf(maximum, weights[v])
                order.add(v)
                bounds.add(total)
            }
        }
        return order to bounds.toLongArray()
    }
    fun search(candidates: Set<Int>, chosen: Set<Int>, score: Long) {
        improve(chosen, score)
        if (candidates.isEmpty()) return
        complete(candidates, chosen, score)
        val (order, bounds) = cover(candidates)
        val remaining = candidates.toMutableSet()
        for (i in order.indices.reversed()) {
            inspect()
            if (score + bounds[i] <= bestScore) return
            val v = order[i]
            search(remaining - adjacent[v] - v, chosen + v, score + weights[v])
            remaining.remove(v)
        }
    }

    try {
        checkCancellation()
        // Six cheap starts; all candidate inspections count toward the same budget.
        for (exponent in listOf(1.0, .5, .0)) for (reverse in listOf(false, true)) {
            val priority =
                DoubleArray(weights.size) { v ->
                    val degree = adjacent[v].size + 1.0
                    -weights[v] /
                        when (exponent) {
                            1.0 -> degree
                            .5 -> sqrt(degree)
                            else -> 1.0
                        }
                }
            fill(
                all.sortedWith(
                    compareBy<Int> { priority[it] }
                        .thenBy { adjacent[it].size }
                        .thenBy { if (reverse) -it else it }
                ),
                all,
                emptySet(),
                0L,
            )
        }
        val priority =
            all.sortedWith(
                compareByDescending<Int> { weights[it] }.thenBy { adjacent[it].size }.thenBy { it }
            )
        for (round in 0 until 2) {
            val before = bestScore
            for (v in priority) {
                inspect()
                if (v in best) continue
                val chosen = mutableSetOf(v)
                var score = weights[v].toLong()
                val blocked = (adjacent[v] + v).toMutableSet()
                for (u in (best - blocked).sorted()) {
                    inspect()
                    chosen.add(u)
                    score += weights[u]
                    blocked.addAll(adjacent[u])
                    blocked.add(u)
                }
                improve(chosen, score)
                complete(all - blocked, chosen, score)
            }
            if (bestScore == before) break
        }
        search(all, emptySet(), 0L)
        checkCancellation()
    } catch (_: SearchStopped) {
        // A budget stop keeps the best valid selection. Cancellation publishes nothing.
    }
    return if (aborted) null else IndependentSelection(best.sorted(), operations)
}
