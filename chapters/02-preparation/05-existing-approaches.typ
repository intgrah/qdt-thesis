#import "common.typ": *

== Existing approaches <sec:existing-approaches>

Production proof assistants (Lean 4, Agda, Rocq) invalidate at the file boundary. Declaration-level dependency tracking is established in adjacent settings, such as Salsa @salsa2018 for the rust-analyzer language server @matklad2020rust_analyzer, and has been attempted experimentally for dependent types in Sixty @fredriksson2019sixty. This section describes each.

The general vocabulary of incremental computation @liu2024essence is fixed first. A _query_ is a pure function from a key to a value, registered with a runtime that memoises its result. For each completed query the runtime records the value and the keys it fetched as dependencies; the dependency graph is built when the query runs, not declared upfront. Queries come in two kinds. _Input queries_ have no recipe; their values are set externally. _Derived queries_ are pure functions of other queries, fetched on demand. When an input changes, the runtime marks transitively dependent derived queries potentially stale; when a stale query is recomputed, its new value is compared against the cached one, and if they agree the cascade stops. This is _early cutoff_. Together these give recomputation proportional to the affected fragment.

Two threads of incremental computation supply the vocabulary used in the systems below. Self-adjusting computation @acar2002adaptive maintains a dependency trace; Adapton @hammer2014adapton refines it with demand-driven memoisation. Make @feldman1979make is the dirty-bit ancestor: a target rebuilds when an input's modification timestamp is newer, with no early cutoff. The terms _demand_, _dirtying_, and _cleaning_ are taken from this lineage.

Incremental type checking has been studied at simpler scales than dependent type theory. @meertens1983incremental gave a per-definition algorithm for polymorphism in the B language; @aditya1991incremental did the same for Hindley-Milner inference in Id. @erdweg2015cocontextual recast type rules to propagate requirements bottom-up rather than contexts top-down, allowing per-expression memoisation on PCF. @pacak2020systematic compile inference rules to Datalog and let the Datalog runtime handle re-evaluation. @porter2025incremental use order-maintenance data structures to propagate edits per-expression in bidirectional checking on the simply-typed lambda calculus with gradual types.

=== Prefix elaboration <sec:conservative>

Lean 4 @demoura2021lean, Agda @norell2009agda, and Rocq @coq2024 elaborate top to bottom, accumulating a global environment. The cache key is the program prefix up to position $p$; an edit before $p$ invalidates the cache. Lean represents this as a snapshot tree per file @ullrich2023extensible; Agda caches each successful declaration; Rocq re-checks from the first modified sentence. Across files the granularity is coarser: any change to an imported module invalidates the importer.

_Elaboration_ turns a command#footnote[A _command_ is a definition, inductive type, axiom, or similar.] into a kernel constant via name resolution, unification, typeclass resolution, coercion insertion, and conversion checking under definitional equality (@sec:fragment). The global environment is the only channel by which one declaration sees another; the elaborator does not record which earlier declarations are relevant, so every declaration nominally depends on the entire prefix.

=== Declaration-level invalidation in adjacent settings <sec:declaration-level>

Salsa @salsa2018 is a Rust framework for on-demand query evaluation. The programmer declares queries and their dependencies in a database trait, and the framework generates the storage, memoisation, and invalidation logic. rust-analyzer @matklad2020rust_analyzer, the language server for Rust, uses Salsa to implement its analysis pipeline as a query graph. Edits update input queries; IDE requests (hover, completion, find references) are derived queries that read from the cache.

In Rust, the type signature is the compilation boundary: a body edit cannot change the type-checking of any other function, because the elaborator only needs the callee's signature to check the caller. Salsa keys its caches by the signature; a body edit invalidates the cache for the edited function only. In dependent type theory the boundary is different. The conversion rule allows declaration $N$'s elaboration to $delta$-unfold the body of an earlier declaration $M$; if $M$'s body changes, $N$'s elaboration result may change even though $M$'s signature does not. The dependency from $N$ to $M$ is on whichever $delta$-reductions $N$'s conversion checks perform, discovered as elaboration runs.

Sixty @fredriksson2019sixty is an experimental Haskell elaborator for a dependently typed language. It records the constants its conversion checker unfolds and uses that record for invalidation. The cache is in-memory within a single language-server process.
