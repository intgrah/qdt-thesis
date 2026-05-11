== Discussion

The incremental results demonstrate that the query-based architecture achieves its goal: after an edit, re-elaboration time is proportional to the amount of work that actually changed, not the size of the file or the number of dependents. The 6--8$times$ speedup over cold build reflects the fact that most queries are unchanged after a typical edit.

The scaling benchmarks show that qdt's per-definition elaboration cost is competitive with Lean 4. The conversion checker scales linearly on Church-encoded benchmarks, with a constant-factor gap from the defunctionalised closure representation.

The formal verification ensures that incremental results are provably equivalent to batch evaluation. The free theorem bridges the gap between the memoising build systems and the specification, with all proof obligations discharged except the parametricity axiom.

=== Threats to validity

The Lean 4 comparison is not like-for-like. Lean 4 performs kernel checking after elaboration; qdt does not. Lean 4 supports implicit arguments, metavariables, and unification; qdt requires explicit type information. Lean 4's elaborator is mature and optimised; qdt's is a first implementation. The numbers reported in @sec:scaling reflect these differences, not just the underlying algorithmic choices. Where qdt is faster, the gap is partly due to the absence of features.

The corpora are bounded. The handwritten qdt corpus and the lean2-hott port together exercise the elaborator on real code, but neither approaches the size of mathlib or the Lean 4 stdlib. Behaviour at corpus sizes an order of magnitude larger is extrapolated, not measured.

The incremental edits in @sec:incremental-eval are scripted, not recorded from real interactive sessions. They probe specific edit categories — no-op, whitespace, leaf addition, hub addition — that exercise the cache machinery, but the distribution of edits in actual interactive use is unknown.

=== Performance limitations

The defunctionalised closure representation costs a constant factor against HOAS. Each $beta$-reduction re-interprets the body in an extended environment, where HOAS would compile the closure to a native function call. Smalltt's reported numbers are an order of magnitude faster on normalisation-heavy benchmarks for this reason. The choice is forced: Lean 4's kernel rejects the non-strictly-positive inductive type that HOAS requires, and qdt's correctness proofs need the evaluator to live within the kernel's logic.

Lean's reference-counting runtime imposes overhead on closure-heavy code. Each closure allocation increments and decrements reference counts; the elaborator allocates closures for every binder it descends under. This overhead is not algorithmic, but it is real, and it accounts for a portion of the gap to smalltt that the defunctionalisation story alone does not explain.
