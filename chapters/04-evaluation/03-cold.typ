#import "../../template.typ": metrics, num

== Cold performance <sec:cold-eval>

I evaluate cold elaboration on two corpora: the handwritten stdlib, and the `init/` subset of the Lean 2 HoTT library. The stdlib is a fairness check on the elaborator against code I wrote with its fragment in mind; the HoTT subset is a sanity check on a corpus I did not write, since a self-curated stdlib could understate the cost of features I happen to use sparingly.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Corpus*], [*Files*], [*Definitions*], [*qdt cold (ms)*]),
    [Handwritten stdlib], [#metrics.corpora.stdlib_files], [#num(258)], [666],
    [Lean 2 HoTT, init subset], [23], [#num(1092)], [#num(11770)],
  ),
  caption: [Cold elaboration time under `--build shake-c`, median of five trials per corpus.],
) <fig:cold>

=== The stdlib

The stdlib covers the fragments named in the proposal: $Pi$ and $Sigma$ types, `Nat`, `List`, `Eq`, recursors over a handful of indexed families, and supporting lemmas. Five-trial cold elaboration sits at 666 ms with trial-to-trial variation under 5%.

#smallcaps[Phase breakdown.] @fig:phases attributes per-query durations from `--build shake-trace` to the top-level query that scheduled the work. The instrumented build is slower than `shake-c` (1.85 s versus 0.65 s wall), but per-call instrumentation overhead is approximately uniform across queries, so query-to-query proportions carry over.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Phase*], [*Time (ms)*], [*Share*]),
    [Declaration elaboration (`elabDecl`)], [1527], [90.0%],
    [Module-graph resolution (`transitiveImports`, `imports`)], [114], [6.7%],
    [Per-file dispatch and indexing (`checkFile` shell, `declarationIndex`)], [51], [3.0%],
    [Parsing (`ast`, `astSourceMap`)], [6], [0.4%],
  ),
  caption: [Phase breakdown under `--build shake-trace`, summed across per-query durations from one trace. Declaration elaboration covers both bidirectional checking and conversion; no separate query distinguishes them.],
) <fig:phases>

Declaration elaboration absorbs nine-tenths of the work. The remaining tenth is split across module-graph traversal, per-file dispatch, and parsing in that order, with parsing essentially free. Where to look for cold-time gains is clear: the conversion checker and the NbE evaluator it calls. Nothing else is large enough to matter.

=== The Lean 2 HoTT init subset

The HoTT corpus is the `init/` directory of the Lean 2 HoTT library: 23 files, 1092 surface declarations, frozen at one commit. It is the largest slice that elaborates against the pre-HIT qdt; constructions in `hit/` and their downstream uses are out of scope. Cold elaboration takes 11.77 s on `shake-c`.

A detail of the source caught me out. Lean 2 inlines let-bodies before elaboration: a `let x := e in body` reaches the elaborator with every occurrence of `x` already substituted by $e$. A nested let-chain that reads as $O(n)$ in the source arrives as a term exponential in the nesting depth, with the same subexpression copied across thousands of leaves. A naive elaborator walks each copy independently and never finishes. Common-subexpression elimination on the elaborated terms is what makes this corpus elaborable at all --- an unexciting optimisation forced by an unexpected feature of the source language.
