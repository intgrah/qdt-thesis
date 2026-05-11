== Correctness

The standard library exercises the full pipeline: parsing, bidirectional checking, NbE, conversion, universe polymorphism, inductives, and recursors. Equality proofs such as `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeed only if iota-reduction through `Nat.rec` computes correctly.

=== Lean 2 HoTT library

A larger correctness test is the port of the Lean 2 HoTT library @lean2hott. A Lean 4 exporter (`Lean2Export.lean`) reads the original `.hlean` files via Lean 2's binary export format and emits qdt source. The result is 23 files, 4,375 lines covering homotopy-theoretic constructions: path types, equivalences, function extensionality, Hedberg's theorem, well-founded recursion. The elaborator processes the entire port.

=== Incremental test harness

`Qdt/Lsp/Test.lean` simulates sequences of editor interactions and checks that diagnostics and hovers match from-scratch elaboration after each edit.
