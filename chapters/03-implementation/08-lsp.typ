== Language server <sec:lsp>

The elaborator doubles as a language server. Hover information and diagnostics are collected in `ElabState` during elaboration and served to a VSCode extension via LSP:

- *Diagnostics*: type errors, unbound variables, universe mismatches --- positioned via path indices into the AST.
- *Hover*: the type under the cursor, or the full signature of a referenced constant.

=== Incremental test harness

The test suite verifies incremental correctness via a harness simulating editor interactions:

- `setText text filepath` sets the contents of a file and triggers a full rebuild through the query system.
- `diagnostics check filepath` asserts that the diagnostics for a file satisfy a predicate.
- `hover pos expected start stop` asserts that hovering at a given position produces the expected content and source span.

Tests sequence multiple `setText` calls and check that diagnostics and hovers update correctly. The cases cover pathological incremental scenarios: swapping definitions so forward references become backward; renaming and checking that dependents report unbound variables; atomically moving a definition between files; and cyclic imports. These exercise dependency tracking, cache invalidation, and error recovery paths that batch elaboration would not stress.

== Repository overview

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, left, right, left),
    table.header([*Directory*], [*Purpose*], [*Lines*], [*Section*]),
    [`Incremental/`], [Build system framework (12 files): Task, Build, BuildConfig, Busy, LessBusy, Shake, Salsa, free theorem, plus ShakeCPS/ShakeEState/ShakeRdeps variants], [1,209], [2.3],
    [`Incremental/c/`], [C implementations of Shake and Salsa (2 files)], [1,141], [3.7],
    [`Qdt/Frontend/`], [Parser, CST, AST, desugarer (4 files)], [1,371], [3.2],
    [`Qdt/Theory/`], [Declarative type theory: syntax, contexts, typing rules, universes, substitution, weakening, alpha-equality (9 files)], [1,342], [2.1],
    [`Qdt/`], [Elaborator core (21 files): bidirectional checker, NbE, conversion, inductive/structure elaboration, quoting, control monad, query types, task rules, error handling, pretty printing, CLI], [2,804], [3.3--3.7],
    [`Qdt/Test/`], [Elaborator regression tests (12 files)], [610], [4.1],
    [`Qdt/Lsp/Test/`], [Incremental test harness + 17 test cases], [438], [3.8],
    [`FSWatch/`], [File system watcher for watch mode (4 files)], [361], [---],
    [`Main.lean`], [CLI entry point], [173], [---],
    [`Lsp.lean`], [Language server entry point], [330], [3.8],
  ),
  caption: [Source code by directory. Line counts computed with `wc -l`, excluding `.lake` and stdlib examples. Total: 9,779 lines of Lean + 1,141 lines of C.],
)
