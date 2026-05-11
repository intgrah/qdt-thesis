== Batch elaboration performance

// TODO: numbers below need re-measuring on final code; the methodology and structure are settled.

We measure cold elaboration time on the two corpora and break it down by pipeline phase. The cold-build measurements isolate the elaborator's raw throughput; the breakdown shows which phase dominates.

=== Methodology

All measurements are taken on // TODO: hardware spec — CPU, RAM, OS, kernel.

Software: Lean // TODO: version, qdt // TODO: commit hash. The elaborator is compiled with `lake build --release`. The Lean comparison uses Lean // TODO: version with `lake build` on equivalent `.lean` files generated from the qdt source.

Each measurement is the minimum across at least five cold runs. Reporting the minimum (rather than the mean) follows standard practice for benchmarking deterministic computations: variance comes from system noise rather than from the workload, and the minimum approximates the no-noise lower bound. The Shake store is discarded between runs.

=== Results

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Corpus*], [*Files*], [*Lines*], [*Time (ms)*]),
    [Handwritten qdt], [39], [2,300], [TODO],
    [Lean 2 HoTT port], [23], [4,375], [TODO],
  ),
  caption: [Cold elaboration of each corpus.],
) <fig:batch-corpus>

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Phase*], [*Time (ms)*], [*Share*]),
    [Parsing + desugaring], [TODO], [TODO],
    [Bidirectional checking], [TODO], [TODO],
    [Conversion + NbE], [TODO], [TODO],
    [Inductive elaboration], [TODO], [TODO],
    [Build system overhead], [TODO], [TODO],
  ),
  caption: [Phase breakdown of a cold elaboration of the Lean 2 HoTT port.],
) <fig:batch-phases>

The conversion checker dominates, as expected: it is the only phase that performs unbounded computation, and every type annotation in the corpus drives at least one conversion check. Parsing is cheap; bidirectional checking without conversion is cheap; build system overhead is a fixed cost paid once per query.

=== Comparison against Lean 4

Lean 4 elaborates the same code with kernel checking, which qdt does not perform. A direct comparison is therefore unfair to Lean 4 in absolute terms. We report it nonetheless to give a sense of qdt's per-definition cost on a like-for-like workload.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Corpus*], [*qdt (ms)*], [*Lean 4 (ms)*], [*Ratio*]),
    [Handwritten qdt], [TODO], [TODO], [TODO],
    [Lean 2 HoTT port], [TODO], [TODO], [TODO],
  ),
  caption: [Cold elaboration of each corpus, qdt versus Lean 4. Lean 4 includes kernel checking; qdt does not. Synthetic benchmarks of varying dependency shape are reported in @sec:scaling.],
)
