#import "../../template.typ": diff

=== Incremental elaboration <sec:incremental>

Elaboration is decomposed into queries managed by a Shake-based build system. Each query has a tag and parameters; its result type is determined by the tag. `Key` has 20 cases; the principal ones are listed.

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

==== Query dependency graph

@fig:query-graph shows the query dependency graph for a two-definition file:

```lean
def foo : Type 1 := Type
def bar : Type 1 := foo
```

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    spacing: (10pt, 9pt),

    node((1, 0), [`text`], name: <text>),
    node((1, 1), [`astSourceMap`], name: <asm>),
    node((1, 2), [`ast`], name: <ast>),
    node((1, 3), [`declarationIndex`], name: <di>),
    node((0, 4), [`declAst foo`], name: <daf>),
    node((2, 4), [`declAst bar`], name: <dab>),
    node((2, 5), [`declScope` $"foo" < "bar"$], name: <ds>),
    node((0, 5), [`elabDecl foo`], name: <edf>),
    node((-1, 5), [`lookup foo`], name: <lf>),
    node((-1, 6), [`constant foo`], name: <cf>),
    node((2, 6), [`elabDecl bar`], name: <edb>),

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
    edge(<edb>, <cf>, "->"),
    edge(<lf>, <edf>, "->"),
    edge(<cf>, <lf>, "->"),
  ),
  caption: [
    Query dependency graph for the two-definition example. Arrows go from each query to its dependencies. The horizontal edge from elabDecl bar to constant foo records that bar's elaboration fetched foo's body during conversion.
  ],
) <fig:query-graph>

==== The Shake algorithm

The mechanism Shake follows when servicing a request for query $q$ is Mitchell's verifying-trace scheme @mitchell2012shake. Each cached `Memo` stores not only $q$'s value but a trace: the inputs the task read, the queries it fetched, and the hash of each at the time the task ran. On the next build, Shake checks whether the world still matches what the trace recorded, and runs the task again only when something has changed.

The check is recursive. Shake hashes every recorded input against the current input, and for every recorded query dependency it fetches that dependency --- which may itself verify or recompute --- and hashes the result. If all the hashes match, the cached value stands; if any one differs, the task runs, records fresh dependencies, and replaces the old `Memo`. The recursive structure is what makes verification _suspending_ in the @mokhov2018build classification: deciding whether $q$'s memo is fresh suspends inside the decision for some dependency $d$, which suspends inside $e$, until every transitive trace entry has either matched its fingerprint or triggered a recompute.

@fig:shake-verify traces an example. Starting from a two-declaration source `A.qdt`, the user inserts a new declaration `baz` between `foo` and `bar`. `text`, `ast`, and `declarationIndex` recompute to fresh hashes because the file structure changed. `declAst foo` and `declAst bar` see their input fingerprints (`ast`, `declarationIndex`) mismatch, so they too recompute---but `declAst` is keyed by paths relative to the declaration, so the recomputed subtrees are byte-identical to the previous ones and the new fingerprints match the stored ones. Cutoff fires here: `elabDecl foo`, `elabDecl bar`, and the `constant` queries above them see every input fingerprint match and serve cached values.

#figure(
  kind: image,
  supplement: [Figure],
  {
    set align(center)
    let lbl(name, h) = [
      #raw(name)\
      #text(size: 7pt, raw(h))
    ]
    stack(
      spacing: 14pt,
      block(width: 60%, diff(
        (" ", "def foo : Nat := 5"),
        ("+", "def baz : Nat := 7"),
        (" ", "def bar : Nat := foo"),
      )),
      scale(85%, reflow: true, diagram(
        node-stroke: 0.5pt,
        node-inset: 5pt,
        spacing: (18pt, 22pt),
        edge-stroke: 0.5pt,
        mark-scale: 70%,

        node((2, 0), lbl("text A.qdt", "4a3f → c29b"), name: <text>),
        node((2, 1), lbl("ast", "e1c4 → 5b8a"), name: <ast>),
        node((2, 2), lbl("declarationIndex", "b6d2 → 8170"), name: <di>),

        node((0, 3), lbl("declAst foo", "7c41 → 7c41"), name: <daf>),
        node((2, 3), lbl("declAst baz", "(new) 60e5"), name: <dab>),
        node((4, 3), lbl("declAst bar", "5208 → 5208"), name: <dabr>),

        node((0, 4), lbl("elabDecl foo", "1fa9"), name: <edf>),
        node((2, 4), lbl("elabDecl baz", "(new) 4d7b"), name: <edb>),
        node((4, 4), lbl("elabDecl bar", "086c"), name: <edbr>),

        node((0, 5), lbl("constant foo", "9d33"), name: <cf>),
        node((2, 5), lbl("constant baz", "(new) a9f1"), name: <cb>),
        node((4, 5), lbl("constant bar", "3358"), name: <cbr>),

        edge(<ast>, <text>, "->"),
        edge(<di>, <ast>, "->"),

        edge(<daf>, <ast>, "->"),
        edge(<daf>, <di>, "->"),
        edge(<dab>, <ast>, "->", bend: 50deg),
        edge(<dab>, <di>, "->"),
        edge(<dabr>, <ast>, "->"),
        edge(<dabr>, <di>, "->"),

        edge(<edf>, <daf>, "->"),
        edge(<edb>, <dab>, "->"),
        edge(<edbr>, <dabr>, "->"),

        edge(<cf>, <edf>, "->"),
        edge(<cb>, <edb>, "->"),
        edge(<cbr>, <edbr>, "->"),

        edge(
          <edbr.east>,
          (5.2, 4),
          (5.2, 5.7),
          (-1.2, 5.7),
          (-1.2, 5),
          <cf.west>,
          "->",
          corner-radius: 5pt,
          stroke: (dash: "dashed", thickness: 0.5pt),
        ),
      )),
    )
  },
  caption: [Rebuild trace after inserting `baz`. `h → h'` recomputed (cutoff when $h = h'$), `h` cache hit, `(new) h` first appearance. The dashed edge `elabDecl bar → constant foo` was recorded by conversion.],
) <fig:shake-verify>

==== Early cutoff

Shake hashes each query's result alongside its dependency fingerprints. When a dependency is recomputed and its result hashes the same as before, the queries that depend on it are not recomputed; their fingerprints still match.

Consider appending a new definition to `Nat.qdt`. A new name appears, so the `declarationIndex` query is invalidated and the new definition's `elabDecl` query runs. But the existing `Nat.add`, `Nat.succ`, and other prior definitions produce the same `Constant` values as before. Their hashes are unchanged, so `constant Nat.add` returns the cached result. Files that import `Nat` see the same fingerprint and are not recomputed, even though `Nat.qdt` was edited.

Without early cutoff, any edit to `Nat.qdt` would cascade through every importing file. With early cutoff, the cascade stops at the first query whose result is unchanged.
