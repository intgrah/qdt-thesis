== Development methodology

The elaborator was built in three phases, each validated against example code before moving to the next. The first phase implemented a batch elaborator for the core theory: Pi types, Tarski universes, bidirectional checking against the declarative rules of @sec:calculus. The second phase added inductive types and structures, including generated recursors with their $iota$-reduction rules and structure projections with $eta$. The third phase introduced the incremental query architecture: per-declaration queries, fingerprint-based memoisation, and the formalised `Build` interface in Lean 4.

Each phase used a corpus of qdt code as its acceptance test, lifted in part from mathlib and Lean 4's prelude. Adding a feature meant adding a file exercising it; the elaborator was not declared complete on that feature until the file elaborated cleanly.

=== Version control and testing

The codebase is a single Git repository hosted on GitHub. The dissertation is a separate Typst repository, also on GitHub. Both have continuous integration: every commit to the elaborator runs `lake build`, which type-checks all Lean sources, elaborates the example corpora, and runs the test suite. The dissertation's CI compiles `main.typ` with Typst.

Correctness testing has three layers. The first is type-checking of the Lean sources themselves: dependent types catch a substantial fraction of bugs before the elaborator is ever run. The second is a suite of focused tests in `Qdt/Test/` (12 files) exercising specific elaborator features in isolation. The third is `Qdt/Lsp/Test.lean`, an incremental test harness that simulates editor interactions and asserts on diagnostics and hovers after targeted edits. The harness covers swapping definitions, renaming, moving definitions between files, and cyclic imports. Additional suites include Church-encoded normalisation benchmarks.

=== Tooling

Development used VSCode with the official Lean 4 extension, Lake as the build system, and a C FFI for the performance-critical Shake implementation. Lean's macro system embeds qdt programs directly in Lean source files as inline test cases: qdt's surface syntax is a subset of Lean 4's, so a Lean macro produces a qdt source string that the elaborator processes in place. The macros also surface diagnostics inline, so test cases fail at compile time rather than at test-run time.

A `qdt-lsp` VSCode extension was developed alongside the elaborator. It connects to the elaborator's language-server process via the standard Language Server Protocol; the protocol defines diagnostic and hover messages independently of the elaborator. The same extension is used to write qdt code during development, so the LSP path is exercised continuously.

All software used in development is open-source and permits educational use: Lean 4 (Apache 2.0), Lake (Apache 2.0), VSCode (MIT for OSS build), Typst (Apache 2.0).

== Starting point

I had implemented type checkers for simply typed languages before, but never a dependently typed elaborator and never a build system. Type theory I knew from coursework and from using Lean 4 as a proof assistant; I had not used Lean 4 as a general-purpose programming language, nor written a project of this scale in any dependently typed setting.

No implementation code was written before the project began. The project was initially planned in Rust, on top of the Salsa framework. After two weeks the Rust prototype was abandoned for OCaml — closures and algebraic datatypes were friendlier than Rust's borrow checker for a tree-walking elaborator. After a further three weeks the OCaml prototype was abandoned for Lean 4, motivated by the wish to have the build system's correctness proofs live in the same language as the elaborator, with shared types and definitions. Both prototypes were discarded; no code from them remains.

No existing codebases were used as a basis. Three references were consulted in detail. Kovacs's _smalltt_ @kovacs2023smalltt provided the design of approximate conversion checking — the rigid/flex/full state machine — and the glued-evaluation representation of constants. Fredriksson's _sixty_ @fredriksson2019sixty provided the motivating example of a query-based dependently typed elaborator and exhibited the kinds of queries to decompose elaboration into. Lean 4's own source provided the surface syntax, the convention for recursor generation, and the reference behaviour for the elaboration of inductive declarations.
