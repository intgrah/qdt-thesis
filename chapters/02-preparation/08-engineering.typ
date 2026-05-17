#import "common.typ": *
#import "@preview/fletcher:0.5.8": diagram, edge, node

== Software engineering practices <sec:engineering>

=== Development methodology

The implementation components decompose into a dependency DAG whose topological levels are the project's milestones. Each layer was developed against small targeted examples before being scaled to the full corpus. smalltt @kovacs2023smalltt was consulted as a reference for "glued" conversion checking.

@fig:milestones groups the components into three priority tiers — *core* (proposal commitment), *extension* (named in the project aims block (#ref(<sec:aims>, supplement: none)) beyond the proposal), and *stretch* (developed during the project, beyond both) — and arranges them into four milestones M1–M4 by topological order.

#let pcore = rgb("#a86060")
#let pext = rgb("#a88060")
#let pstretch = rgb("#607a96")
#let mbg-core = rgb("#f5e8e8")
#let mbg-ext = rgb("#f3ece2")
#let mbg-mixed = rgb("#eee8e8")

#let box-style(fill) = (
  stroke: 0.6pt + fill,
  fill: fill.lighten(80%),
  inset: 5pt,
)
#let swatch(c) = box(width: 0.8em, height: 0.8em, baseline: -0.05em, ..box-style(c))

#figure(
  text(size: 8pt, diagram(
    node-stroke: 0.5pt,
    node-inset: 3pt,
    spacing: (10pt, 9pt),
    edge-stroke: 0.6pt + luma(80),
    mark-scale: 80%,
    node-corner-radius: 2pt,

    // Milestone backgrounds. Three sub-columns (x=0,1,2). y increases downward.
    node((1, 1), [], width: 280pt, height: 110pt, fill: mbg-core, stroke: 0.5pt + pcore.lighten(20%), corner-radius: 5pt, inset: 0pt),
    node((1, 4), [], width: 280pt, height: 70pt, fill: mbg-mixed, stroke: 0.5pt + luma(170), corner-radius: 5pt, inset: 0pt),
    node((1, 7), [], width: 280pt, height: 90pt, fill: mbg-mixed, stroke: 0.5pt + luma(170), corner-radius: 5pt, inset: 0pt),
    node((1, 10), [], width: 280pt, height: 38pt, fill: mbg-ext, stroke: 0.5pt + pext.lighten(20%), corner-radius: 5pt, inset: 0pt),

    // Milestone labels in left gutter.
    node((-1.3, 1), text(size: 7.5pt, weight: 600, fill: luma(80))[*M1*\ founda-\ tions], stroke: none, fill: none),
    node((-1.3, 4), text(size: 7.5pt, weight: 600, fill: luma(80))[*M2*\ cached \ layer], stroke: none, fill: none),
    node((-1.3, 7), text(size: 7.5pt, weight: 600, fill: luma(80))[*M3*\ evaluation \ + ext.], stroke: none, fill: none),
    node((-1.3, 10), text(size: 7.5pt, weight: 600, fill: luma(80))[*M4*\ effect \ layers], stroke: none, fill: none),

    // M1 — Foundations.
    node((0, 0), [Parser], ..box-style(pcore), name: <m1parser>),
    node((1, 0), [AST + smap], ..box-style(pcore), name: <m1ast>),
    node((2, 0), [`Task`], ..box-style(pcore), name: <m1task>),
    node((0, 1), [Bidirectional], ..box-style(pcore), name: <m1bidir>),
    node((1, 1), [NbE +\ glued], ..box-style(pcore), name: <m1nbe>),
    node((2, 1), [`MonadAction`], ..box-style(pcore), name: <m1ma>),
    node((0, 2), [Conversion], ..box-style(pcore), name: <m1conv>),
    node((1, 2), [Inductive], ..box-style(pcore), name: <m1ind>),
    node((2, 2), [`compute`], ..box-style(pcore), name: <m1compute>),

    // M2 — Cached layer.
    node((0, 3.5), [`Busy`], ..box-style(pcore), name: <m2busy>),
    node((1, 3.5), [`LessBusy`], ..box-style(pcore), name: <m2lb>),
    node((2, 3.5), [`Memo` inv.], ..box-style(pcore), name: <m2memo>),
    node((0, 4.5), [`Shake`], ..box-style(pcore), name: <m2shake>),
    node((1, 4.5), [C ports], ..box-style(pstretch), name: <m2cp>),

    // M3 — Evaluation + extensions.
    node((0, 6.5), [`Tasks.` \ `freeTheorem`], ..box-style(pext), name: <m3ft>),
    node((1, 6.5), [Bench-\ marks], ..box-style(pcore), name: <m3bench>),
    node((2, 6.5), [Test suite\ (`#pass`)], ..box-style(pstretch), name: <m3test>),
    node((0, 7.5), [`cacheMiss_` \ `invariant`], ..box-style(pext), name: <m3cm>),
    node((1, 7.5), [Cache\ accounting], ..box-style(pcore), name: <m3acct>),
    node((2, 7.5), [LSP\ server], ..box-style(pstretch), name: <m3lsp>),

    // M4 — Effect layers.
    node((0.3, 10), [`ShakeTrace`], ..box-style(pext), name: <m4trace>),
    node((1.7, 10), [`ShakeCancel`], ..box-style(pext), name: <m4cancel>),

    // Development order: arrows go DOWNWARD = earlier task → later task.
    // M1: parser → bidir → conv; AST → NbE → inductive; Task → MonadAction → compute.
    edge(<m1parser>, <m1bidir>, "->"),
    edge(<m1bidir>, <m1conv>, "->"),
    edge(<m1ast>, <m1nbe>, "->"),
    edge(<m1nbe>, <m1ind>, "->"),
    edge(<m1task>, <m1ma>, "->"),
    edge(<m1ma>, <m1compute>, "->"),

    // M1 → M2: conv enables Busy; inductive enables LessBusy; compute enables Memo invariant.
    edge(<m1conv>, <m2busy>, "->"),
    edge(<m1ind>, <m2lb>, "->"),
    edge(<m1compute>, <m2memo>, "->"),
    edge(<m2busy>, <m2shake>, "->"),

    // M2 → M3: Shake enables freeTheorem; LessBusy enables benchmarks; Memo enables test suite.
    edge(<m2shake>, <m3ft>, "->"),
    edge(<m2lb>, <m3bench>, "->"),
    edge(<m2memo>, <m3test>, "->"),
    edge(<m3ft>, <m3cm>, "->"),
    edge(<m3bench>, <m3acct>, "->"),
    edge(<m3test>, <m3lsp>, "->"),

    // M3 → M4: cacheMiss_invariant enables both effect layers (the layering proof reuses it).
    edge(<m3cm>, <m4trace>, "->"),
    edge(<m3cm>, <m4cancel>, "->"),
  )),
  caption: [
    Development order. Top to bottom is earlier to later. Lean 2 HoTT port omitted; reported in #ref(<ch:evaluation>, supplement: none).
    #swatch(pcore) core
    #h(6pt) #swatch(pext) extension
    #h(6pt) #swatch(pstretch) stretch.
  ],
) <fig:milestones>

The stretch tier accounts for capabilities the project ended up needing. The language server became the natural front-end for the incremental cache, since the incremental-responsiveness desideratum (@sec:requirements) is observable only under editor-driven workloads; without it, the only available measurement is a synthetic batch of edits. The C native ports are an FFI-level drop-in for `Shake` and a separate `Salsa` inhabitant, used to bound the verifying-trace overhead against an unverified executor and to read off the cost of the agreement proof in throughput. The Lean 2 HoTT port supplies a corpus I did not write, ruling out idiosyncrasies of the qdt stdlib as a measurement artefact.

=== Version control and tooling

Source code and dissertation are tracked in Git, with the repository hosted on GitHub. The Lean toolchain `Lake` manages the build and dependencies; `mathlib` @mathlib2020 is the only explicitly required package, with the Lean community `Cli` library and others pulled in transitively. The language server is built against modules from `Lean.Data.Lsp`, and the command-line interface against `Cli`. Tests are defined inline in Lean's _interactive_ mode using the `#eval`, `#guard_msgs`, and `#guard` directives and custom _meta-programming_ features (@sec:correctness-eval).

=== Language choice <sec:language-choice>

The proposal named Rust on top of Salsa. At the start of implementation the decision was revisited; Lean 4 and OCaml were considered alongside. Lean 4 was chosen for three reasons. The query layer is dependently typed (`Val : Key → Type`): Lean expresses this directly, Rust has neither dependent types nor GADTs (generalised algebraic data types, whose constructors specialise the type parameter), and OCaml has GADTs but is not dependently typed and so cannot express proofs. One project aim is a machine-checked correctness proof relating cached and batch elaboration; in Lean the implementation and its proof live in the same project. Lean's macros embed qdt programs directly as inline test cases.

The Salsa framework was replaced by a polymorphic-Task framework written in Lean (@sec:requires).

=== Licensing

Our code is licensed under #link("https://www.apache.org/licenses/LICENSE-2.0")[Apache 2.0], which is aligned with the Lean ecosystem. As discussed in @sec:cold-eval, we export and translate code from the Lean 2 HoTT library @lean2hott. This library is also licensed under Apache 2.0, which permits re-use, and we include the relevant attribution.
