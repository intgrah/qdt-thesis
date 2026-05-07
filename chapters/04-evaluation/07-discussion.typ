== Discussion

The incremental results demonstrate that the query-based architecture achieves its goal: after an edit, re-elaboration time is proportional to the amount of work that actually changed, not the size of the file or the number of dependents. The 6--8$times$ speedup over cold build on the standard library reflects the fact that most queries are unchanged after a typical edit.

The scaling benchmarks show that qdt's per-definition elaboration cost is competitive with Lean 4 (which additionally performs kernel checking). The conversion checker scales linearly on Church-encoded benchmarks, with a constant-factor gap from the defunctionalised closure representation.

The formal verification ensures that incremental results are provably equivalent to batch evaluation. The free theorem bridges the gap between the memoising build systems and the specification, with all proof obligations discharged except the parametricity axiom.
