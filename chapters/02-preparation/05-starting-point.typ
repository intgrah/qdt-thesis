== Development methodology

The elaborator was built in three phases: a batch elaborator for the core theory (Pi types, universes, bidirectional checking), then inductive types and structures, then the incremental query architecture. Each phase was validated against the example code, including a small "standard library" before moving to the next.

=== Version control and testing

The codebase is hosted on GitHub. The dissertation is a separate Typst repository, also on GitHub. Commits to the elaborator are checked by `lake build` in CI; the stdlib and test suites run as part of the build.

The primary correctness test is the standard library, re-elaborated from scratch on every run. It includes well-founded recursion, the Ackermann function, proof irrelevance of accessibility predicates, and an algebraic hierarchy through commutative groups. A test harness (`Qdt/Lsp/Test.lean`) simulates editor interactions and asserts on diagnostics and hovers after targeted edits. It covers swapping definitions, renaming, moving definitions between files, and cyclic imports. Additional suites include Church-encoded normalisation benchmarks.

=== Tooling

Development used VSCode with the Lean 4 extension, Lake as the build system, and a C FFI for the performance-critical Shake implementation. Lean's macro system embeds qdt programs directly in Lean source files as inline test cases, since qdt's syntax is a subset of Lean's.

== Starting point

I had experience implementing type checkers for simply typed languages, but had not built a dependently typed elaborator or a build system. I was familiar with type theory and had used Lean 4 as a proof assistant, but not as a general-purpose programming language for a project of this scale.

No code was written before the project started. The project was initially planned in Rust, but I switched early to OCaml, then to Lean 4. No existing codebases were used as a basis; I consulted smalltt, sixty, and Lean 4's source as references.
