== Headline result

The incremental elaborator is tested on a standard library of 2,300 lines across 10 files, covering arithmetic, equality, well-founded recursion, and algebraic structures. After changing the body of `Nat.add` in `Nat.qdt` (a file imported by five others), the incremental rebuild re-elaborates only the queries whose dependencies changed. The remaining queries are verified by fingerprint comparison and reused. Measurements are in @sec:incremental-eval.

The build system executing this rebuild is one of three inhabitants of a verified `Build` type, proven in Lean 4 to produce the same results as batch evaluation. The proof, the elaborator, and the standard library share the same language, types, and definitions.
