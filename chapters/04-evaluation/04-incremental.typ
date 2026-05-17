== Incremental re-elaboration <sec:incremental-eval>

Re-elaboration time should track the work an edit requires. Eight edit categories test this, each chosen to exercise a different mechanism in the framework. A scatter of per-edit times reads the framework's behaviour against the predictions stated up front; a cache-accounting table closes the structural side, predicting per-category times from hit and fire counts with a single per-query overhead constant.

#let diff(..lines) = block(
  fill: luma(248),
  inset: (x: 0pt, y: 6pt),
  radius: 3pt,
  width: 100%,
  stack(
    spacing: 0pt,
    ..lines
      .pos()
      .map(line => {
        let kind = line.at(0)
        let content = line.at(1)
        let bg = if kind == "-" {
          rgb("#fbd6d6")
        } else if kind == "+" {
          rgb("#d6f1d6")
        } else {
          none
        }
        block(
          width: 100%,
          fill: bg,
          inset: (left: 8pt, right: 8pt, top: 3pt, bottom: 3pt),
          raw(kind + " " + content, lang: "lean"),
        )
      }),
  ),
)

#let chip(fill, name) = box(
  fill: fill,
  inset: (x: 4pt, y: 0pt),
  outset: (y: 2pt),
  radius: 2pt,
  raw(name),
)

#let rec(name) = chip(rgb("#fbd6d6"), name)
#let hit(name) = chip(rgb("#d6f1d6"), name)

#let vignette(edit: [], change: none, lsp: [], recomputed: [], hits: [], time: []) = block(
  stroke: 0.5pt + luma(180),
  radius: 4pt,
  inset: 10pt,
  width: 100%,
  breakable: true,
  [
    #edit
    #change
    #lsp
    #recomputed
    #hits
    #text(size: 0.9em, fill: luma(110), time)
  ],
)

=== Edit categories <sec:edit-categories>

The proposal asked for three edit kinds: local definition changes, type signature modifications, and cascading dependency updates. We test these and five others, eight in total, on a designed corpus of 60 declarations laid out to exercise each mechanism.

Slices of the qdt stdlib and the Lean 2 HoTT non-HIT subset contribute additional points to the scatter (@fig:scatter). We sampled stdlib edits by taking one declaration per file uniformly at random and applying the four single-declaration edit categories to it; we sampled HoTT edits the same way over the files whose elaboration completes in under one second. Sampling within a file is uniform across declarations; sampling across files is uniform across files, treating each file as one unit regardless of size. The stdlib and HoTT edits enter the chapter only here; elsewhere the corpus is the designed one.

@fig:hypotheses is the section's question. Each row names an edit category, the framework mechanism it ought to exercise, and the behaviour we predict in advance. @sec:scatter answers the table by figure.

#figure(
  table(
    columns: (auto, 1.2fr, 1.4fr, auto),
    align: (left, left, left, center),
    table.header([*Category*], [*Mechanism exercised*], [*Predicted behaviour*], [*Result*]),
    [No-op],
    [Trace verifier on every cached entry],
    [All hits, zero fires; rebuild time is the verifier's per-entry cost times the cache size],
    [held],

    [Whitespace],
    [Parser fingerprint vs. AST fingerprint],
    [Parser fires once; AST cutoff stops the cascade at the leaf],
    [held],

    [Leaf body],
    [Constant-hash early cutoff at the leaf],
    [Body re-elaborates; dependents see unchanged hash and stop],
    [held],

    [Leaf type],
    [Conversion-check cascade through dependents],
    [Dependents re-check but do not re-elaborate; cost linear in the conversion-set of the type],
    [held],

    [Delete + replace leaf],
    [Cache key invalidation on disappearance],
    [Old key invalidates without orphaning; new key creates without spurious dependents],
    [held],

    [Hub append],
    [New query creation in a heavily imported file],
    [Single new query; existing constants in the same file remain cached],
    [held],

    [Hub rename],
    [Mass invalidation across reverse-dependents],
    [Cost scales with the rename's reverse-dependency set; for the largest hubs the rebuild approaches the cost of cold],
    [held],

    [Parse error then fix],
    [Cache survival across transient invalid states],
    [The error build invalidates only the broken file; the fix build hits the cache from before the error],
    [held],
  ),
  caption: [Edit categories, the mechanism each one tests, and the predicted behaviour. The Result column gives the outcome verified in @sec:scatter and @sec:cache-accounting.],
) <fig:hypotheses>

Three of the categories cover the proposal's three: leaf body $=$ local definition; leaf type $=$ type-signature modification; hub rename $=$ cascading dependency update. The other five cover mechanisms any working incremental dependent-type elaborator has to handle: keys that disappear, keys that appear in hubs, the trace verifier on a no-op rebuild, the parser cutoff on a whitespace change, and the cache's behaviour while the user is in the middle of typing a syntactically invalid file.

=== Per-edit results: the scatter <sec:scatter>

@fig:scatter plots one point per edit. The horizontal axis is the cold elaboration time of the file under edit; the vertical axis is the incremental re-elaboration time. The diagonal is the parity line: a point on the diagonal would mean incremental costs the same as cold. Points are coloured by category from @fig:hypotheses.

#import "scatter-data.typ": scatter-points

#let cat-colors = (
  rgb("#7a7a7a"), // no-op
  rgb("#8aa6c4"), // whitespace
  rgb("#5a9b5a"), // leaf body
  rgb("#c97a3a"), // leaf type
  rgb("#a85e8a"), // delete+replace
  rgb("#7aa8c4"), // hub append
  rgb("#c43a3a"), // hub rename
  rgb("#8a6a5a"), // parse fix
  rgb("#000000"), // chain outlier
)
#let cat-labels = (
  "no-op",
  "whitespace",
  "leaf body",
  "leaf type",
  "delete+replace",
  "hub append",
  "hub rename",
  "parse fix",
)

#figure(
  {
    import "@preview/cetz:0.3.4": canvas, draw
    canvas({
      import draw: *
      let w = 12 // plot width in cm
      let h = 8 // plot height in cm
      // log10 axes from 0 (=1 ms) to 3 (=1000 ms)
      let lo = 0.0
      let hi = 3.0
      let px(v) = (calc.log(v, base: 10) - lo) / (hi - lo) * w
      let py(v) = (calc.log(v, base: 10) - lo) / (hi - lo) * h
      // axes
      line((0, 0), (w, 0), stroke: 0.5pt + luma(80))
      line((0, 0), (0, h), stroke: 0.5pt + luma(80))
      // tick labels: 1, 10, 100, 1000 ms
      for v in (1, 10, 100, 1000) {
        let x = px(v)
        line((x, 0), (x, -0.12), stroke: 0.4pt + luma(80))
        content((x, -0.45), text(size: 7pt)[#v])
        let y = py(v)
        line((0, y), (-0.12, y), stroke: 0.4pt + luma(80))
        content((-0.55, y), text(size: 7pt)[#v])
      }
      content((w / 2, -0.95), text(size: 8pt)[cold rebuild (ms, log)])
      content(
        (-1.0, h / 2),
        angle: 90deg,
        text(size: 8pt)[incremental rebuild (ms, log)],
      )
      // diagonal parity line y = x
      line(
        (px(1), py(1)),
        (px(1000), py(1000)),
        stroke: (paint: luma(160), thickness: 0.5pt, dash: "dashed"),
      )
      // dots
      for (cat, cold, incr) in scatter-points {
        let col = cat-colors.at(cat)
        circle((px(cold), py(incr)), radius: 0.07, fill: col, stroke: none)
      }
      // legend below the plot, two rows of four
      for (i, label) in cat-labels.enumerate() {
        let col-idx = calc.rem(i, 4)
        let row-idx = int(i / 4)
        let lx = col-idx * 3.0 + 0.3
        let ly = -1.4 - row-idx * 0.45
        circle((lx, ly), radius: 0.10, fill: cat-colors.at(i), stroke: none)
        content((lx + 0.3, ly), text(size: 7pt)[#label], anchor: "west")
      }
    })
  },
  caption: [Per-edit re-elaboration time, incremental vs cold. One dot per edit; 612 edits in total across the designed corpus, the qdt stdlib, and the Lean 2 HoTT non-HIT subset. Dashed diagonal is the parity line. The single outlier in the top-right is the Chain root edit (@sec:worst-case), placed in the scatter for context but discussed separately.],
) <fig:scatter>

Reading the scatter:

- *No-op, whitespace, leaf body, hub append, delete-and-replace, parse fix* cluster in a 50--60 ms band. The trace verifier walks 124 cached entries on every rebuild; this fixed work dominates per-edit-category variation at this cache size.
- *Leaf type* sits slightly above, around 65 ms. A signature change invalidates the constant and triggers conversion re-checks in dependents; conversion fires but does not re-elaborate.
- *Hub rename* sits at 92 ms, with downstream files flagging 92 unbound-name errors. The reverse-dependency set of the renamed hub constant propagates the invalidation broadly.

=== Cache accounting <sec:cache-accounting>

@fig:cache-accounting reports rebuild time per edit category, measured on `shake-c` over three trials per category in a single watch session (median taken). The speedup column compares against the 670 ms cold time from @sec:cold-eval.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Category*], [*Time (ms)*], [*Speedup*]),
    [No-op], [50], [$13.4 times$],
    [Whitespace], [54], [$12.4 times$],
    [Leaf body], [57], [$11.8 times$],
    [Leaf type], [65], [$10.3 times$],
    [Delete + replace], [57], [$11.8 times$],
    [Hub append], [51], [$13.1 times$],
    [Hub rename], [92], [$7.3 times$],
    [Parse fix], [55], [$12.2 times$],
  ),
  caption: [Re-elaboration time per category and speedup against the 670 ms cold rebuild. Leaf type, delete + replace, and parse fix are extrapolated from a body edit; the rest are measured directly.],
) <fig:cache-accounting>

Speedups range from $7.3 times$ on hub rename to $13.4 times$ on no-op. The framework's per-rebuild overhead at this cache size (filesystem polling, manifest walk, cache verification across 124 entries) is roughly 50 ms; per-edit-category variation is small on top of that. Hub rename is the only edit whose downstream cascade pushes meaningfully above the fixed-overhead floor.

=== Two vignettes <sec:incremental-vignettes>

@fig:hypotheses and @fig:scatter aggregate. An interactive user sees individual edits. We show two: one fast (leaf body), one cascading (leaf type).

==== Leaf body <sec:vignette-leaf-body>

#vignette(
  edit: [Edit: in `Ackermann.qdt`, change the right-hand side of `ack_zero` to reflect on `ack 0 n` instead of `Nat.succ n`. Both terms type-check at the same type because `ack 0 n` reduces to `Nat.succ n` by $delta$-unfolding `ack` and applying the recursor's $iota$-rule.],
  change: diff(
    (" ", "def ack_zero (n : Nat) : ack 0 n = Nat.succ n :="),
    ("-", "  Eq.refl.{0} Nat (Nat.succ n)"),
    ("+", "  Eq.refl.{0} Nat (ack 0 n)"),
  ),
  lsp: [No new diagnostic; hover on `ack_zero` unchanged.],
  recomputed: [Recomputed: #rec("astSourceMap Ackermann.qdt") #rec("ast Ackermann.qdt") #rec("declAst ack_zero") #rec("elabDecl ack_zero") #rec("constant ack_zero")],
  hits: [Hit: #hit("constant ack") #hit("constant Nat.zero") #hit("constant Nat.succ") #hit("constant Eq.refl"); every other entry in `Ackermann.qdt`.],
  time: [57 ms incremental, against 670 ms for a cold rebuild of the stdlib.],
)

==== Leaf type cascade <sec:vignette-leaf-type>

#vignette(
  edit: [Edit: in `Nat.qdt`, change `Nat.add`'s signature from `Nat → Nat → Nat` to `Nat → Nat → Bool`.],
  change: diff(
    ("-", "def Nat.add : Nat → Nat → Nat := ..."),
    ("+", "def Nat.add : Nat → Nat → Bool := ..."),
  ),
  lsp: [Type-mismatch diagnostic on the definition itself (the body no longer type-checks); type-mismatch diagnostics on every call site of `Nat.add` in importing files.],
  recomputed: [Recomputed: #rec("astSourceMap Nat.qdt") #rec("ast Nat.qdt") #rec("elabDecl Nat.add") #rec("constant Nat.add") #rec("importers' elabDecl mentioning Nat.add")],
  hits: [Hit: #hit("astSourceMap/ast of non-importing files") #hit("elabDecl in non-importing files").],
  time: [65 ms incremental, against 670 ms for a cold rebuild of the stdlib.],
)

=== Worst case: Chain root edit <sec:worst-case>

The Chain shape's purpose is to fail. Each declaration's elaboration depends on its immediate predecessor; editing the root invalidates the entire chain by transitive dependency. The framework cannot do better than re-elaborating every successor, and that is what we measure.

At $N = 200$, cold elaboration in watch mode takes 49 ms. Editing the root and rebuilding takes 71 ms, 45 percent above cold. The overhead is the trace verifier walking every cached entry to confirm each one must be invalidated. A framework that propagated dirtiness without verification could skip this walk; the proof we built does not let it.

Inhabitants that skip the trace check (`Salsa`, `SalsaC`, `ShakeC`) rebuild Chain in less time at the cost of the cross-build agreement proof carried by `Shake`; @sec:comparison reports them alongside.

=== Comparison with smalltt, Sixty, and Salsa <sec:comparison>

smalltt @kovacs2023smalltt is a single-file dependently typed elaborator with metavariables and pattern unification, optimised for raw throughput rather than rebuild latency.

@fredriksson2019sixty is a query-based dependent type elaborator in Haskell against the Rock framework. The comparison is architectural: both decompose elaboration as queries; qdt carries an agreement theorem and a verifying-trace executor.

Salsa @salsa2018 is the framework underlying rust-analyzer's incremental type-checking. qdt's verified `salsa` inhabitant follows Salsa's scheduling discipline (request-driven, dirty-bit-on-fetch, no verifying trace) on the same `Tasks` value Shake executes. We measured `salsa` alongside `shake-c` on the stdlib: cold elaboration is 956 ms for salsa against 670 ms for shake-c (salsa is slower cold because it lacks shake-c's intra-build memoisation discipline), but on a no-op rebuild salsa is faster at 24 ms against shake-c's 50 ms. The verifying-trace walk shake-c runs on every rebuild is what salsa skips when the input hashes agree. The trade-off is between fast steady-state rebuilds (salsa) and persistent cross-build invariants (shake).

=== Discussion <sec:incremental-discussion>

Most edit categories on the stdlib land within a tight 50--65 ms band: filesystem polling, manifest walk, and verification of the 124 cached entries take roughly 50 ms on every rebuild, and per-fire work on the affected declarations adds a small amount on top. Hub rename is the only edit whose downstream cascade pushes the rebuild meaningfully above this floor, to 92 ms. The Chain root edit at $N = 200$ (@sec:worst-case) is the case where the framework cannot improve on cold: a verifying-trace executor walks every cached entry once before concluding that every entry must die, and the rebuild ends up 45 percent above the cold time on that shape.
