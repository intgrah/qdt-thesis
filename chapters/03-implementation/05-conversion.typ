== Conversion checking <sec:conv>

#import "@preview/fletcher:0.5.8": diagram, node, edge

Conversion checking decides definitional equality. The naive algorithm --- reduce both sides to normal form, compare structurally --- forces all reducible subterms regardless of whether comparison needs them.

The algorithm here, from Kovacs's smalltt @kovacs2023smalltt, bounds speculative work with a three-state mode:

- *Rigid*: the default. When two values have the same defined head, spines are compared speculatively in flex mode. If flex succeeds, no unfolding was needed. If it fails, both sides are unfolded and compared in full mode.
- *Flex*: entered from rigid's speculative check. No definitions are unfolded; no fallback. Any mismatch causes immediate failure, returning control to rigid.
- *Full*: entered after a flex failure. All definitions are unfolded on encounter. Once in full, all recursive calls remain in full.

@fig:conv-states shows the transitions between these modes. At most one backtrack per subterm: rigid attempts a cheap flex check, and on failure commits to the expensive full check. Flex never unfolds, so the cost of a failed speculation is bounded by the matching prefix of the two spines.

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 8pt,
    node-corner-radius: 3pt,
    spacing: (60pt, 40pt),

    node((0, 0), [`rigid`], fill: rgb("#e8f0fe"), name: <rigid>),
    node((2, 0), [`flex`], fill: rgb("#fef7e0"), name: <flex>),
    node((0, 1), [`full`], fill: rgb("#fce8e6"), name: <full>),

    edge(<rigid>, <flex>, "->", label: [same head], label-side: left),
    edge(<flex>, <rigid>, "-->", label: [fail], label-side: left, bend: 20deg),
    edge(<rigid>, <full>, "->", label: [heads differ], label-side: left),
  ),
  caption: [Conversion state transitions. Rigid speculatively tries flex on matching heads; on failure it falls back to full, which unfolds eagerly.],
) <fig:conv-states>

Consider comparing `f (g (h x))` with itself, where `f`, `g`, `h` are top-level definitions. The naive algorithm unfolds all three on both sides --- potentially exponential. The approximate algorithm observes the same folded structure: same head `f`, same spine. Flex descends into the argument, sees `g`, then `h`, bottoming out at `x` with no unfolding. The check runs in time proportional to the folded term, not the unfolded one.

For eta-conversion: function eta opens both sides at a fresh variable and compares bodies; structure eta compares each projection $s.i$ with the corresponding field $r_i$ of $c(r_1, dots, r_k)$.

An alternative is _on-the-fly_ reduction: whnf each side just enough to decide equality, recurse under binders. This avoids full normal forms, but without the rigid/flex distinction it still unfolds aggressively whenever heads differ syntactically. The speculative flex check avoids this in the common case of matching defined heads.

