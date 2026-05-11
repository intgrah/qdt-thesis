== Correctness

The elaborator is exercised on two corpora and three test suites. The corpora are the targets the elaborator is *intended* to process: real qdt code that should elaborate cleanly. The test suites probe individual features and the incremental layer, with assertions that pin down expected behaviour.

=== Corpora

A handwritten qdt corpus covers arithmetic, equality, well-founded recursion, sigma types, monadic abstractions, and an algebraic hierarchy through commutative groups. The content is lifted in part from mathlib and Lean 4's prelude. Both this corpus and the lean2-hott port exercise the full pipeline: parsing, bidirectional checking, NbE, conversion, universe polymorphism, inductives, and recursors. Equality proofs such as `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeed only if $iota$-reduction through `Nat.rec` computes correctly.

The non-HIT subset of the Lean 2 HoTT library @lean2hott is ported into qdt by `Lean2Export.lean`, which reads `.hlean` files via Lean 2's binary export format and re-emits the declarations as qdt source. The port comprises 23 files and 4,375 lines. The exporter does not handle higher inductive types, so quotient types, truncations, and the cubical machinery are omitted; what remains is the path machinery, equivalences, function extensionality, Hedberg's theorem, and well-founded recursion. Elaborating this corpus stresses universe polymorphism (every Lean 2 HoTT definition is universe-polymorphic) and the recursor machinery (the library is recursor-heavy by design, since pattern matching in Lean 2 desugars to recursor applications).

=== Unit tests

`Qdt/Test/` contains 12 focused tests, each exercising one elaborator feature in isolation: accessibility predicates and well-founded recursion (`Acc`, `MLTT`), propositional equality (`Eq3`), eta-conversion (`Eta`), inductive indices (`Indices`), parameter handling (`Params`), strict positivity (`Positivity`), structure projections (`Projection`), return-type inference (`ReturnType`), universe handling (`Universes`), and weak head reduction of applications (`WhnfApp`).

=== Incremental test harness

`Qdt/Lsp/Test/` contains 17 incremental scenarios driven by a harness in `Qdt/Lsp/Test.lean` that simulates editor interactions. Each test sequences `setText` calls against a virtual file system, triggers a rebuild through the query system, and asserts on diagnostics and hovers against the resulting state. The scenarios cover the editing patterns that batch elaboration would not exercise: adding and removing imports (`AddRemoveImport`), atomically moving a definition between files (`AtomicMove`), editing a definition's body without changing its type (`BodyEdit`) versus editing its type (`TypeEdit`), cross-file dependency invalidation (`CrossFile`), import cycles (`ImportCycle`), name collisions (`NameCollision`), parser errors and recovery (`ParserError`, `SyntaxRecovery`), renaming and the resulting unbound-variable diagnostics (`Rename`), structure-field parameter shadowing (`StructureFieldParam`), swapping definitions so forward references become backward (`Swap1`, `Swap2`), no-op edits (`Touch`), and whitespace-only edits (`Whitespace`).

=== Axiom audit

`#print axioms` on the build system theorems reduces to two axioms: `Task.freeTheorem`, which states the parametricity property used to prove that memoising and pure semantics agree (@sec:free-theorem); and the injectivity of the hash functions, which makes fingerprint comparison sound. `Classical.choice` is not used: parametricity in Lean is incompatible with choice, and the formalisation avoids choice throughout. The elaborator itself uses `sorry` only in the well-foundedness witnesses for the dependency relation in `Qdt/Incremental/Rules.lean`; the well-foundedness is asserted, not proved, and the incremental test harness validates it empirically.
