#import "@preview/cetz:0.3.4"
#import "@preview/cetz:0.3.4": canvas, draw

== Scaling benchmarks

We compare wall-clock time between qdt and Lean 4 on synthetic programs of increasing size. Lean's time includes kernel checking, which qdt does not perform. Each generator produces a file with $N$ definitions following a specific dependency pattern:

- _Discrete_ ($n_i := sans("Nat.zero")$): independent definitions, isolates per-definition overhead.
- _Random_ ($n_i := sans("Nat.succ") thin n_j$ for random $j < i$): realistic dependency shape.
- _Chain_ ($n_i := sans("Nat.succ") thin n_(i-1)$): linear dependency chain, stresses recursive query resolution.
- _Triangle_ ($n_i := n_0 + n_1 + dots + n_(i-1)$): conversion-heavy, each definition reduces a sum of predecessors.

#figure(
  canvas(length: 1cm, {
    import draw: *
    let w = 10
    let h = 6
    let max-n = 10000
    let max-t = 8000

    let sx(x) = x / max-n * w
    let sy(y) = y / max-t * h

    rect((0, 0), (w, h), stroke: 0.4pt)

    for tick in (2000, 4000, 6000, 8000) {
      line((0, sy(tick)), (w, sy(tick)), stroke: 0.2pt + luma(200))
      content((-0.3, sy(tick)), text(size: 7pt)[#tick], anchor: "east")
    }
    for tick in (2000, 4000, 6000, 8000, 10000) {
      line((sx(tick), 0), (sx(tick), h), stroke: 0.2pt + luma(200))
      content((sx(tick), -0.3), text(size: 7pt)[#tick], anchor: "north")
    }
    content((w / 2, -0.8), text(size: 8pt)[$N$ (definitions)])
    content((-1.5, h / 2), text(size: 8pt)[Time (ms)], angle: 90deg)

    let discrete-qdt = ((1000, 60), (5000, 320), (10000, 692))
    let discrete-lean = ((1000, 834), (5000, 2995), (10000, 5739))
    let random-qdt = ((1000, 85), (5000, 479), (10000, 949))
    let random-lean = ((1000, 901), (5000, 3823), (10000, 7439))

    let plot-line(data, color, mark-shape: "o") = {
      for i in range(data.len() - 1) {
        let (x1, y1) = data.at(i)
        let (x2, y2) = data.at(i + 1)
        line((sx(x1), sy(y1)), (sx(x2), sy(y2)), stroke: 1pt + color)
      }
      for (x, y) in data {
        circle((sx(x), sy(y)), radius: 0.08, fill: color, stroke: none)
      }
    }

    plot-line(discrete-qdt, blue)
    plot-line(discrete-lean, blue.lighten(40%))
    plot-line(random-qdt, red)
    plot-line(random-lean, red.lighten(40%))

    let legend-x = 0.5
    let legend-y = h - 0.5
    line((legend-x, legend-y), (legend-x + 0.6, legend-y), stroke: 1pt + blue)
    content((legend-x + 0.8, legend-y), text(size: 7pt)[Discrete (qdt)], anchor: "west")
    line((legend-x, legend-y - 0.4), (legend-x + 0.6, legend-y - 0.4), stroke: 1pt + blue.lighten(40%))
    content((legend-x + 0.8, legend-y - 0.4), text(size: 7pt)[Discrete (Lean)], anchor: "west")
    line((legend-x, legend-y - 0.8), (legend-x + 0.6, legend-y - 0.8), stroke: 1pt + red)
    content((legend-x + 0.8, legend-y - 0.8), text(size: 7pt)[Random (qdt)], anchor: "west")
    line((legend-x, legend-y - 1.2), (legend-x + 0.6, legend-y - 1.2), stroke: 1pt + red.lighten(40%))
    content((legend-x + 0.8, legend-y - 1.2), text(size: 7pt)[Random (Lean)], anchor: "west")
  }),
  caption: [Discrete and Random scaling: qdt vs Lean 4. Lean's time includes startup and kernel checking.],
)

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
  caption: [Full scaling results. Chain and Triangle use smaller $N$ due to superlinear growth.],
)
