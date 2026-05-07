== Parsing <sec:parsing>

The parser is a hand-rolled recursive descent Pratt parser @pratt1973top, implemented as monadic combinators over `StateT State (Except ParseError)`. Source text is first parsed to a concrete syntax tree (`Cst`) retaining trivia and exact token widths, then desugared to an abstract syntax tree (`Ast`) that strips trivia and expands surface syntax.

=== Green trees

#import "@preview/fletcher:0.5.8": diagram, node, edge

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

Each token stores its text _including adjacent whitespace_. Nodes store only their kind and children --- no absolute positions. Positions are recovered on demand by summing widths from the root. Because nodes lack positions, two identical subtrees are structurally equal regardless of where they appear in the file, making the CST `Hashable`.

This matters for incrementality in two ways: green trees absorb whitespace edits within a definition, and relative paths absorb insertions before a definition.

==== Whitespace edits

Consider the definition `def foo := Type`, which produces the CST:

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (10pt, 14pt),

    node((1, 0), [`definition`], fill: rgb("#e8f0fe"), name: <root>),
    node((0, 1), [`"def·"`], fill: rgb("#f0f0f0"), name: <def>),
    node((0.67, 1), [`"foo"`], fill: rgb("#f0f0f0"), name: <foo>),
    node((1.33, 1), [`"·:=·"`], fill: rgb("#f0f0f0"), name: <col>),
    node((2, 1), [`"Type"`], fill: rgb("#f0f0f0"), name: <ty>),

    edge(<root>, <def>, "->"),
    edge(<root>, <foo>, "->"),
    edge(<root>, <col>, "->"),
    edge(<root>, <ty>, "->"),
  ),
  caption: [CST for `def foo := Type`. Each token includes adjacent whitespace (shown as `·`). The `definition` node stores no position.],
) <fig:cst-example>

If the user changes this to `def foo      := Type` (extra spaces), only the `":=·"` token changes --- it becomes `"·····:=·"`. The other three tokens (`"def·"`, `"foo"`, `"Type"`) are structurally identical. The AST, which discards whitespace during desugaring, hashes the same as before. No downstream query is invalidated.

Without green trees, each node would store its absolute byte offset. Adding five spaces would shift the positions of `":= "` and `"Type"`, producing a structurally different tree. Every query that depends on the CST --- the AST, the elaboration, the diagnostics --- would see a different hash and recompute, despite the source code being semantically identical.

==== Relative paths and insertion

The elaboration pipeline uses _paths_ --- lists of child indices relative to a subtree root --- rather than absolute positions or absolute indices from the file root. A path `[2, 1]` means "child 2 of the subtree, then child 1 of that". Diagnostics and hovers are keyed by path relative to the declaration's subtree.

This means that inserting a new definition _before_ `foo` does not invalidate `foo`'s elaboration. Consider a file with two definitions:

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (8pt, 14pt),

    node((1, 0), [`file`], fill: rgb("#e8f0fe"), name: <file>),
    node((0, 1), [`def bar ...`], fill: rgb("#e6f4ea"), name: <bar>),
    node((2, 1), [`def foo ...`], fill: rgb("#e6f4ea"), name: <foo>),

    edge(<file>, <bar>, "->", label: [`[0]`]),
    edge(<file>, <foo>, "->", label: [`[1]`]),
  ),
  caption: [`foo` is at absolute index `[1]` in the file.],
)

If a new definition `baz` is inserted before `foo`:

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (8pt, 14pt),

    node((1, 0), [`file`], fill: rgb("#e8f0fe"), name: <file>),
    node((-0.5, 1), [`def bar ...`], fill: rgb("#e6f4ea"), name: <bar>),
    node((1, 1), [`def baz ...`], fill: rgb("#fce8e6"), name: <baz>),
    node((2.5, 1), [`def foo ...`], fill: rgb("#e6f4ea"), name: <foo>),

    edge(<file>, <bar>, "->", label: [`[0]`]),
    edge(<file>, <baz>, "->", label: [`[1]`]),
    edge(<file>, <foo>, "->", label: [`[2]`]),
  ),
  caption: [`foo` is now at absolute index `[2]`, but its subtree is unchanged.],
)

`foo`'s absolute index changed from `[1]` to `[2]`, but the subtree rooted at `foo` is structurally identical --- same tokens, same children, same widths. The `declarationIndex` query (which maps names to indices) recomputes, but `foo`'s green tree subtree hashes the same as before, so `elabDecl foo` is not recomputed. Only `baz` is elaborated.

If paths were absolute from the file root, every diagnostic and hover inside `foo` would shift from `[1, ...]` to `[2, ...]`, producing different hashes and forcing recomputation of `foo` and all subsequent definitions.

=== Language server integration

Alongside the CST, parsing produces a `SourceMap` that bidirectionally maps paths in the CST to paths in the AST:

```lean
structure SourceMap where
  cstToAst : HashMap Path Path
  astToCst : HashMap Path Path
```

The map is populated during desugaring: as each AST node is constructed from a CST node, an entry is added to both tables. The language server uses it in both directions:

- _Hover_: given a cursor position, the CST is walked to find the path of the token under the cursor. `cstToAst` maps this to the AST path. Hover content is keyed by AST path, so the lookup is direct.
- _Diagnostics_: the elaborator records diagnostics at AST paths. `astToCst` maps these back to CST paths, which are converted to source spans by summing widths from the root.

Source positions are reconstructed only at this final step --- the entire elaboration pipeline operates on paths, never on byte offsets. Path-based lookup is $O("depth")$ rather than $O("size")$.

=== Error recovery

On a parse error, a diagnostic is emitted and the parser skips to the next top-level declaration boundary (`def`, `inductive`, `axiom`, etc.). A single malformed declaration does not prevent the rest of the file from being elaborated.

A separate converter from `Lean.Syntax` to `Ast` via the metaprogramming framework is available for inline test cases in Lean source files, but is not used by the main pipeline.

