= Conclusion <ch:conclusion>

== Summary

We have presented an incremental, query-based elaborator for a dependently typed language, implemented in Lean 4. The elaborator supports dependent function types, a hierarchy of Tarski-style universes with universe polymorphism, and inductive types with recursors. Elaboration is decomposed into fine-grained queries managed by a Shake-based build system, so that editing a single definition recomputes only the queries that depend on it.

The build system framework is formalised in Lean 4, refining the "Build Systems à la Carte" framework with a type-level separation of inputs from queries and well-founded termination of the dependency relation. The elaborator itself uses normalisation by evaluation for efficient term reduction and an approximate conversion checker with rigid/flex/full modes to bound backtracking.

TODO: summarise evaluation results.

== Future work

Several directions remain open:

- *Metavariables and implicit arguments.* The current system requires all terms to be fully explicit. Adding metavariables with pattern unification would make the surface language significantly more usable.
- *Parallelism.* The build system framework supports a base monad parameter that could be instantiated with IO for parallel query evaluation. This would allow independent queries to be elaborated concurrently.
- *Cancellation.* A language server should be able to cancel in-progress elaboration when the user edits the file again. The middleware framework could support this via an exception monad that preserves partial progress in the memo store.
