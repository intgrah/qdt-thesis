== Related work

=== Efficient elaboration

Kovacs's _smalltt_ @kovacs2023smalltt combines higher-order abstract syntax, glued evaluation, and approximate conversion checking, achieving type-checking speeds that outperform production systems. I adopted approximate conversion checking and glued evaluation from it.

=== Lean 4

Lean 4 @moura2021lean is the primary reference for surface language and inductive types. Our elaborator supports the same declaration forms (`def`, `inductive`, `structure`, `axiom`) and recursor-based elimination. The core theory departs from Lean's kernel in using Tarski-style universes and omitting metavariables and implicit arguments.

=== Self-adjusting computation and Adapton

The theoretical ancestor of fine-grained incremental computation is _self-adjusting computation_ @acar2002adaptive, which tracks data dependencies at runtime and propagates changes through a dependency graph. Adapton @hammer2014adapton refines this with demand-driven evaluation: computations are re-executed only when their results are demanded. The "Build Systems à la Carte" framework @mokhov2018build applies these ideas at the granularity of named build targets rather than individual memory cells; our formulation inherits this coarser granularity.

=== Salsa

Salsa @salsa2018 is a Rust framework for on-demand, incrementalised computation, used by rust-analyzer @matklad2020rust_analyzer for incremental type checking of Rust. It implements query-based incrementality with memoisation and early cutoff, similar to the Shake cell. I target a dependently typed language, where conversion checking blurs the boundary between signatures and bodies, and provide a formal correctness proof.

=== Sixty

Fredriksson's _sixty_ @fredriksson2019sixty applies query-based incrementality to a dependently typed language, using a Haskell library inspired by BSALC. I formalise the build system in Lean 4 with a machine-checked correctness proof, and implement the elaborator in the same language, so the two share types and definitions.
