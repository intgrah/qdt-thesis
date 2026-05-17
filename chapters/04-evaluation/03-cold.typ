#import "../../template.typ": metrics, num

== Cold performance <sec:cold-eval>

A cache is only worth caching from if cold elaboration costs something. The speedups in @sec:incremental-eval are ratios against the numbers in this section, so the numbers in this section need to be non-trivial. We measure cold elaboration on two corpora: the qdt stdlib, which we wrote and which exists to be elaborated at scale; and the non-HIT subset of the Lean 2 HoTT library, which we did not write and which contains let-bound terms whose naive unfolding doubles their representation size at each step.

@fig:cold reports cold elaboration times.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Corpus*], [*Files*], [*Lines*], [*qdt cold (ms)*]),
    [Handwritten qdt stdlib], [#metrics.corpora.stdlib_files], [#num(metrics.corpora.stdlib_lines)], [670],
    [Lean 2 HoTT, non-HIT subset], [#text(red)[TODO]], [#text(red)[TODO]], [#text(red)[TODO]],
  ),
  caption: [Cold elaboration time, qdt stdlib under `--build shake-c`.],
) <fig:cold>

=== The qdt stdlib

The stdlib's role here is scale. Its #metrics.corpora.stdlib_files files cover the fragments named in the proposal: Pi types, Sigma types, `Nat`, `List`, `Eq`, recursors over a handful of indexed families, and a handful of small proofs. The 670 ms cold time is the value the speedups in @sec:incremental-eval are measured against.

#smallcaps[Phase breakdown.] @fig:phases sums durations from `ShakeTrace` by the constructor of each `Key`.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Phase*], [*Cold (ms)*], [*Share*]),
    [Parsing and lowering], [#text(red)[TODO]], [#text(red)[TODO]],
    [Bidirectional checking], [#text(red)[TODO]], [#text(red)[TODO]],
    [Conversion and NbE], [#text(red)[TODO]], [#text(red)[TODO]],
    [Inductive elaboration], [#text(red)[TODO]], [#text(red)[TODO]],
    [Build-framework overhead], [#text(red)[TODO]], [#text(red)[TODO]],
  ),
  caption: [Phase breakdown for the qdt stdlib cold elaboration.],
) <fig:phases>

=== The non-HIT subset of Lean 2 HoTT

The Lean 2 HoTT library is the worked example we did not write. We use a subset defined by milestone: everything that elaborates against the pre-HIT version of qdt, fixed at one commit.

I was surprised to find that Lean 2 inlines let-bodies before elaboration. A compact let in the source becomes a giant unfolded term by the time elaboration sees it, with right-hand sides repeated many times across the body. Naive elaboration substitutes each occurrence independently and the term explodes. Common-subexpression elimination on shared sub-terms keeps the corpus tractable; without it the elaborator does not finish on a 32 GB machine.
