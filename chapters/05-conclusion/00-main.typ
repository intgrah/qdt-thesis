= Conclusion <ch:conclusion>

== Summary

This project built an incremental elaborator for a dependently typed language, with a formalised build system guaranteeing that incremental results agree with batch elaboration.

== Returning to the claims

The introduction made four claims. I revisit each:

+ _Existing systems re-check entire file suffixes after an edit_ (@sec:incremental-eval). The incremental elaborator avoids this: changing `Nat.add`'s body in a file imported by five others triggers re-elaboration of only the affected queries. Early cutoff prevents the cascade from propagating when a recomputed result hashes the same.

+ _No mainstream proof assistant uses query-based incrementality._ This remains true. The project demonstrates that query-based incrementality is viable for a dependently typed language, with per-declaration granularity and dynamic dependency tracking.

+ _Fredriksson's Sixty does not formalise the underlying build system._ The formalised build system framework (@sec:verification) fills this gap.

TODO: refcounting overhead conclusion

+ _The dependency structure is discovered dynamically during elaboration._ Glued evaluation and approximate conversion checking (@sec:conv) reduce the dependencies recorded: flex-mode comparison avoids fetching definition bodies, and early cutoff prevents propagation when results are unchanged.

== Extensions beyond the proposal

The original proposal specified using the Salsa framework as a black box. Instead, the build system was formalised from scratch. Glued evaluation and approximate conversion checking were added. A language server with diagnostics and hover was implemented. Structures with projections and eta-expansion were added.

== Lessons learnt

*Language pivots.* The project moved from Rust to OCaml to Lean 4. Each transition was costly, but Lean's dependent types proved essential: intrinsically scoped terms (`VTm n`), dependently typed query results (`Val : Key -> Type`), and proof-carrying build systems (`{ r // r = compute ... }`) would have required unsafe casts or boilerplate in the other languages.

*Verification methodology.* The free theorem is stated as an axiom in Lean because parametricity cannot be proved internally. This is a limitation of the formalisation, but the axiom is well-established in the literature (Reynolds, Wadler, Voigtlander, Atkey) and its use is confined to a single lemma.

*Performance.* The elaborator is approximately 100x slower than smalltt on normalisation-heavy benchmarks, due to Lean's reference-counting runtime overhead on closure-heavy code. This is a constant factor; the asymptotic behaviour is the same. For interactive use, the incremental rebuild avoids most of this cost.

== Future work

- *Parallelism.* Mokhov et al. @mokhov2019selective introduce _selective functors_, sitting between `Applicative` and `Monad`. Selective tasks could allow the build system to parallelise queries with static dependencies (e.g. parsing independent files) while retaining dynamic dependencies for elaboration.
- *Cancellation.* A language server should cancel in-progress elaboration when the user edits again. A middleware framework could support this via an exception monad that preserves partial progress in the memo store.
- *Pattern matching.* The core theory uses recursors directly. A pattern-matching compiler translating case trees to recursor applications would make the surface language more practical without changing the core.
