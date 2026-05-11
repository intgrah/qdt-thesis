== Headline result

After changing the body of `Nat.add` in `Nat.qdt` (a file imported by five others), the incremental rebuild re-elaborates only the queries whose dependencies changed. The remaining queries are verified by fingerprint comparison and reused. Measurements are in @sec:incremental-eval.

The build system executing this rebuild is one of three inhabitants of a verified `Build` type, proven in Lean 4 to produce the same results as batch evaluation. The proof and the elaborator share the same language, types, and definitions.
