#import "common.typ": *

== Software engineering practices <sec:engineering>

=== Development methodology

The project decomposes into modular components: the elaborator, the build system, verification, corpora, and effect layers. Extensions to these were largely orthogonal, which made the spiral model of software development @boehm1988spiral a natural fit. The elaborator and the polymorphic-`Task` build system came first, each delivering a usable artefact (an elaborator passing feature programs; a cached executor running it) before the next iteration began. Verification of the agreement theorem, evaluation corpora, and the effect-layer extensions followed in subsequent iterations. Within an iteration, priority went to items on the path to a success criterion of the proposal. Risk was assessed by whether a feature had a published implementation or specification (low risk: bidirectional checking, normalisation by evaluation, BSALC's polymorphic `Task`) or required novel work (higher risk: structural parametricity certificates). Debug instrumentation for the build framework, specifically, query tracing, was prioritised early for ease of development.

=== Version control and tooling

Source code and dissertation are tracked in Git, with the repository hosted on GitHub. The Lean toolchain `Lake` manages the build and dependencies; `mathlib` @mathlib2020 is the only explicitly required package, with the Lean community `Cli` library and others pulled in transitively. The language server is built against modules from `Lean.Data.Lsp`, and the command-line interface against `Cli`.

=== Code style

Despite Lean having no canonical formatter, we strive for consistent style across the codebase. Where the type system can enforce an implementation invariant, we let it: terms and types are intrinsically well-scoped, indexed by the number of binders they preserve, so out-of-bounds access is a type error. Tests are defined inline using Lean's `#eval`, `#guard_msgs`, and `#guard` directives and custom meta-programming (@sec:correctness-eval), elaborating through the same code path users invoke rather than against a parallel harness.

=== Language choice <sec:language-choice>

The proposal named Salsa @salsa2018 in Rust as the incremental substrate. At the start of implementation the decision was revisited; Lean 4 and OCaml were considered alongside. Lean 4 was chosen for three reasons. The query layer is dependently typed (`Val : Key → Type`): Lean expresses this directly, Rust has neither dependent types nor GADTs (generalised algebraic data types, whose constructors specialise the type parameter), and OCaml has GADTs but is not dependently typed and so cannot express proofs. One project aim is a machine-checked correctness proof relating cached and batch elaboration; in Lean the implementation and its proof live in the same project. In addition, Lean's meta-programming features and introspectability of its own compiler made it easy to prototype ideas, and to write tests.

Salsa was therefore replaced by a polymorphic-`Task` abstraction @mokhov2018build written in Lean (@sec:requires). A Salsa-style inhabitant is retained as a stretch deliverable, running against the same `Tasks` value for comparison.

=== Licensing and open source

Our code is licensed under the open source #link("https://www.apache.org/licenses/LICENSE-2.0")[Apache 2.0] license, which is aligned with the Lean ecosystem. As discussed in @sec:cold-eval, we patch the Lean 2 compiler, which is itself Apache 2.0, to add common-subexpression elimination in order to translate the Lean 2 HoTT library @lean2hott efficiently. Apache 2.0 permits this modification and redistribution; hence, we retain the copyright headers, enumerate the modified files, and include the relevant attribution in a NOTICE file.
