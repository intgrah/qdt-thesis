== Parsing <sec:parsing>

The parser is a hand-rolled recursive descent Pratt parser @pratt1973top, implemented as monadic combinators over `StateT State (Except ParseError)`. Source text is first parsed to a concrete syntax tree (`Cst`) retaining trivia and exact token widths, then desugared to an abstract syntax tree (`Ast`) that strips trivia and expands surface syntax.

The parser itself is unremarkable . The interesting choice is the CST representation.

=== Green trees

The CST follows the _green tree_ pattern @roslyn2015 @matklad2020rust_analyzer. Nodes and tokens are tagged by `SyntaxNodeKind`; positions are not stored:

```lean
inductive Cst : Type
  | token (kind : SyntaxNodeKind) (val : String)
  | node (kind : SyntaxNodeKind) (children : Array Cst)
with
  @[computed_field]
  width : Cst → Nat
    | .token _ val => val.length
    | .node _ children => children.map width |>.sum
```

For example, `def foo := Type` produces the tree:

```
node Command.definition ["def " | "foo" | " := " | "Type"]
```

Each token stores its text including adjacent whitespace. No absolute positions --- these are recovered by summing widths from the root. Because nodes lack positions, identical subtrees are structurally equal regardless of location, making the CST `Hashable`. The build system can short-circuit recomputation when an edit does not affect a subtree.

If two spaces are inserted at the start of the file, only the first token changes (`"def "` becomes `"  def "`). The rest are structurally identical, so the AST (which discards trivia) hashes the same and no downstream query is invalidated. Without green trees, any whitespace edit would shift absolute positions throughout the file, invalidating every query.

The pipeline works with AST _paths_ (lists of child indices from the root), not source positions. Diagnostics and hovers are keyed by path, so elaboration results are independent of where a definition sits in the file. Positions are reconstructed on demand for the language server.

=== Language server integration

Alongside the CST, parsing produces a `SourceMap` that bidriectionally maps paths in the CST to paths in the AST. A _path_ is a list of child indices from the root. In the tree above, the token `"foo"` has path `[1]` (the second child of the root node), and `" := "` has path `[2]`. In a file with two definitions, the identifier in the second definition might have path `[1, 1]` (second child of root, then second child of that node). The bidirectional map is:

```lean
structure SourceMap where
  cstToAst : HashMap Path Path
  astToCst : HashMap Path Path
```

The map is populated during desugaring. The language

The language server uses it in both directions:

- _Hover_: walk the CST to find the path under the cursor, then `cstToAst` gives the AST path. Hover content is keyed by AST path.
- _Diagnostics_: recorded at CST paths, mapped back via `astToCst`, then converted to source spans by summing widths.

Path-based lookup is $O("depth")$ rather than $O("size")$.

=== Error recovery

On a parse error, a diagnostic is emitted and the parser skips to the next top-level declaration boundary (`def`, `inductive`, `axiom`, etc.). A single malformed declaration does not prevent the rest of the file from being elaborated.

A separate converter from `Lean.Syntax` to `Ast` via the metaprogramming framework is available for inline test cases in Lean source files, but is not used by the main pipeline.

