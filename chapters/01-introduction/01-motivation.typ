== Motivation

Lean's mathlib library @mathlib2020 contains over 130,000 definitions and 270,000 theorems.#footnote[#link("https://leanprover-community.github.io/mathlib_stats.html"), as of 2026-05-14.] A developer working inside mathlib edits a declaration and waits for the elaborator to re-check the affected work. While they wait, types appear as the cursor moves over a subterm, and diagnostics update as they type. Responsiveness depends on the elaborator producing fine-grained output, quickly.

Mainstream proof assistants invalidate everything in scope of the changed name: the suffix of the file from the change, and every file that imports it. This cost is paid even when no use actually depends on the change, because dependency tracking operates only at the granularity of module imports.

A finer scheme records, for each declaration, the constants its elaboration actually unfolded. This set cannot be precomputed from the syntax: a dependent type theory's _conversion rule_ decides at runtime which earlier definitions to unfold. Existing systems approximate at varying granularities. Wenzel's Isabelle/PIDE @wenzel2014pide and Lean's snapshot trees @ullrich2023extensible go to command-suffix within a file; Sixty @fredriksson2019sixty goes to per-declaration in memory within a language-server session.

Whatever the granularity, the incremental cache must agree with batch elaboration. A cache hit returning a value the elaborator's source code would not have produced is undetectable from interaction alone.

Precise invalidation requires recording the cross-declaration dependencies a conversion check discovers at runtime, which extends the trusted layer to include that record. Correctness requires a cache hit return what a fresh build would. No deployed system has met both.
