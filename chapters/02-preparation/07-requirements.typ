#import "common.typ": *

== Requirements analysis <sec:requirements>

The two success criteria of the proposal (#ref(<sec:proposal>, supplement: none)) translate into a small number of testable obligations. This section names them; #ref(<sec:engineering>, supplement: none) records how the components that discharge them are structured and developed.

=== Desiderata

I divide the obligations into five properties that the elaborator and its build substrate together must satisfy.

/ Correctness <rq:correctness>:
  The elaborated form of every declaration is the same whether the elaborator runs from cold or from a cached build. Tested by the elaborator test suite (#ref(<sec:correctness-eval>, supplement: none)); proved as a Lean 4 theorem for each cached inhabitant of `Build` (#ref(<sec:mechanised-inhabitants>, supplement: none)).

/ Incremental responsiveness <rq:responsiveness>:
  Re-elaboration time scales with the affected fragment, not with the size of the corpus. The build framework tracks cross-declaration dependencies discovered at conversion time, and reuses any cached entry whose recorded fingerprints still match. Measured against eight edit categories on a designed corpus and on slices of two stdlib corpora (#ref(<sec:incremental-eval>, supplement: none)).

/ Verifiability <rq:verify>:
  The build substrate is amenable to a machine-checked agreement theorem relating cached and batch elaboration. The agreement theorem is unconditional in the executor and depends only on `propext` and `Quot.sound` (#ref(<sec:mechanised-inhabitants>, supplement: none)).

/ Executor polymorphism <rq:polymorphism>:
  The elaborator is presented as a single value, independent of the cache strategy that executes it. Switching between `Busy`, `LessBusy`, and `Shake` requires no source change to the elaborator and no rerun of the agreement proof.

/ Effect orthogonality <rq:effects>:
  Tracing and cancellation are layered around the cache without revisiting the agreement proof. `ShakeTrace` and `ShakeCancel` inherit `Shake`'s agreement through the free theorem on `Tasks`.

=== Deviations from the proposal <sec:deviations>

Two changes between the proposal and the delivered project are recorded here in the interest of honest scoping.

/ Build framework: The proposal named the Salsa framework in Rust @salsa2018 as the incremental substrate. At the start of implementation the decision was revisited, and the framework was replaced with a polymorphic-Task abstraction in the style of @mokhov2018build, written in Lean 4 and instantiated with `Busy`, `LessBusy`, and `Shake`. The reasons (dependent result types, on-paper agreement proof, single-source elaborator) are recorded in #ref(<sec:language-choice>, supplement: none). A `Salsa` inhabitant retained as a stretch deliverable runs against the same `Tasks` value for comparison.

/ Pattern matching: The proposal listed pattern matching as a feature of the surface syntax. The implementation drops it; all case analysis is written through recursors directly. This narrows the language fragment but lets the inductive elaborator stay close to the kernel's own elimination form.
