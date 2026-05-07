== Scaling benchmarks

We compare wall-clock time between qdt and Lean 4 on synthetic programs of increasing size. Lean's time includes startup (~300ms) and kernel checking, which qdt does not perform. Each generator produces a file with $N$ definitions following a specific dependency pattern.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Benchmark*], [*$N$*], [*qdt (ms)*], [*Lean (ms)*]),
    [Discrete], [1,000], [60], [834],
    [Discrete], [5,000], [320], [2,995],
    [Discrete], [10,000], [692], [5,739],
    [Random], [1,000], [85], [901],
    [Random], [5,000], [479], [3,823],
    [Random], [10,000], [949], [7,439],
    [Chain], [100], [17], [368],
    [Chain], [500], [127], [672],
    [Chain], [1,000], [342], [952],
    [Triangle], [25], [22], [463],
    [Triangle], [50], [101], [964],
    [Triangle], [75], [274], [1,872],
    [Triangle], [100], [587], [3,074],
    [Triangle], [150], [1,835], [6,477],
  ),
  caption: [Elaboration time for synthetic benchmarks. Lean's time includes startup and kernel checking.],
)

- _Discrete_ ($n_i := sans("Nat.zero")$): independent definitions, isolates per-definition overhead.
- _Random_ ($n_i := sans("Nat.succ") thin n_j$ for random $j < i$): realistic dependency shape.
- _Chain_ ($n_i := sans("Nat.succ") thin n_(i-1)$): linear dependency chain, stresses recursive query resolution.
- _Triangle_ ($n_i := n_0 + n_1 + dots + n_(i-1)$): conversion-heavy, each definition reduces a sum of predecessors.
