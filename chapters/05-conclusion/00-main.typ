= Conclusion <ch:conclusion>

== Summary

All five desiderata are met and exceeded. Watch-mode rebuilds track the affected fragment on every edit category. Cold and cached elaboration produce the same elaborated forms across every elaborator and language-server test, the dynamic trace coincides with the agreement proof's hit-or-miss decision on every fetch, and the agreement itself is mechanised in Lean 4 against a reference batch semantics. The same `Tasks` value drives five inhabitants without source change or rerun of the proof; the effect-layer extensions inherit the theorem through a free theorem.

== Lessons learnt

/ Reference counting and FBIP: Lean's runtime mutates persistent data in place when the refcount is one, which keeps `StateM Cache` hashmap inserts at O(1) when the store is threaded linearly through the build. A stray `let` that retains a second reference silently degrades the write to O(n); the symptom is a slow benchmark, not a type error.

/ Verification forces design clarity: More than one bug survived every test I wrote and only surfaced when a proof obligation refused to close. The proof is a sharper reader than I am; a `sorry` is a thumb on the scale.

/ Proof erasure: The entire correctness invariant of `Build` --- the `Value.spec` field, `WellFormed`, the `MonadAction.rel` axioms --- lives in `Prop` and is erased at runtime. Co-locating proof with code costs nothing, which is why structural agreement is architecturally viable in Lean and would not be in a language whose type system cannot carry it.

== Future work

/ Parallelism: Static dependencies (parsing, independent files) parallelise under the applicative fragment of @mokhov2018build's task abstraction directly; conditional dependencies fit under _selective functors_ @mokhov2019selective via speculative parallelism, sitting between applicative and monadic.

/ Type classes and coercions: Resolution requires a metavariable layer for the unification variables in instance heads. Tabled resolution @selsam2020tabled then treats each subgoal as a memoised query and its sub-subgoals as dependencies the framework already tracks @saha2003incremental; a resolver written through `pure`/`bind`/`fetch` inherits the parametricity certificate. How much of elaboration follows this pattern?

/ Tactics: The natural extension to tactic languages would treat each goal state as a memoised query keyed by input state and tactic syntax, invalidating only the script suffix after an edit.
