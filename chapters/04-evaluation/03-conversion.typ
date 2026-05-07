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

For comparison, Kovacs's normalisation-bench @kovacs2023smalltt reports Nat 5M conv in 90ms for a GHC-compiled HOAS evaluator, and 500ms for smalltt (which does more bookkeeping for elaboration). The gap with our implementation is due to defunctionalised closures: each beta-reduction re-interprets the body in an extended environment, whereas HOAS compiles the closure to a native function call.
