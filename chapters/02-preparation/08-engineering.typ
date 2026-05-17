#import "common.typ": *

== Software engineering practices <sec:engineering>

// TODO the dependency order
Since each layer depends on those below it, we chose to develop the project bottom-up by dependency order: the core calculus and conversion checker first, then normalisation by evaluation, then the bidirectional type checker, then the inductive-type compiler, then the incremental layer, then the language server, and finally the formal verification of the build system. Each layer was developed against small targeted examples before being scaled to the full corpus. smalltt @kovacs2023smalltt was consulted as a reference for "glued" conversion checking.

=== Version control and tooling

Source code and dissertation are tracked in Git, with the repository hosted on GitHub. The Lean toolchain `Lake` manages the build and dependencies; `mathlib` @mathlib2020 is the only explicitly required package, with the Lean community `Cli` library and others pulled in transitively. The language server is built against modules from `Lean.Data.Lsp`, and the command-line interface against `Cli`. Tests are defined inline in Lean's _interactive_ mode using the `#eval`, `#guard_msgs`, and `#guard` directives and custom _meta-programming_ features (@sec:correctness-eval).

=== Language choice <sec:language-choice>

The proposal named Rust on top of Salsa. At the start of implementation the decision was revisited; Lean 4 and OCaml were considered alongside. Lean 4 was chosen for three reasons. The query layer is dependently typed (`Val : Key → Type`): Lean expresses this directly, Rust has neither dependent types nor GADTs (generalised algebraic data types, whose constructors specialise the type parameter), and OCaml has GADTs but is not dependently typed and so cannot express proofs. One project aim is a machine-checked correctness proof relating cached and batch elaboration; in Lean the implementation and its proof live in the same project. Lean's macros embed qdt programs directly as inline test cases.

The Salsa framework was replaced by a polymorphic-Task framework written in Lean (@sec:requires).

=== Licensing

Our code is licensed under #link("https://www.apache.org/licenses/LICENSE-2.0")[Apache 2.0], which is aligned with the Lean ecosystem. As discussed in @sec:cold-eval, we export and translate code from the Lean 2 HoTT library @lean2hott. This library is also licensed under Apache 2.0, which permits re-use, and we include the relevant attribution.
