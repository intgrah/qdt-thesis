#import "common.typ": *

== Existing approaches <sec:existing-approaches>

=== Prefix elaboration <sec:conservative>

Production proof assistants invalidate at the file boundary. Lean 4 @demoura2021lean, Agda @norell2009agda, and Rocq @coq2024 elaborate top to bottom, accumulating a global environment. The cache key is the program prefix up to position $p$; an edit before $p$ invalidates the cache. Lean represents this as a snapshot tree per file @ullrich2023extensible; Agda caches each successful declaration; Rocq re-checks from the first modified sentence. Across files the granularity is coarser: any change to an imported module invalidates the importer. The global environment is the only channel by which one declaration sees another, and the elaborator does not record which earlier declarations are relevant, so every declaration nominally depends on the entire prefix.

=== In adjacent settings <sec:declaration-level>

A _query_ is a pure function from a key to a value, registered with a runtime that memoises its result. For each completed query the runtime records the value and the keys it fetched as dependencies; the dependency graph is built when the query runs, not declared upfront. Queries come in two kinds. _Input queries_ have no recipe; their values are set externally. _Derived queries_ are pure functions of other queries, fetched on demand. When an input changes, the runtime marks transitively dependent derived queries potentially stale; when a stale query is recomputed, its new value is compared against the cached one, and if they agree the cascade stops. This is _early cutoff_. Together these give recomputation proportional to the affected fragment. The vocabulary is rooted in self-adjusting computation @acar2002adaptive and Adapton @hammer2014adapton, with _demand_, _dirtying_, and _cleaning_ taken from Make's lineage @feldman1979make.

Salsa @salsa2018 is a Rust framework for on-demand query evaluation along these lines. Its scheduling discipline is request-driven, with a dirty bit set on fetch and no verifying trace over the cache. The programmer declares queries and their dependencies in a database trait, and the framework generates the storage, memoisation, and invalidation logic. rust-analyzer @matklad2020rust_analyzer, the language server for Rust, uses Salsa to implement its analysis pipeline as a query graph. Edits update input queries; IDE requests (hover, completion, find references) are derived queries that read from the cache.

In Rust, the type signature is the compilation boundary: a body edit cannot change the type-checking of any other function, because the elaborator only needs the callee's signature to check the caller. Salsa keys its caches by the signature; a body edit invalidates the cache for the edited function only. In dependent type theory the boundary is different. The conversion rule allows declaration $N$'s elaboration to $delta$-unfold the body of an earlier declaration $M$; if $M$'s body changes, $N$'s elaboration result may change even though $M$'s signature does not. The dependency from $N$ to $M$ is on whichever $delta$-reductions $N$'s conversion checks perform, discovered as elaboration runs.

Sixty @fredriksson2019sixty is an experimental Haskell elaborator for a dependently typed language. It records the constants its conversion checker unfolds and uses that record for invalidation. The cache is in-memory within a single language-server process.

Incremental type checking has also been studied for simpler systems @meertens1983incremental @pacak2020systematic @porter2025incremental; the gap addressed in this thesis is doing so for a dependent type theory.
