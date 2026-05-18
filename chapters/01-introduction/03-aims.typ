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
    + to build an *elaborator* for a dependent type theory with $Pi$ types, inductive types, universe polymorphism, structures, demonstrated on subsets of the Lean 2 HoTT library (@sec:correctness-eval), and
    + to achieve *substantial speedup* of cached rebuilds against re-elaboration across a range of edit categories (@sec:incremental-eval).
  ],
)

#pagebreak()

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
    + to give *formally specified guarantees* about our underlying incremental system, in order to remove this aspect of our elaborator from the _trusted computing base_, in particular, to show that our elaborator is semantically identical to _batch elaboration_ (@sec:build-framework, @sec:build-inhabitants), and
    + to *modularise* our code in such a way that extending our incremental system is _easy_ and can support the necessary features expected of modern tooling, such as _profiling_, _tracing_, and _language servers_. (@sec:effect-layers).
  ],
)
