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

==== The Shake algorithm

When the build system receives a request for query $q$, it executes the following procedure:

+ *Cache lookup.* Check if $q$ has a cached `Memo` from a previous build.
+ *Verify input fingerprints.* For each input dependency recorded in the memo, hash the current input value and compare against the stored fingerprint. If any mismatch, go to step 5.
+ *Verify query fingerprints.* For each query dependency recorded in the memo, _recursively fetch_ that dependency (which may itself verify or recompute), hash the result, and compare. If any mismatch, go to step 5.
+ *Cache hit.* All fingerprints match. Return the cached value.
+ *Recompute.* Execute the task, recording which inputs and queries it fetches. Hash the results. Store a new `Memo` with the value and its dependency fingerprints.

@fig:shake-algorithm gives the algorithm as a flowchart. The three escape paths (no Memo, input-hash mismatch, query-hash mismatch) all funnel to a recompute that stores a fresh Memo; matching at every level returns the cached value.

#let _shake_inputc = rgb("#c43a3a")
#let _shake_recompc = rgb("#c97a3a")
#let _shake_cutoffc = rgb("#5a9b5a")
#let _shake_hitc = rgb("#7a7a7a")
#let _shake_newc = rgb("#7aa8c4")
#let _shake_xdecl = rgb("#7a3a7a")
#let _shake_swatch(c) = box(width: 0.8em, height: 0.8em, baseline: -0.05em, stroke: 1.3pt + c)

#import "@preview/fletcher:0.5.8": shapes

#figure(
  diagram(
    node-stroke: 0.9pt,
    node-inset: 5pt,
    spacing: (14pt, 12pt),
    edge-stroke: 0.55pt,
    mark-scale: 75%,

    node((1, 0), [request `q`], shape: shapes.pill, name: <start>),
    node((1, 1), [look up `Memo[q]`], name: <lookup>),
    node((1, 2), [_Memo exists?_], shape: shapes.diamond, name: <exist>),
    node((1, 3), align(center)[for each $i in$ `inputDeps`: \ check $h_I (i, sans("now"))$ vs $h_I (i, sans("stored"))$], name: <inhash>),
    node((1, 4), [_all input hashes match?_], shape: shapes.diamond, name: <inok>),
    node((1, 5), align(center)[for each $q' in$ `queryDeps`: \ recursively fetch $q'$, hash, compare], name: <qhash>),
    node((1, 6), [_all query hashes match?_], shape: shapes.diamond, name: <qok>),
    node((1, 7), [return cached `value`], stroke: 1.3pt + _shake_cutoffc, name: <hit>),

    node((3, 4), align(center)[recompute task; \ record `inputDeps`, `queryDeps`; \ store new `Memo`], stroke: 1.3pt + _shake_recompc, name: <recomp>),
    node((3, 6.5), [return new `value`], stroke: 1.3pt + _shake_cutoffc, name: <miss>),

    edge(<start>, <lookup>, "->"),
    edge(<lookup>, <exist>, "->"),
    edge(<exist>, <inhash>, "->", label: [yes], label-side: left),
    edge(<inhash>, <inok>, "->"),
    edge(<inok>, <qhash>, "->", label: [yes], label-side: left),
    edge(<qhash>, <qok>, "->"),
    edge(<qok>, <hit>, "->", label: [yes], label-side: left),

    edge(<exist>, (3, 2), <recomp>, "->", corner-radius: 6pt, label: [no], label-pos: 0.15, label-side: right),
    edge(<inok>, <recomp>, "->", label: [no], label-side: right),
    edge(<qok>, (3, 6), <recomp>, "->", corner-radius: 6pt, label: [no], label-pos: 0.15, label-side: right),
    edge(<recomp>, <miss>, "->"),
  ),
  caption: [Verify-or-recompute for one query under Shake. The cache-hit path on the left checks input fingerprints, then recursively checks query fingerprints; on any mismatch (or no Memo at all) the task is recomputed and a fresh Memo stored. _Recursively_ in the third decision is the load-bearing word: each `queryDeps` entry triggers the same procedure on its query, so verification walks the dependency graph until it bottoms out at inputs.],
) <fig:shake-algorithm>

@fig:shake-verify shows the operational consequence on a small file: starting from a two-declaration source `A.qdt`, the user inserts a new declaration `baz` between `foo` and `bar`. Every query depending on `text` is re-evaluated, but the path-keyed `declAst` for `foo` and `bar` produces the same subtree as before (paths are relative to the declaration, not byte offsets in the file), so each recomputed fingerprint matches the stored one. Early cutoff fires at `declAst foo` and `declAst bar`: their dependants (`elabDecl`, `constant`) see unchanged input fingerprints and serve their cached values without re-elaboration.

#figure(
  kind: image,
  supplement: [Figure],
  {
    set align(center)
    stack(spacing: 8pt,
      table(
        columns: (auto, auto),
        column-gutter: 18pt,
        stroke: none,
        align: (left + top, left + top),
        [_Before_:
```lean
def foo : Nat := 5
def bar : Nat := foo
```],
        [_After_ (inserting `baz`):
```lean
def foo : Nat := 5
def baz : Nat := 7
def bar : Nat := foo
```],
      ),
      diagram(
        node-stroke: 1pt,
        node-inset: 5pt,
        spacing: (14pt, 14pt),
        edge-stroke: 0.55pt,
        mark-scale: 70%,

        node((2, 0), [`text A.qdt`], stroke: 1.4pt + _shake_inputc, name: <text>),
        node((2, 1), [`ast`], stroke: 1.4pt + _shake_recompc, name: <ast>),
        node((2, 2), [`declarationIndex`], stroke: 1.4pt + _shake_recompc, name: <di>),

        node((0, 3.3), [`declAst foo`], stroke: 1.4pt + _shake_cutoffc, name: <daf>),
        node((2, 3.3), [`declAst baz`], stroke: 1.4pt + _shake_newc, name: <dab>),
        node((4, 3.3), [`declAst bar`], stroke: 1.4pt + _shake_cutoffc, name: <dabr>),

        node((0, 4.6), [`elabDecl foo`], stroke: 1.4pt + _shake_hitc, name: <edf>),
        node((2, 4.6), [`elabDecl baz`], stroke: 1.4pt + _shake_newc, name: <edb>),
        node((4, 4.6), [`elabDecl bar`], stroke: 1.4pt + _shake_hitc, name: <edbr>),

        node((0, 5.9), [`constant foo`], stroke: 1.4pt + _shake_hitc, name: <cf>),
        node((2, 5.9), [`constant baz`], stroke: 1.4pt + _shake_newc, name: <cb>),
        node((4, 5.9), [`constant bar`], stroke: 1.4pt + _shake_hitc, name: <cbr>),

        edge(<ast>, <text>, "->"),
        edge(<di>, <ast>, "->"),

        edge(<daf>, <ast>, "->"),
        edge(<daf>, <di>, "->"),
        edge(<dab>, <ast>, "->"),
        edge(<dab>, <di>, "->"),
        edge(<dabr>, <ast>, "->"),
        edge(<dabr>, <di>, "->"),

        edge(<edf>, <daf>, "->"),
        edge(<edb>, <dab>, "->"),
        edge(<edbr>, <dabr>, "->"),

        edge(<cf>, <edf>, "->"),
        edge(<cb>, <edb>, "->"),
        edge(<cbr>, <edbr>, "->"),

        edge(<edbr.south>, (4, 7), (0, 7), <cf.south>, "->",
          corner-radius: 6pt,
          stroke: 0.8pt + _shake_xdecl,
          label: text(size: 7pt, fill: _shake_xdecl)[cross-decl dep],
          label-pos: 0.5, label-side: right),
      ),
      text(size: 8.5pt)[
        #_shake_swatch(_shake_inputc) input changed
        #h(6pt) #_shake_swatch(_shake_recompc) recomputed, hash changed
        #h(6pt) #_shake_swatch(_shake_cutoffc) recomputed, hash unchanged ($->$ cutoff)
        #h(6pt) #_shake_swatch(_shake_hitc) cache hit
        #h(6pt) #_shake_swatch(_shake_newc) new
      ],
    )
  },
  caption: [Rebuild trace after inserting `baz` between `foo` and `bar` in `A.qdt`. The cross-decl edge from `elabDecl bar` to `constant foo` records that elaborating `bar` fetched `foo`'s body during conversion. `text`, `ast`, and `declarationIndex` recompute (orange) because their underlying values changed. `declAst foo` and `declAst bar` recompute, but the file's restructuring leaves each declaration's subtree intact, so their fingerprints match (green) and the cascade stops there. `elabDecl` and `constant` for `foo` and `bar` are cache hits (grey). Only the `baz` column is new work (blue).],
) <fig:shake-verify>

Verification is _suspending_: the build walks the graph demand-driven, recursing into each dependency before deciding whether the current query needs recomputation. This is the suspending scheduler with verifying traces in the terminology of @mokhov2018build.

==== Early cutoff

Shake hashes each query's result alongside its dependency fingerprints. When a dependency is recomputed and its result hashes the same as before, the queries that depend on it are not recomputed; their fingerprints still match.

Consider appending a new definition to `Nat.qdt`. A new name appears, so the `declarationIndex` query is invalidated and the new definition's `elabDecl` query runs. But the existing `Nat.add`, `Nat.succ`, and other prior definitions produce the same `Constant` values as before. Their hashes are unchanged, so `constant Nat.add` returns the cached result. Files that import `Nat` see the same fingerprint and are not recomputed, even though `Nat.qdt` was edited.

Without early cutoff, any edit to `Nat.qdt` would cascade through every importing file. With early cutoff, the cascade stops at the first query whose result is unchanged.
