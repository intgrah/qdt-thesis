== Incremental elaboration <sec:incremental>

Elaboration is decomposed into queries managed by a Shake-based build system. Each query has a tag and parameters; its result type is determined by the tag. `Key` has 17 cases; the principal ones:

```lean
inductive Key where
  | cst : FilePath → Key
  | ast : FilePath → Key
  | declarationIndex : FilePath → Key
  | elabCmdAt : FilePath → Nat → Key
  | elabDecl : FilePath → Name → Key
  | constant : FilePath → Name → Key
  | lookupInfo : FilePath → Name → Key
  -- ... others omitted

def Val : Key → Type
  | .cst _              => Cst × Array ParseError
  | .ast _              => Ast
  | .declarationIndex _ => HashMap Name Nat × Array Diagnostic
  | .elabCmdAt _ _      => Global × ElabInfo
  | .elabDecl _ _       => Option (Constant × Origin) × ElabInfo
  | .constant _ _       => Option (Constant × Origin)
  | .lookupInfo _ _     => ElabInfo
  -- ... others omitted
```

The principal queries:

- `declarationIndex`: maps declaration names to indices within the file. Depends only on the parsed AST.
- `elabDecl`: elaborates one declaration. Fetches the AST, looks up the declaration, type-checks it. Depends on `constant` queries for every referenced name.
- `constant`: the elaborated form of a named constant. This is the primary cross-declaration dependency.

When the elaborator encounters a constant reference, `fetchConstant` issues a `Key.constant` query, registering a dependency. An `entryCache` in `ElabState` memoises lookups within a single elaboration run to avoid repeated queries for the same name.

=== Query wiring

The `tasks` function maps each `Key` to its computation. Three representative cases illustrate how queries chain:

`constant filepath name` resolves a name to its elaborated form across files. It first tries the local file via `lookup filepath name`, which delegates to `elabDecl filepath name`. If that returns `none` (the name is not defined in this file), it fetches `transitiveImports filepath` to get the set of imported files, then tries `lookup path name` for each imported file until it finds a match. This two-phase lookup is the primary cross-file resolution mechanism: editing a definition in one file invalidates `constant` queries in other files that resolved to it.

`elabDecl filepath name` elaborates a single declaration. It fetches `declarationIndex filepath` (a map from names to command indices), looks up the index for `name`, then fetches `elabCmdAt filepath idx` to run the elaborator on that command. The result is the elaborated `Constant` and diagnostic information. Because the index is looked up dynamically, reordering definitions in a file changes the index mapping and triggers re-elaboration of the affected declarations.

`checkFile filepath` aggregates all diagnostics for a file. It fetches `astSourceMap filepath` for parse errors, `declarationIndex filepath` for the list of declarations, then `lookupInfo filepath name` for each declared name to collect elaboration diagnostics. This is the top-level query that the CLI and language server invoke.

=== The elaboration monad

`ElabM` combines incremental queries with elaboration state:

```lean
abbrev ElabM := ReaderT ElabContext (StateT ElabState (Task Monad config ι₀ q₀))
```

`Task` is the query monad: `Task.fetch` calls register dependencies. `StateT ElabState` threads the local environment, constant cache, and accumulated diagnostics and hovers. `ReaderT ElabContext` carries file path, declaration name, and universe parameters. `ι₀` and `q₀` identify the current query in the dependency graph.

=== Granularity of queries

If queries are too coarse, such as per-file granuality, any edit invalidates the whole file. If they are too fine, per-expression, the per-query overhead dominates.

I chose per-declaration granularity. `Key.elabDecl` elaborates one `def`, `inductive`, or `structure`. Dependent declarations are recomputed only if the edit changes the cached `Constant`.

Finer granularity would require making subterms addressable, adding engineering complexity for diminishing returns.

=== Dependently-typed query results

The dependent `Val : Key → Type` lets `fetch (Key.constant p n) : Task (Option Constant)` type-check without tagging; the compiler specialises each call site. The alternatives are a sum type (boilerplate matching at every consumer), an existential (`unsafeCast` at every fetch), or GADTs (where an index on the key type determines the result type, as in Rock and Salsa). Dependent types express this directly.

=== Query dependency graph

@fig:query-graph shows the query dependency graph for a two-definition file:

```lean
def foo : Type 1 := Type
def bar : Type 1 := foo
```

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.6pt,
    node-fill: rgb("#dce4f0"),
    node-inset: 6pt,
    spacing: (12pt, 16pt),

    node((1, 0), [`text`], fill: rgb("#e6d0c8"), name: <text>),
    node((1, 1), [`cst`], name: <cst>),
    node((1, 2), [`astSourceMap`], name: <asm>),
    node((1, 3), [`ast`], name: <ast>),
    node((1, 4), [`declarationIndex`], name: <di>),
    node((0, 5), [`elabCmdAt 0`], name: <ec0>),
    node((2, 5), [`elabCmdAt 1`], name: <ec1>),
    node((0, 6), [`elabDecl foo`], fill: rgb("#e8dfd0"), name: <edf>),
    node((2, 6), [`elabDecl bar`], fill: rgb("#e8dfd0"), name: <edb>),
    node((0, 7), [`lookup foo`], name: <lf>),
    node((0, 8), [`constant foo`], name: <cf>),

    edge(<cst>, <text>, "->"),
    edge(<asm>, <cst>, "->"),
    edge(<ast>, <asm>, "->"),
    edge(<di>, <ast>, "->"),
    edge(<ec0>, <ast>, "->"),
    edge(<ec0>, <di>, "->"),
    edge(<ec1>, <ast>, "->"),
    edge(<ec1>, <di>, "->"),
    edge(<ec1>, <cf>, "->", bend: 30deg),
    edge(<edf>, <ec0>, "->"),
    edge(<edf>, <di>, "->"),
    edge(<edb>, <ec1>, "->"),
    edge(<edb>, <di>, "->"),
    edge(<lf>, <edf>, "->"),
    edge(<cf>, <lf>, "->"),
  ),
  caption: [
    Query dependency graph for a file with two definitions. Arrows point from a query to its dependencies. The `text` node (red) is the input. Elaborating `bar` depends on `constant foo`, which depends on `elabDecl foo`. Editing `foo`'s body invalidates `elabCmdAt 0`, `elabDecl foo`, `lookup foo`, and `constant foo`; if the resulting `Constant` hashes the same (e.g. the type is unchanged), `elabDecl bar` is not recomputed.
  ],
) <fig:query-graph>

=== Glued evaluation and dependency tracking

Glued evaluation (@sec:nbe) produces values carrying a constant's name and universe arguments without fetching its body. The body is fetched only when `whnf` forces the value. Flex mode compares two glued values with the same head without forcing either side. Only when heads disagree and full mode fires does delta-reduction fetch the body and record a dependency.

=== The Shake algorithm

When the build system receives a request for query $q$, it executes the following procedure:

+ *Cache lookup.* Check if $q$ has a cached `Memo` from a previous build.
+ *Verify input fingerprints.* For each input dependency recorded in the memo, hash the current input value and compare against the stored fingerprint. If any mismatch, go to step 5.
+ *Verify query fingerprints.* For each query dependency recorded in the memo, _recursively fetch_ that dependency (which may itself verify or recompute), hash the result, and compare. If any mismatch, go to step 5.
+ *Cache hit.* All fingerprints match. Return the cached value.
+ *Recompute.* Execute the task, recording which inputs and queries it fetches. Hash the results. Store a new `Memo` with the value and its dependency fingerprints.

@fig:shake-verify illustrates verification on a fragment of the query graph. Each edge is annotated with the fingerprint stored at build time. When `elabDecl bar` is fetched, Shake verifies its dependency `constant foo` by recursively fetching it, which in turn verifies `elabDecl foo` against the input `text`. If the input has changed, `elabDecl foo` is recomputed. If the new result hashes the same as the stored fingerprint on the edge to `constant foo`, verification of `elabDecl bar` still passes (early cutoff). If it hashes differently, `elabDecl bar` is recomputed too.

#figure(
  diagram(
    node-stroke: 0.6pt,
    node-inset: 6pt,
    spacing: (16pt, 18pt),

    node((1, 0), [`text`], fill: rgb("#e6d0c8"), name: <text>),
    node((1, 1), [`elabDecl foo`], fill: rgb("#dce4f0"), name: <edf>),
    node((1, 2), [`constant foo`], fill: rgb("#dce4f0"), name: <cf>),
    node((1, 3), [`elabDecl bar`], fill: rgb("#dce4f0"), name: <edb>),

    edge(<edf>, <text>, "->", label: text(size: 0.8em)[`h₁`]),
    edge(<cf>, <edf>, "->", label: text(size: 0.8em)[`h₂`]),
    edge(<edb>, <cf>, "->", label: text(size: 0.8em)[`h₃`]),
  ),
  caption: [Shake verification. Each edge stores a fingerprint (`h₁`, `h₂`, `h₃`) from the previous build. To verify `elabDecl bar`, Shake recursively fetches `constant foo`, which fetches `elabDecl foo`, which checks `h₁` against the current input. If `h₁` mismatches, `elabDecl foo` is recomputed; if its new result still matches `h₂`, `elabDecl bar` is not recomputed (early cutoff).],
) <fig:shake-verify>

Verification is _suspending_: the build walks the graph demand-driven, recursing into each dependency before deciding whether the current query needs recomputation. This is the suspending scheduler with verifying traces in the terminology of Mokhov, Mitchell, and Peyton Jones @mokhov2018build.

=== Early cutoff

Shake hashes each query's result alongside its dependency fingerprints. When a dependency is recomputed and its result hashes the same as before, the queries that depend on it are not recomputed; their fingerprints still match.

Consider appending a new definition to `Nat.qdt`. The `declarationIndex` query is invalidated (a new name appears), and the new definition's `elabDecl` query runs. But the existing definitions --- `Nat.add`, `Nat.succ`, etc. --- produce the same `Constant` values as before. Their hashes are unchanged, so `constant Nat.add` returns the cached result. Files that import `Nat` see the same fingerprint and are not recomputed, even though `Nat.qdt` was edited.

Without early cutoff, any edit to `Nat.qdt` would cascade through every importing file. With early cutoff, the cascade stops at the first query whose result is unchanged.

=== Native build system implementations

The Lean Shake implementation (`Incremental/Shake.lean`) uses `runST` with mutable references for the memo table and in-progress cache. Two additional implementations in C — `shake.c` (622 lines) and `salsa.c` (519 lines) — implement the same `Build` interface via Lean's `@[extern]` FFI.

The C implementations must match Lean's runtime ABI: constructor field order and scalar layout for `Memo` and `Store`, closure arity for the `fetch` and `input` callbacks passed to tasks, and reference counting protocol for all allocated objects.

The C implementation avoids Lean's closure allocation and monadic bind dispatch on each query.
