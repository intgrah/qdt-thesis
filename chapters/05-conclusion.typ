= Conclusion <ch:conclusion>

== Summary

I built an incremental, query-based elaborator for a dependently typed language in Lean 4, supporting dependent function types, Tarski-style universes with universe polymorphism, and inductive types with recursors. Editing a single definition recomputes only the queries that depend on it.

The build system framework is formalised in the same language, refining "Build Systems à la Carte" with type-level separation of inputs from queries and well-founded termination. The elaborator uses NbE and an approximate conversion checker with rigid/flex/full modes.

TODO: summarise evaluation results.

== Future work

Several directions remain:

- *Metavariables and implicit arguments.* All terms are currently fully explicit. Pattern unification would make the surface language much more usable.
- *Parallelism.* The build system's base monad could be instantiated with IO for parallel query evaluation, elaborating independent queries concurrently.
- *Cancellation.* A language server should cancel in-progress elaboration when the user edits again. The a framework that supported "middleware" could support this via an exception monad preserving partial progress.
