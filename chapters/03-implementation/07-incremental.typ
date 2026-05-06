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

If queries are too coarse, such as per-file granuality, any edit invalidates the whole file. If they are too fine, per-expression, the per-query overhead dominates.

I chose per-declaration granularity. `Key.elabDecl` elaborates one `def`, `inductive`, or `structure`. Dependent declarations are recomputed only if the edit changes the cached `Constant`.

Finer granularity is not particularly compelling, since large terms can be broken into smaller definitions anyway, by the user.

=== Dependently-typed query results

The dependent `Val : Key → Type` lets `fetch (Key.constant p n) : Task (Option Constant)` type-check without tagging --- the compiler specialises each call site. The alternatives are a sum type (boilerplate matching at every consumer), an existential (`unsafeCast` at every fetch), or GADTs (where an index on the key type determines the result type, as in Rock and Salsa). Dependent types express this directly.

=== Query dependency graph

@fig:query-graph shows the query dependency graph for a two-definition file:

```lean
def foo : Type 1 := Type
def bar : Type 1 := foo
```

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-fill: rgb("#e8f0fe"),
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (12pt, 16pt),

    node((1, 0), [`text`], fill: rgb("#fce8e6"), name: <text>),
    node((1, 1), [`cst`], name: <cst>),
    node((1, 2), [`astSourceMap`], name: <asm>),
    node((1, 3), [`ast`], name: <ast>),
    node((1, 4), [`declarationIndex`], name: <di>),
    node((0, 5), [`elabCmdAt 0`], name: <ec0>),
    node((2, 5), [`elabCmdAt 1`], name: <ec1>),
    node((0, 6), [`elabDecl foo`], name: <edf>),
    node((2, 6), [`elabDecl bar`], name: <edb>),
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

Glued evaluation (@sec:nbe) produces values carrying a constant's name and universe arguments without fetching its body. The body is fetched only when whnf forces the value. Flex mode compares two glued values with the same head without forcing either side --- no body fetched, no dependency recorded. Only when heads disagree and full mode fires does delta-reduction fetch the body and record a dependency.

Editing a definition's body thus invalidates only the queries that actually unfolded it. Call sites whose checks succeeded in flex mode have no dependency on the body.

