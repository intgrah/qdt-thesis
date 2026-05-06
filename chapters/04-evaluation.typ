= Evaluation <ch:evaluation>

We evaluate the elaborator along three axes: correctness, performance, and incrementality.

== Correctness

The primary correctness test is the standard library. The stdlib contains 2,200 lines of qdt code across 36 files, covering natural number arithmetic, propositional equality, well-founded recursion, sigma types, monadic abstractions, and the Ackermann function. Each definition is fully explicit --- no implicit arguments or wildcards --- and type-checked from scratch on every run.

Equality proofs in the stdlib serve as integration tests for the conversion checker: a proof `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeeds only if the elaborator correctly reduces `Nat.add 2 4` to `6` via iota-reduction on the recursor.

== Batch elaboration performance

We measure the time to elaborate the full stdlib from a cold start, with no cached results.

Cold-start elaboration of the full stdlib completes in approximately 438ms (median of three runs: 447ms, 408ms, 438ms).

== Conversion checking performance

To stress-test the evaluator and conversion checker in isolation, we use Church-encoded benchmarks adapted from Kovacs's normalisation-bench @kovacs2023smalltt. These encode natural numbers and binary trees as lambda terms, then check definitional equality between two independently computed values of the same normal form.

The benchmarks are:

- *Nat $n$ conv*: check that two Church numerals, both representing $n$, are definitionally equal. This forces $n$ beta-reductions on each side.
- *Tree $n$ conv*: check that two full binary trees of depth $n$ (with $2^(n+1) - 1$ nodes) are definitionally equal.

Nat 10K conv (checking equality of two Church numerals representing 10,000) completes in approximately 136ms (median of three runs: 139ms, 134ms, 136ms). Larger benchmarks (Nat 100K and above) overflow the stack. This is a known limitation of the defunctionalised closure representation used in the evaluator --- each beta-reduction is a recursive call, and Church numerals with $n$ successors require $n$ stack frames.

For comparison, smalltt handles Nat 5M conv in approximately 90ms and Nat 10M conv in 180ms, using HOAS closures compiled by GHC. The stack overflow in our implementation prevents direct comparison at these scales.

== Incremental re-elaboration

The key benefit of the query-based architecture is that editing a single definition does not require re-checking the entire file. We measure the time to re-elaborate after modifying a definition, compared to batch re-elaboration.

TODO: table comparing incremental vs batch times for targeted edits.

== Discussion

TODO

