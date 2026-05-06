== Development methodology

The elaborator was built in three phases: a batch elaborator for the core theory (Pi types, universes, bidirectional checking), then inductive types and structures, then the incremental query architecture. Each phase was validated against the standard library before moving to the next.

=== Version control and testing

The codebase is in Git with GitHub as the remote. The dissertation is a separate Typst repository.

The primary correctness test is the standard library: 2,200 lines across 36 files, re-elaborated from scratch on every run. Equality proofs serve as integration tests for the conversion checker. A test harness (`Qdt/Lsp/Test.lean`) simulates editor interactions --- setting file contents, triggering rebuilds, asserting on diagnostics and hovers --- covering pathological incremental scenarios (swapping definitions, renaming, moving between files). Additional suites include Church-encoded normalisation benchmarks and a port of the Lean 2 HoTT library.

The build system's correctness proofs (Busy, LessBusy, Shake) replace testing of the incremental layer: any inhabitant of `Build` is correct by construction.

=== Tooling

Development used VSCode with the Lean 4 extension, Lake as the build system, and a C FFI for the performance-critical Shake implementation. Lean's macro system embeds qdt programs directly in Lean source files as inline test cases, since qdt's syntax is a subset of Lean's.

== Starting point

I had experience implementing type checkers for simply typed languages, but had not built a dependently typed elaborator or a build system. I was familiar with type theory and had used Lean 4 as a proof assistant, but not as a general-purpose programming language.

No code was written before the project started. The project was initially planned in Rust, but I switched early to OCaml, then to Lean 4. No existing codebases were used as a basis; I consulted smalltt, sixty, and Lean 4's source as references.
