== Development methodology

The elaborator was built in three phases: a batch elaborator for the core theory (Pi types, universes, bidirectional checking), then inductive types and structures, then the incremental query architecture. Each phase was validated against the example code, including a small "standard library" before moving to the next.

=== Version control and testing

The codebase is hosted on GitHub. The dissertation is a separate Typst repository, also on GitHub. Commits to the elaborator are checked by `lake build` in CI; the stdlib and test suites run as part of the build.

The primary correctness test is the standard library: 2,300 lines across 39 files, re-elaborated from scratch on every run. The stdlib includes well-founded recursion, the Ackermann function with its reduction lemmas, proof irrelevance of accessibility predicates, and an algebraic hierarchy of semigroups through commutative groups. Elaborating these exercises deep chains of iota-reduction through nested recursors, universe polymorphism at every step, and the full pipeline from parsing through conversion checking. A test harness (`Qdt/Lsp/Test.lean`) simulates editor interactions, setting file contents, triggering rebuilds, and asserting on diagnostics and hovers. It covers pathological incremental scenarios: swapping definitions so forward references become backward, renaming and checking that dependents report unbound variables, moving a definition between files, and cyclic imports. Additional suites include Church-encoded normalisation benchmarks.

The build system's correctness proofs (Busy, LessBusy, Shake) replace testing of the incremental layer: any inhabitant of `Build` is correct by construction.

=== Tooling

Development used VSCode with the Lean 4 extension, Lake as the build system, and a C FFI for the performance-critical Shake implementation. Lean's macro system embeds qdt programs directly in Lean source files as inline test cases, since qdt's syntax is a subset of Lean's.

== Starting point

I had experience implementing type checkers for simply typed languages, but had not built a dependently typed elaborator or a build system. I was familiar with type theory and had used Lean 4 as a proof assistant, but not as a general-purpose programming language for a project of this scale.

No code was written before the project started. The project was initially planned in Rust, but I switched early to OCaml, then to Lean 4. No existing codebases were used as a basis; I consulted smalltt, sixty, and Lean 4's source as references.
