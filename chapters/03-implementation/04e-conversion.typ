=== Conversion checking <sec:conv>

#import "@preview/fletcher:0.5.8": diagram, edge, node

Conversion checking decides definitional equality. The speculation-then-fallback strategy of @sec:nbe-theory is realised here as the three-mode algorithm of Kovacs's smalltt @kovacs2023smalltt:

- *Rigid*: the default. Two glued values with the same head trigger a speculative spine comparison in flex; on flex failure both sides are forced and compared in full.
- *Flex*: entered from rigid's speculative check. No definitions are unfolded; no fallback. Any mismatch causes immediate failure, returning control to rigid.
- *Full*: entered after a flex failure. All definitions are unfolded on encounter. Once in full, all recursive calls remain in full.

@fig:conv-states shows the transitions between these modes. At most one backtrack per subterm: rigid attempts a cheap flex check, and on failure commits to the expensive full check. Flex never unfolds, so the cost of a failed speculation is bounded by the matching prefix of the two spines.

#figure(
  diagram(
    node-stroke: 0.6pt,
    node-inset: 8pt,
    spacing: (60pt, 40pt),

    node((0, 0), [`rigid`], fill: rgb("#dce4f0"), name: <rigid>),
    node((2, 0), [`flex`], fill: rgb("#e8dfd0"), name: <flex>),
    node((0, 1), [`full`], fill: rgb("#e6d0c8"), name: <full>),

    edge(<rigid>, <flex>, "->", label: [same head], label-side: left),
    edge(<flex>, <full>, "->", label: [fail], label-side: left),
    edge(<rigid>, <full>, "->", label: [heads differ], label-side: left),
  ),
  caption: [Conversion state transitions. ],
) <fig:conv-states>

Consider comparing `Nat.add 2 3` against `Nat.add 2 3`. Both sides are glued values with the same defined head `Nat.add`. Rigid enters flex speculatively. Flex compares the spines elementwise: the first arguments are both `Nat.succ (Nat.succ Nat.zero)`, same constructor head `Nat.succ`; recurse into the field, same again, down to `Nat.zero` on both sides. The second arguments match similarly. Flex succeeds. No definition body was fetched.

Now comparing `Nat.add 2 3` against `5`. The heads differ: `Nat.add` is a defined constant appearing as a glued value, while `Nat.succ` is a constructor appearing as a neutral. Different heads skip flex and enter full mode. Full forces the glued value via `whnf`, which fetches `Nat.add`'s definition body and fires iota-reduction on the recursor three times, yielding `Nat.succ (Nat.succ (Nat.succ (Nat.succ (Nat.succ Nat.zero))))`. This matches `5`. The check succeeds, but `Nat.add`'s body was fetched, so a dependency is recorded.

The checker also decides the two $eta$ rules of @sec:type-theory. For function $eta$, comparing a lambda against a non-lambda (or two lambdas) applies both sides to a fresh variable at the current de Bruijn level and compares the bodies, so `f` need not syntactically be a lambda. For structure $eta$, when one side is a constructor application $c(r_1, dots, r_k)$ of a single-constructor inductive and the other is an arbitrary term $s$, each projection $s.i$ is compared against the corresponding field $r_i$.

