#import "../../template.typ": metrics, num

== Repository overview <sec:repository>

The repository follows the standard structure of a Lean 4 project, with `lakefile.lean` at the root and a top-level `.lean` file re-exporting each module. The two principal modules are `Qdt/` (the elaborator and language server) and `Incremental/`, the build system framework, which is independent of the elaborator.

#set par(justify: false)
#set text(hyphenate: false)

#table(
  columns: (3.7cm, 3.3cm, 1fr, 1.7cm),
  align: (left + horizon, left + horizon, left + horizon, right + horizon),
  stroke: 0.4pt,
  table.header([*Directory*], [*Files*], [*Description*], [*LoC*]),

  [`Incremental/`],
  [`Basic`, `FreeMonad`, `Busy`],
  [Task abstraction, build configurations, fetch primitive],
  [#num(metrics.rows.incremental)],

  [`Incremental/Shake/`],
  [`Standard`, `StandardRdeps`, `Cancel`, `C`],
  [Shake variants: Lean, rdeps-augmented Lean, effectful, and C versions],
  [#num(metrics.rows.incremental_shake)],

  [`Incremental/Test/`],
  [`Fibonacci`, `Triangle`],
  [End-to-end tests against concrete task graphs],
  [#num(metrics.rows.incremental_test)],

  [`Incremental/c/`],
  [`shake.c`, `salsa.c`],
  [C implementations of Shake and Salsa],
  [#num(metrics.rows.incremental_c)],

  [`Qdt/Theory/`],
  [`Syntax`, `Universe`, `Global`],
  [Core syntax, universe levels, global environment],
  [#num(metrics.rows.qdt_theory)],

  [`Qdt/Frontend/`],
  [`Parser/Core`, `Desugar`],
  [Parser to CST and lowering to AST with source map],
  [#num(metrics.rows.qdt_frontend)],

  [`Qdt/`],
  [`Bidirectional`, `Nbe`, `Conversion`],
  [Bidirectional type checking, normalisation by evaluation, conversion checking],
  [#num(metrics.rows.qdt)],

  [`Qdt/Incremental/`],
  [`Query`, `Rules`],
  [Query types and elaboration task rules],
  [#num(metrics.rows.qdt_incremental)],

  [`Qdt/Test/`], [`Universes`, `Trunc`, `Quotient`], [Inline elaborator tests], [#num(metrics.rows.qdt_test)],

  [`Qdt/Lsp/`], [`Swap1`, `CrossFile`, `ImportCycle`], [Scripted edit session tests], [#num(metrics.rows.qdt_lsp)],

  [`FSWatch/`], [`Manager`, `INotify`], [File system watcher], [#num(metrics.rows.fswatch)],
  [`vscode-qdt/`], [`src`, `syntaxes`], [VS Code client], [#num(metrics.rows.vscode)],
  [`examples/lean2-hott/`],
  [`Lean2Export`, `port.sh`],
  [Lean 2 HoTT library porter],
  [#num(metrics.rows.examples_lean2hott)],

  [`examples/`], [`stdlib`, `long`], [Example code and synthetic benchmarks], [#num(metrics.rows.examples_other)],

  [`bench/`], [`cold`, `incremental`, `conversion`, `variants`], [Benchmark drivers and conversion-checker variants], [#num(metrics.rows.bench)],

  [`.`], [`Main`, `Lsp`, `lakefile`], [CLI and LSP entry points; build config], [#num(metrics.rows.root)],
)
