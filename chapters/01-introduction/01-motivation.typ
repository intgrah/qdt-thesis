#import "@preview/fletcher:0.5.8": diagram, node, edge

== Motivation

Consider a file with 200 definitions. The user edits definition 5 --- changing its body, not its type. In Lean, Agda, and Rocq, the elaborator re-checks definitions 6 through 200. But suppose only three of those 195 definitions actually unfold definition 5 during conversion checking. The other 192 re-checks are wasted work.

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (10pt, 14pt),

    node((0, 0), [def 5 _(edited)_], fill: rgb("#fce8e6"), name: <d5>),
    node((-1, 1), [def 12], fill: rgb("#fff3e0"), name: <d12>),
    node((0, 1), [def 47], fill: rgb("#fff3e0"), name: <d47>),
    node((1, 1), [def 131], fill: rgb("#fff3e0"), name: <d131>),
    node((2, 1), [192 others], stroke: 0.3pt, fill: rgb("#f0f0f0"), name: <rest>),

    edge(<d12>, <d5>, "->"),
    edge(<d47>, <d5>, "->"),
    edge(<d131>, <d5>, "->"),
  ),
  caption: [After editing definition 5, only 3 of 195 downstream definitions actually depend on its body. Current systems re-check all 195.],
) <fig:motivation>

A dependently typed elaborator runs programs during compilation. When a definition changes, the elaborator must re-check not just definitions that mention it, but any definition whose type checking reduced through its body. In Lean @moura2021lean, Agda @norell2009agda, and Rocq @barras1999coq, this means re-checking everything from the edit point onward.

Existing systems offer limited incrementality. Across files, all three cache compiled results per file: if a file has not changed, its output is reused. When an imported file _does_ change, the importing file is fully invalidated. Within a single file, each system reuses a prefix: Lean saves snapshots of elaboration state at each top-level command and resumes from the last valid one; Agda caches results per declaration for the unchanged prefix; coq-lsp re-checks from the first modified sentence onward. All treat the file as a sequence. If definition 5 of 200 changes, definitions 6 through 200 are re-checked --- even if none depend on definition 5.

In practice, a user working interactively expects sub-second feedback @nielsen1993usability. When an edit triggers re-elaboration of an entire file, the delay can reach tens of seconds in large developments.

Most of this re-checking is redundant. If a definition's body changes but its type is unaffected, definitions that depend only on its type need not be re-checked. What is needed is tracking which results depend on which, and recomputing only what has been invalidated. Unlike in a conventional compiler, where downstream code depends only on type signatures, a dependently typed elaborator may reduce through definition _bodies_ during conversion checking. The dependency structure is finer-grained and discovered dynamically during elaboration.
