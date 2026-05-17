= Conclusion <ch:conclusion>

== Summary

Chapter 1 asked whether an incremental elaborator's cache can be made provably equal to a fresh build. This thesis answers in the affirmative on a dependent type theory. A polymorphic build framework was mechanised in Lean 4; two cached inhabitants, LessBusy (intra-build memoisation) and Shake (persistent verifying traces), are proven to agree with a reference `compute` semantics defined by well-founded recursion. The elaborator on top of the verified framework handles Pi types, Sigma types, inductive types, universe polymorphism, structures with eta-conversion, and recursor-based elimination, and runs on subsets of the Lean 2 HoTT port. Incremental rebuilds across a range of edit categories run an order of magnitude faster than a cold build.

== Lessons learnt

/ Language pivots: The project moved from Rust to OCaml to Lean 4. Lean's dependent types were used in three places: intrinsically scoped terms (`Tm n`), dependently typed query results (`Val : Key -> Type`), and proof-carrying build systems (`{ r // r = compute ... }`). None of these invariants are expressible in the type systems of the other languages; they would have lived as runtime checks or unchecked conventions.

/ Performance: The elaborator is roughly two orders of magnitude slower than `smalltt` on normalisation-heavy benchmarks, which I believe is attributable to the defunctionalised closure representation. For interactive use, the incremental rebuild avoids most of this cost: edits that the user actually makes touch a small fraction of queries, and the closure-heavy work is amortised across cache hits.

/ Co-locating proofs and code: The `Build` type's correctness invariant is part of the type; an inhabitant cannot exist without a proof, so the build system's correctness is enforced at compile time. The elaborator's `tasks` value is the same value the proofs reason about; there is no gap between specification and implementation.

== Future work

/ Parallelism: Queries with static dependencies, such as parsing independent files, are already parallelisable under the applicative fragment of @mokhov2018build's task abstraction. _Selective functors_ @mokhov2019selective extend this to conditional dependencies via _speculative parallelism_: the dependency graph is over-approximated statically and unused branches are discarded at runtime. This would apply to queries whose dependencies depend on intermediate results, sitting between fully static (applicative) and fully dynamic (monadic) tasks.

/ Type classes and coercions: Instance heads carry unification variables (`ToString α → ToString (List α)` fires on `ToString (List Nat)` by solving `α := Nat`), so a metavariable layer is prerequisite. After that, tabled resolution @selsam2020tabled makes each subgoal a memoised entry; its recorded sub-subgoals are the dependencies the build framework already tracks for other queries, so an instance addition invalidates only the goals whose resolution consulted it @saha2003incremental. A resolver written through the framework's `pure`/`bind`/`fetch` primitives inherits the parametricity certificate, so agreement with the batch semantics extends without revisiting the proof.
