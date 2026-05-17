== Aims <sec:aims>

The core aims of this project correspond to the two success criteria of the proposal: correctly type-checking a dependent type theory, and showing measurable incremental performance improvement against re-elaboration. Specifically, we seek

#block(
  width: 100%,
  inset: (x: 12pt, y: 10pt),
  stroke: 0.5pt + luma(160),
  radius: 3pt,
  breakable: true,
  [
    #text(weight: 500, smallcaps[Core aims])
    #v(0.4em)
    #set enum(numbering: "(a)")
    + to *elaborate* a dependent type theory with $Pi$ types, inductive types, universe polymorphism, structures, demonstrated on subsets of the Lean 2 HoTT port (@sec:correctness-eval), and
    + to achieve *substantial speedup* of cached rebuilds against re-elaboration across a range of edit categories (@sec:incremental-eval).
  ],
)

#block(
  width: 100%,
  inset: (x: 12pt, y: 10pt),
  stroke: 0.5pt + luma(160),
  radius: 3pt,
  breakable: true,
  [
    #text(weight: 500, smallcaps[Extension aims])
    #v(0.4em)
    #set enum(numbering: "(a)")
    + to *prove* in Lean 4 that every inhabitant of the polymorphic `Build` type produces the same result as a reference `compute` semantics defined by well-founded recursion (@sec:build-framework, @sec:build-inhabitants), with the verified core depending only on the axioms `propext` (propositional extensionality) and `Quot.sound` (soundness of quotient types) (@sec:correctness-eval), and
    + to layer *effect-carrying extensions* (`ShakeTrace` for tracing, `ShakeCancel` for cancellation) that inherit the agreement proof _without_ revisiting it (@sec:effect-layers).
  ],
)
