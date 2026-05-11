== Work completed

// TODO

The project's contributions, summarised against the proposal's success criteria:

/ Build system formalisation: a refinement of the "Build Systems à la Carte" framework in Lean 4, with dependent query result types (`Val : Key -> Type`), an input-query separation at the type level, and a well-foundedness condition on the dependency relation. Three build systems — Busy, LessBusy, and Shake — inhabit a verified `Build` type and compute the same results as `compute` by construction. Extensions beyond the proposal: a free theorem connecting tasks in `Id` and `StateM Cache` so memoising and pure semantics agree, and C FFI implementations of Shake and Salsa matching Lean's runtime ABI.

/ Incremental elaborator: a dependently typed elaborator for a calculus with dependent function types, Tarski-style universes with universe polymorphism, inductive types with recursors, and structures with projections. Elaboration is decomposed into per-declaration queries executed by the formalised build system. Extensions beyond the proposal: glued evaluation, approximate conversion checking with rigid/flex/full modes, a language server providing diagnostics and hover information, and a port of the non-HIT subset of the Lean 2 HoTT library exercising the elaborator on third-party code.

/ Evaluation: measurements of correctness on a handwritten qdt corpus and the Lean 2 HoTT port, conversion-checker microbenchmarks against `smalltt`, and incremental re-elaboration latency under targeted edits. The proposal asked for comparison against batch re-elaboration; the evaluation also compares against Lean 4 on synthetic programs of varying dependency shape.
