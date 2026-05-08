== This project

I apply that framework to elaboration. The elaborator decomposes its work into queries: "what is the type of this constant?", "what are the errors in this definition?", "what is the parsed AST of this file?", each memoised by a build system. When a definition changes, only the queries that transitively depend on it are reconsidered; if a recomputed result is unchanged, its dependents are not recomputed.

The elaborator supports dependent function types, Tarski-style universes with universe polymorphism, and inductive types with recursors, enough to elaborate a standard library of arithmetic, equality, well-founded recursion, and algebraic structures. The implementation is in Lean 4, and the build system framework is formalised in the same language: three build systems (batch, memoising, and incremental) are proven to agree with batch evaluation.
