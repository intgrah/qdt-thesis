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
- `constant`: the elaborated form of a named constant --- the primary cross-declaration dependency.

When the elaborator encounters a constant reference, `fetchConstant` issues a `Key.constant` query, registering a dependency. An `entryCache` in `ElabState` memoises lookups within a single elaboration run to avoid repeated queries for the same name.

=== The elaboration monad

`ElabM` combines incremental queries with elaboration state:

```lean
abbrev ElabM := ReaderT ElabContext (StateT ElabState (Task Monad config ι₀ q₀))
```

`Task` is the query monad: `Task.fetch` calls register dependencies. `StateT ElabState` threads the local environment, constant cache, and accumulated diagnostics and hovers. `ReaderT ElabContext` carries file path, declaration name, and universe parameters. `ι₀` and `q₀` identify the current query in the dependency graph.

=== Granularity of queries

If queries are too coarse --- one per file --- any edit invalidates the whole file. If they are too fine --- one per expression --- the per-query overhead dominates.

I chose per-declaration granularity. `Key.elabDecl` elaborates one `def`, `inductive`, or `structure`. Dependent declarations are recomputed only if the edit changes the cached `Constant`.

Finer granularity --- caching individual subterms --- would require treating each subterm as a named entity. This needs either heuristic naming (hashing syntax) or restructuring the theory. Neither is compelling.

=== Dependently-typed query results

The dependent `Val : Key → Type` lets `fetch (Key.constant p n) : Task (Option Constant)` type-check without tagging --- the compiler specialises each call site. The alternative is a sum type (boilerplate matching at every consumer) or existential (`unsafeCast` at every fetch). Haskell's Rock and Salsa approximate this with singleton types or type families.

=== Query dependency graph

@fig:query-graph shows the query dependency graph for a two-definition file:

```lean
def foo : Type 1 := Type
def bar : Type 1 := foo
```

#import "@preview/fletcher:0.5.8": diagram, node, edge

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-fill: rgb("#e8f0fe"),
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (10pt, 18pt),

    node((1, 0), [`text`], fill: rgb("#fce8e6"), name: <text>),

    node((1, 1), [`cst`], name: <cst>),
    edge(<cst>, <text>, "->"),

    node((1, 2), [`astSourceMap`], name: <asm>),
    edge(<asm>, <cst>, "->"),

    node((0, 3), [`ast`], name: <ast>),
    edge(<ast>, <asm>, "->"),

    node((2, 3), [`declarationIndex`], name: <di>),
    edge(<di>, <ast>, "->"),

    node((-0.5, 4), [`elabCmdAt 0`], name: <ec0>),
    edge(<ec0>, <ast>, "->"),
    edge(<ec0>, <di>, "->"),

    node((2.5, 4), [`elabCmdAt 1`], name: <ec1>),
    edge(<ec1>, <ast>, "->"),
    edge(<ec1>, <di>, "->"),

    node((-0.5, 5), [`elabDecl foo`], name: <edf>),
    edge(<edf>, <ec0>, "->"),
    edge(<edf>, <di>, "->"),

    node((2.5, 5), [`elabDecl bar`], name: <edb>),
    edge(<edb>, <ec1>, "->"),
    edge(<edb>, <di>, "->"),

    node((1, 6), [`lookup foo`], name: <lf>),
    edge(<lf>, <edf>, "->"),

    node((1, 7), [`constant foo`], name: <cf>),
    edge(<cf>, <lf>, "->"),

    edge(<ec1>, <cf>, "->", bend: 20deg),
  ),
  caption: [
    Query dependency graph for a file with two definitions. Arrows point from a query to its dependencies. The `text` node (red) is the input. Elaborating `bar` depends on `constant foo`, which depends on `elabDecl foo`. Editing `foo`'s body invalidates `elabCmdAt 0`, `elabDecl foo`, `lookup foo`, and `constant foo`; if the resulting `Constant` hashes the same (e.g. the type is unchanged), `elabDecl bar` is not recomputed.
  ],
) <fig:query-graph>

=== Glued evaluation and dependency tracking

Glued evaluation (@sec:nbe) produces values carrying a constant's name and universe arguments without fetching its body. The body is fetched only when whnf forces the value. Flex mode compares two glued values with the same head without forcing either side --- no body fetched, no dependency recorded. Only when heads disagree and full mode fires does delta-reduction fetch the body and record a dependency.

Editing a definition's body thus invalidates only the queries that actually unfolded it. Call sites whose checks succeeded in flex mode have no dependency on the body.

