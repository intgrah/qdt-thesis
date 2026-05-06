= Evaluation <ch:evaluation>

We evaluate correctness, performance, and incrementality.

== Correctness

The primary test is the standard library: 2,200 lines of qdt code across 36 files, covering natural number arithmetic, propositional equality, well-founded recursion, sigma types, monadic abstractions, and the Ackermann function. Every definition is fully explicit and type-checked from scratch on each run.

Equality proofs serve as integration tests for the conversion checker: `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeeds only if the elaborator correctly reduces `Nat.add 2 4` to `6` via iota-reduction.

== Batch elaboration performance

Cold-start elaboration of the full stdlib (no cached results) completes in 438ms (median of three runs: 447ms, 408ms, 438ms).

== Conversion checking performance

We stress-test the evaluator and conversion checker with Church-encoded benchmarks from Kovacs's normalisation-bench @kovacs2023smalltt. These encode natural numbers as lambda terms, then check definitional equality between two independently computed values of the same normal form, forcing $n$ beta-reductions on each side.

#figure(
  table(
    columns: (auto, auto),
    align: (left, right),
    table.header([*Benchmark*], [*Time (ms)*]),
    [Nat 10K], [176],
    [Nat 100K], [1,708],
    [Nat 1M], [16,417],
  ),
  caption: [Church numeral conversion checking. Time scales linearly with $n$.],
)

For comparison, smalltt @kovacs2023smalltt handles Nat 5M in 90ms using HOAS closures compiled by GHC. The constant-factor gap is due to our defunctionalised closure representation: each beta-reduction re-interprets the body in an extended environment, whereas HOAS compiles the closure to a native function call.

== Incremental re-elaboration

We measure re-elaboration time after targeted edits, compared to batch.

TODO: table comparing incremental vs batch times for targeted edits.

== Discussion

TODO

