= Conclusion <ch:conclusion>

All original aims were met. The elaborator supports the full intended type theory --- dependent function types, Tarski-style universes with universe polymorphism, and inductive types with recursors --- and successfully elaborates a 2,300-line standard library. The build system framework is formalised in Lean 4 with machine-checked correctness proofs: three build systems inhabit the same verified `Build` type. Incremental re-elaboration avoids redundant work, and early cutoff prevents re-elaboration when a definition's type is unchanged.

Several extensions were completed beyond the original proposal. The proposal specified using the Salsa framework as a black box; instead, the build system was formalised from scratch with machine-checked correctness proofs. The elaborator implements glued evaluation and approximate conversion checking (rigid/flex/full), which reduce the number of dependencies recorded in the query graph. A language server with diagnostics and hover information was added. Structures with projections and eta-expansion were added to support the standard library's algebraic hierarchy.

TODO: summarise evaluation results.

== Reflections

=== Choosing Lean 4

The project was initially planned in Rust (using the Salsa framework), initially implemented in OCaml, and finally settled on Lean 4. Each transition was costly. Lean's dependent types allow intrinsically scoped terms (`VTm n`), dependently-typed query results (`Val : Key -> Type`), and proof-carrying build systems (`{ r // r = compute ... }`). The build system correctness proofs live in the same language as the implementation, so the types that the elaborator manipulates are the same objects the proofs reason about. 
== Future work

- *Parallelism.* Mokhov et al. @mokhov2019selective introduce _selective functors_, a type class sitting between `Applicative` and `Monad`. Applicative tasks have statically known dependencies and can be parallelised; monadic tasks have dynamic dependencies discovered at runtime. Selective tasks sit between: they can conditionally skip branches but cannot use one result to determine what to fetch next. Incorporating selective tasks would allow the build system to parallelise queries with static dependencies (e.g. parsing independent files) while retaining dynamic dependencies where needed (e.g. elaboration that discovers references at runtime).
- *Cancellation.* A language server should cancel in-progress elaboration when the user edits again. A middleware framework could support this via an exception monad that preserves partial progress in the memo store.
- *Pattern matching.* The core theory uses recursors directly. A pattern-matching compiler translating case trees to recursor applications would make the surface language more practical without changing the core.
