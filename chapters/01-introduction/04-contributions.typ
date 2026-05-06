== Contributions

- A formalisation of the "Build Systems à la Carte" framework in Lean 4, refined with dependent query types (`Val : Key -> Type`), a separation of inputs from queries, and a well-foundedness condition on the dependency relation. Three build systems --- Busy (batch), LessBusy (memoising), and Shake (incremental) --- are proved correct: their results equal batch evaluation by construction.
- An incremental elaborator for a dependently typed language supporting dependent function types, a hierarchy of Tarski-style universes with universe polymorphism, inductive types with recursors, and structures with projections. Elaboration is decomposed into per-declaration queries executed by the formalised build system.
- An evaluation on a standard library and synthetic benchmarks, comparing incremental re-elaboration against batch elaboration and against Lean 4.
