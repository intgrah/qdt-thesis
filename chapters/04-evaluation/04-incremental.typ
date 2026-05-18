#import "../../template.typ": diff

== Incremental re-elaboration <sec:incremental-eval>

A rebuild should cost what its edit demands. To check whether ours does indeed do this, I designed nine edit categories so that each isolates one mechanism the framework relies on. @fig:hypotheses commits to a prediction per category before any measurement; @sec:scatter and @sec:cache-accounting report what was measured.

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
    #h(0.5em)
    #text(size: 0.9em, fill: luma(110), time)
  ],
)

=== Edit categories <sec:edit-categories>

The proposal asked for three edit kinds: local definition changes, type-signature modifications, and cascading dependency updates. These map onto leaf body, leaf type, and hub rename respectively. I added six more: a no-op so the verifier walks an unchanged cache, whitespace to separate the parser fingerprint from the AST fingerprint, an ill-typed body so the cache must survive a failed elaboration, a hub append for query creation, a delete-and-replace for key disappearance, and a parse error to exercise the cache while the file is unparseable. Each category is anchored at a fixed declaration: `Std/Nat.qdt` for hub-level edits, `Std/Ackermann.qdt` for leaf-level body edits, and `Std/Sigma.qdt` for whitespace and parse-error edits.

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

    [Leaf body, ill-typed],
    [Error propagation without cache corruption],
    [Body fails elaboration; its `constant` entry is absent from the next cache; surviving entries are reused on the fix],
    [held],

    [Leaf type],
    [Conversion-check cascades through dependents],
    [Dependents re-check but do not re-elaborate; cost linear in the conversion-set of the type],
    [held],

    [Delete + replace leaf],
    [Cache key invalidation on disappearance],
    [Old key invalidates without orphaning; new key creates without spurious dependents],
    [held],

    [Hub append],
    [New query in a heavily imported file],
    [Single new query; existing constants in the same file remain cached],
    [held],

    [Hub rename],
    [Mass invalidation across reverse-dependents],
    [Cost scales with the reverse-dependency set; dependents re-check against the renamed constant rather than re-elaborating, so the cascade stays well below cold],
    [held],

    [Parse error],
    [Cache survival across transient invalid states],
    [Only the broken file invalidates; the next non-broken edit hits the cache from before the error],
    [held],
  ),
  caption: [Edit categories, the mechanism each one tests, the predicted behaviour, and the outcome confirmed in @sec:scatter and @sec:cache-accounting.],
) <fig:hypotheses>

=== Per-file scatter <sec:scatter>

@fig:scatter plots one point per (file, edit) pair on the stdlib for the three categories that apply to every file: noop, whitespace, and hub append. The horizontal axis is the cold elaboration time of the file's transitive closure (3--589 ms across the stdlib); the vertical axis is the incremental rebuild time. Each file is measured in a watch session whose entry module is the file itself, so cold and incremental walk the same dependency subtree --- the parity diagonal compares like-for-like. Times come from `IO.monoNanosNow` and are reported in milliseconds with sub-millisecond precision.

#import "scatter-data.typ": scatter-points

#let cat-colors = (
  rgb("#7a7a7a"), // noop
  rgb("#8aa6c4"), // whitespace
  rgb("#7aa8c4"), // hub-append
)
#let cat-labels = ("noop", "whitespace", "hub-append")

#figure(
  scale(85%, reflow: true, {
    import "@preview/cetz:0.3.4": canvas, draw
    canvas({
      import draw: *
      let w = 12
      let h = 8
      let lo = -1.0 // log10(0.1)
      let hi = 3.0 // log10(1000)
      let px(v) = (calc.log(v, base: 10) - lo) / (hi - lo) * w
      let py(v) = (calc.log(v, base: 10) - lo) / (hi - lo) * h
      line((0, 0), (w, 0), stroke: 0.5pt + luma(80))
      line((0, 0), (0, h), stroke: 0.5pt + luma(80))
      for (v, label) in ((0.1, "0.1"), (1, "1"), (10, "10"), (100, "100"), (1000, "1000")) {
        let x = px(v)
        line((x, 0), (x, -0.12), stroke: 0.4pt + luma(80))
        content((x, -0.45), text(size: 7pt)[#label])
        let y = py(v)
        line((0, y), (-0.12, y), stroke: 0.4pt + luma(80))
        content((-0.55, y), text(size: 7pt)[#label])
      }
      content((w / 2, -0.95), text(size: 8pt)[file cold rebuild (ms, log)])
      content(
        (-1.0, h / 2),
        angle: 90deg,
        text(size: 8pt)[incremental rebuild (ms, log)],
      )
      line(
        (px(0.1), py(0.1)),
        (px(1000), py(1000)),
        stroke: (paint: luma(160), thickness: 0.5pt, dash: "dashed"),
      )
      for (cat, cold, incr) in scatter-points {
        let col = cat-colors.at(cat)
        circle((px(cold), py(incr)), radius: 0.08, fill: col, stroke: none)
      }
      let lx = 0.5
      let ly = h - 0.5
      rect(
        (lx - 0.2, ly + 0.3),
        (lx + 2.6, ly - 0.4 * cat-labels.len() - 0.1),
        stroke: 0.4pt + luma(140),
        fill: rgb(255, 255, 255, 220),
      )
      for (i, label) in cat-labels.enumerate() {
        let yy = ly - 0.4 * i
        circle((lx, yy), radius: 0.10, fill: cat-colors.at(i), stroke: none)
        content((lx + 0.3, yy), text(size: 7pt)[#label], anchor: "west")
      }
    })
  }),
  caption: [Per-file re-elaboration time against the file's transitive cold cost, stdlib under `shake-c`. One dot per (file, edit) across three universally applicable edit categories. Both axes are log-scale, and the diagonal is the parity line.],
) <fig:scatter>

Every dot lies below the diagonal. At the extremes, the smallest file (3.2 ms cold), rebuilds in 0.17 ms on noop, 0.88 ms on whitespace, and 2.8 ms on hub append. the largest (589 ms cold), rebuilds in tens of milliseconds across the same three categories. Across the corpus the incremental cost grows much more slowly than the cold cost: about one order of magnitude separates the two at the top, two at the bottom. Hub append sits above noop and whitespace on every file, since a fresh declaration forces one new query through the build graph, while the other two categories ride entirely on cache verification.

=== Per-category timings <sec:cache-accounting>

The scatter pools all three uniform categories across files. To compare categories one by one, I fix the corpus (the full stdlib, watched at module `Std`) and vary the edit. @fig:cache-accounting reports five-trial medians per category in one watch session.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Category*], [*Median (ms)*], [*n*], [*Errors*]),
    [No-op], [2.6], [5], [0],
    [Whitespace], [1.6], [5], [0],
    [Leaf body], [7.6], [5], [0],
    [Leaf body, ill-typed], [18.8], [5], [19],
    [Leaf type], [25.1], [5], [4],
    [Delete + replace], [30.0], [5], [0],
    [Hub append], [27.9], [5], [0],
    [Parse error], [3.5], [5], [1],
    [Hub rename], [76.0], [1], [92],
  ),
  caption: [Per-category re-elaboration on `shake-rdeps`, stdlib watched at module `Std`. Five trials per category in one session, median reported. The `Errors` column gives the diagnostic count after the edit; hub rename is reported from a single trial because its mass invalidation does not reset cleanly on snapshot restore within a session.],
) <fig:cache-accounting>

The categories stratify across nearly two orders of magnitude. No-op and whitespace sit at the file-watcher floor (1.6--2.6 ms): no input changed except for a sub-AST detail, no query was dirtied, no work happened. Parse error joins them at 3.5 ms --- the broken file's parser query invalidated, nothing downstream. Leaf body re-elaborates exactly one declaration at 7.6 ms; the ill-typed variant pays an additional 11 ms emitting nineteen diagnostics on downstream call sites. Leaf type, delete + replace, and hub append cluster between 25 and 30 ms, reflecting the size of each edit's reverse-dependency closure inside one file. Hub rename, the only edit invalidating a hub constant whose reverse-dependency closure spans 92 declarations, sits a factor of three above the next category at 76 ms --- still 11$times$ below the 818 ms cold rebuild. Every category's cost reflects the edit's affected closure rather than the cache size, which is what @fig:hypotheses predicted of an rdep-tracked verifying-trace executor.

=== Two vignettes <sec:incremental-vignettes>

To make the work pattern of a single edit visible, I trace two leaf-body changes to `ack_zero` in `Ackermann.qdt` against an 818 ms cold rebuild of the stdlib under `shake-rdeps`: one well-typed, one not. The first should leave the cache intact and recompute exactly the changed declaration; the second should report an error without corrupting the rest of the cache.

==== Leaf body, well-typed <sec:vignette-leaf-body>

#vignette(
  edit: [Change `ack_zero`'s right-hand side from `Nat.succ n` to `ack 0 n`. Both terms type-check at the same type, since `ack 0 n` reduces to `Nat.succ n` by $delta$-unfolding `ack` and applying the recursor's $iota$-rule.],
  change: diff(
    (" ", "def ack_zero (n : Nat) : ack 0 n = Nat.succ n :="),
    ("-", "  Eq.refl.{0} Nat (Nat.succ n)"),
    ("+", "  Eq.refl.{0} Nat (ack 0 n)"),
  ),
  lsp: [No new diagnostic; hover on `ack_zero` unchanged.],
  recomputed: [Recomputed: #rec("astSourceMap.qdt") #rec("ast Ackermann.qdt") #rec("declAst ack_zero") #rec("elabDecl ack_zero") #rec("constant ack_zero").],
  hits: [Hit: #hit("constant ack") #hit("constant Nat.zero") #hit("constant Nat.succ") #hit("constant Eq.refl"), and every other entry in the file.],
  time: [8 ms.],
)

==== Leaf body, ill-typed <sec:vignette-leaf-broken>

#vignette(
  edit: [Replace `Nat.succ n` with `Nat.succ (Nat.succ n)` in `ack_zero`'s body. The right-hand side now has type `ack 0 n = Nat.succ (Nat.succ n)`, which does not match the declared signature.],
  change: diff(
    (" ", "def ack_zero (n : Nat) : ack 0 n = Nat.succ n :="),
    ("-", "  Eq.refl.{0} Nat (Nat.succ n)"),
    ("+", "  Eq.refl.{0} Nat (Nat.succ (Nat.succ n))"),
  ),
  lsp: [Type-mismatch on `ack_zero`'s body; nineteen further diagnostics from downstream `example`s reporting the dangling identifier.],
  recomputed: [Recomputed: #rec("astSourceMap Ackermann.qdt") #rec("ast Ackermann.qdt") #rec("declAst ack_zero") #rec("elabDecl ack_zero"), and each downstream `example`.],
  hits: [Hit: the cached `constant` entries for `ack`, `Nat.succ`, and `Eq.refl` survive; only the broken declaration's `constant` is missing from the next cache.],
  time: [19 ms.],
)

=== Comparison <sec:comparison>

The closest architectural neighbours are smalltt @kovacs2023smalltt, @fredriksson2019sixty, and Salsa @salsa2018. smalltt optimises raw single-file throughput and does not address rebuild latency. @fredriksson2019sixty exposes elaboration as queries against the Rock framework, the precedent our `Tasks` value resembles most. Salsa underlies rust-analyzer's incremental type-checking; our `salsa` inhabitant follows its discipline --- request-driven, dirty-bit-on-fetch, no verifying trace --- on the same `Tasks` value `shake` executes.

The inhabitants the chapter compares against are `shake-c` (a verifying-trace executor without rdep tracking), `salsa` and `salsa-c` (request-driven, dirty-bit-on-fetch, no verifying trace), and `shake-standard-rdeps` (rdep tracking with the structural agreement certificate). @fig:variant-comparison reports cold and no-op for the five.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Inhabitant*], [*Cold (ms)*], [*No-op rebuild (ms)*]),
    [`shake-rdeps`], [818], [2.6],
    [`shake-standard-rdeps`], [931], [3.3],
    [`salsa`], [819], [22.6],
    [`salsa-c`], [657], [28.4],
    [`shake-c`], [666], [54.3],
  ),
  caption: [Median cold and no-op rebuild on the stdlib for five `Build` inhabitants. Cold is one-shot; no-op is the watch-mode rebuild after touching an unchanged file. Five-trial medians.],
) <fig:variant-comparison>

The factor-20 gap between `shake-rdeps` and `shake-c` on no-op is what rdep tracking buys. `shake-c` verifies its 124-entry cache against the inputs before consuming any cached value, walking the trace once per rebuild; that walk is most of the 54 ms total. `shake-rdeps` propagates input-fingerprint changes forward through stored reverse-dep edges and never inspects queries outside the affected closure; on a no-op, the closure is empty and the rebuild does almost nothing. `salsa` and `salsa-c` skip the verifier walk too but pay a different price: their agreement obligation is weaker, discharged by a different proof structure that this thesis does not develop. The verified `shake-standard-rdeps` (@sec:shake-standard-rdeps) matches `shake-rdeps`'s no-op latency to within a millisecond while keeping the structural agreement certificate, since its `set` short-circuit on input fingerprint equality returns the cached `Persist` unchanged and the four invariants transport across `Input.get j' = Input.get j` without re-elaboration.

=== Discussion <sec:incremental-discussion>

Under `shake-rdeps`, every category's cost reflects the edit's actual work: no-op and whitespace pay only the file-watcher floor, parse error invalidates one file's parser, leaf body re-elaborates exactly one declaration, leaf type and delete + replace and hub append do one file's reverse-dep cascade, and hub rename does the whole-corpus reverse-dep cascade --- 1.6 ms to 76 ms across the nine categories. The four-tier stratification is the empirical content of @fig:hypotheses: every category exercises one mechanism, and that mechanism's cost is now visible in the wall-clock time without a fixed verifier-walk overhead masking it. The verifying-trace inhabitant `shake-c` would have hidden seven of the nine categories behind a 54 ms cache-verification floor (@fig:variant-comparison); rdep tracking lifts the floor and exposes the framework's per-edit behaviour as the chapter's hypotheses predicted.
