#import "../../template.typ": metrics, num

=== Incremental elaboration <sec:incremental>

Elaboration is decomposed into queries managed by a Shake-based build system. Each query has a tag and parameters; its result type is determined by the tag. `Key` has 17 cases; the principal ones are listed.

#[
  #show raw.where(block: true): set block(width: auto)
  #show raw: set text(size: 6.3pt)
  #grid(
    columns: (auto, auto),
    column-gutter: 8pt,
    ```lean
    inductive Key where
      | astSourceMap : FilePath → Key
      | ast : FilePath → Key
      | declarationIndex : FilePath → Key
      | declAst : FilePath → Name → Key
      | declScope : FilePath → Name → Name → Key
      | elabDecl : FilePath → Name → Key
      | constant : FilePath → Name → Key
      | lookupInfo : FilePath → Name → Key
      -- ...
    ```,
    ```lean
    def Val : Key → Type
      | .astSourceMap _     => Ast × SourceMap × Array Diagnostic
      | .ast _              => Ast
      | .declarationIndex _ => HashMap Name Nat × Array Diagnostic
      | .declAst _ _        => Option Ast
      | .declScope _ _ _    => Bool
      | .elabDecl _ _       => Option Constant × ElabInfo
      | .constant _ _       => Option Constant
      | .lookupInfo _ _     => ElabInfo
      -- ...
    ```,
  )
]

The principal queries:

- `declarationIndex`: maps declaration names to indices within the file. Depends only on the parsed AST.
- `declAst`: extracts the AST subtree for a single named declaration. Depends on `declarationIndex` (for the index) and `ast` (for the file).
- `declScope`: whether one name may be referenced from inside another's elaboration, used as a stable surrogate for the order check (see below).
- `elabDecl`: elaborates one declaration. Fetches `declAst` for the subtree, then runs the elaborator. Depends on `declScope` and `constant` queries for every referenced name.
- `constant`: the elaborated form of a named constant. The primary cross-declaration dependency.

When the elaborator encounters a constant reference, `fetchConstant` issues a `Key.constant` query, registering a dependency. An `entryCache` in `ElabState` memoises lookups within a single elaboration run to avoid repeated queries for the same name.

==== Query wiring

The `tasks` function maps each `Key` to its computation. Three representative cases illustrate how queries chain:

`constant filepath name` resolves a name to its elaborated form across files. It first tries the local file via `lookup filepath name`, which delegates to `elabDecl filepath name`. If that returns `none` (the name is not defined in this file), it fetches `transitiveImports filepath` to get the set of imported files, then tries `lookup path name` for each imported file until it finds a match. This two-phase lookup is the primary cross-file resolution mechanism: editing a definition in one file invalidates `constant` queries in other files that resolved to it.

`elabDecl filepath name` elaborates a single declaration. It fetches `declAst filepath name` to obtain the subtree for `name`, then runs the elaborator with the declaration-relative path stack initialised to the empty path. The diagnostics and hovers it produces are therefore independent of the declaration's absolute position in the file. The result is the elaborated `Constant` and diagnostic information.

The order check used during constant resolution ("may `name` be referenced from inside `currentDecl`'s elaboration?") is routed through `declScope filepath name currentDecl`. This query fetches `declarationIndex` and returns the `Bool` answer. Lifting the comparison out of `elabDecl`'s body means `elabDecl` does not depend on `declarationIndex` directly: insertions that shift indices recompute `declScope`, but its `Bool` result is unchanged for pre-existing pairs of names, so the cutoff fires at the `declScope` boundary and `elabDecl` is not re-elaborated.

`checkFile filepath` aggregates all diagnostics for a file. It fetches `astSourceMap filepath` for parse errors, `declarationIndex filepath` for the list of declarations, then `lookupInfo filepath name` for each declared name to collect elaboration diagnostics. Because each `lookupInfo` returns paths relative to its own declaration, `checkFile` prepends the declaration's current index at aggregation time, converting decl-relative paths to file-relative for the source-map resolver. This is the top-level query that the CLI and language server invoke.

==== The elaboration monad

`ElabM` combines incremental queries with elaboration state:

```lean
abbrev ElabM := ReaderT ElabContext (StateT ElabState (Task config q₀))
```

`Task` is the query monad: `Task.fetch` calls register dependencies. `StateT ElabState` threads the local environment, constant cache, and accumulated diagnostics and hovers. `ReaderT ElabContext` carries file path, declaration name, and universe parameters. `q₀` identifies the current query in the dependency graph.

==== Granularity of queries

If queries are too coarse, such as per-file granuality, any edit invalidates the whole file. If they are too fine, per-expression, the per-query overhead dominates.

I chose per-declaration granularity. `Key.elabDecl` elaborates one `def`, `inductive`, or `structure`. Dependent declarations are recomputed only if the edit changes the cached `Constant`.

Finer granularity would require making subterms addressable, adding engineering complexity for diminishing returns.

==== Query dependency graph

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
    node((1, 1), [`astSourceMap`], name: <asm>),
    node((1, 2), [`ast`], name: <ast>),
    node((1, 3), [`declarationIndex`], name: <di>),
    node((0, 4), [`declAst foo`], name: <daf>),
    node((2, 4), [`declAst bar`], name: <dab>),
    node((2, 5), [`declScope foo<bar`], name: <ds>),
    node((0, 6), [`elabDecl foo`], fill: rgb("#e8dfd0"), name: <edf>),
    node((2, 6), [`elabDecl bar`], fill: rgb("#e8dfd0"), name: <edb>),
    node((0, 7), [`lookup foo`], name: <lf>),
    node((0, 8), [`constant foo`], name: <cf>),

    edge(<asm>, <text>, "->"),
    edge(<ast>, <asm>, "->"),
    edge(<di>, <ast>, "->"),
    edge(<daf>, <di>, "->"),
    edge(<daf>, <ast>, "->"),
    edge(<dab>, <di>, "->"),
    edge(<dab>, <ast>, "->"),
    edge(<ds>, <di>, "->"),
    edge(<edf>, <daf>, "->"),
    edge(<edb>, <dab>, "->"),
    edge(<edb>, <ds>, "->"),
    edge(<edb>, <cf>, "->", bend: 30deg),
    edge(<lf>, <edf>, "->"),
    edge(<cf>, <lf>, "->"),
  ),
  caption: [
    Query dependency graph for a file with two definitions. Arrows point from a query to its dependencies. The `text` node (red) is the input. Elaborating `bar` depends on `declAst bar` for its subtree, `declScope foo<bar` for the order check, and `constant foo`. Editing `foo`'s body invalidates `astSourceMap`, `ast`, and the `declAst` queries; `declAst bar`'s value is unchanged so the cutoff fires there. `elabDecl foo` recomputes; if the resulting `Constant` hashes the same (e.g. the type is unchanged), `elabDecl bar` is not recomputed. Inserting a sibling between `foo` and `bar` invalidates `declarationIndex`, but the `declScope` and `declAst` queries return the same values, so `elabDecl bar` still hits cache.
  ],
) <fig:query-graph>

==== Unfolding

Glued evaluation (@sec:nbe) produces values carrying a constant's name and universe arguments without fetching its definition. The definition is fetched only when `whnf` forces the value. Flex mode compares two glued values with the same head without forcing either side. Only when heads disagree and full mode fires is the definition fetched, and the build system records a dependency on the unfolded constant.

==== The Shake algorithm

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

Verification is _suspending_: the build walks the graph demand-driven, recursing into each dependency before deciding whether the current query needs recomputation. This is the suspending scheduler with verifying traces in the terminology of @mokhov2018build.

==== Early cutoff

Shake hashes each query's result alongside its dependency fingerprints. When a dependency is recomputed and its result hashes the same as before, the queries that depend on it are not recomputed; their fingerprints still match.

Consider appending a new definition to `Nat.qdt`. A new name appears, so the `declarationIndex` query is invalidated and the new definition's `elabDecl` query runs. But the existing `Nat.add`, `Nat.succ`, and other prior definitions produce the same `Constant` values as before. Their hashes are unchanged, so `constant Nat.add` returns the cached result. Files that import `Nat` see the same fingerprint and are not recomputed, even though `Nat.qdt` was edited.

Without early cutoff, any edit to `Nat.qdt` would cascade through every importing file. With early cutoff, the cascade stops at the first query whose result is unchanged.

==== Native build system implementations

The Lean Shake implementation in `Incremental/Shake.lean` uses `runST` with mutable references for the memo table and in-progress cache. Two additional implementations in C, `shake.c` at #num(metrics.rows.shake_c) lines and `salsa.c` at #num(metrics.rows.salsa_c) lines, implement the same `Build` interface via Lean's `@[extern]` FFI.

The C implementations must match Lean's runtime ABI: constructor field order and scalar layout for `Memo` and `Store`, closure arity for the `fetch` and `input` callbacks passed to tasks, and reference counting protocol for all allocated objects.

The C implementation avoids Lean's closure allocation and monadic bind dispatch on each query.
