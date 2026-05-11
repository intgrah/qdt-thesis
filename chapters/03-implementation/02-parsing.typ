== Parsing <sec:parsing>

The parser is a hand-rolled recursive descent Pratt parser @pratt1973top, implemented as monadic combinators over `EStateM ParseError State`. Source text is first parsed to a concrete syntax tree (`Cst`) retaining trivia and exact token widths, then desugared to an abstract syntax tree (`Ast`) that strips trivia and expands surface syntax.

=== Green trees

#import "@preview/fletcher:0.5.8": diagram, edge, node

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

Nodes store only their kind and children, not absolute positions. Positions are recovered on demand by summing widths from the root. Because nodes lack positions, two identical subtrees are structurally equal regardless of where they appear in the file, making the CST `Hashable`.

Separately, whitespace and comments are parsed as _trivia_ tokens, stored as siblings of content tokens. Lowering discards trivia when producing the AST, so whitespace edits that only affect trivia tokens do not change the AST hash.

==== Example

Consider the file containing:

```lean
def a : Nat := Nat.zero
def b : Nat := a
```

The CST is a tree rooted at a `file` node, with trivia (whitespace, comments) and declaration subtrees as children. Each declaration subtree contains its tokens. @fig:cst-example shows the structure, with token children of each declaration abbreviated.

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    spacing: (8pt, 14pt),

    node((3, 0), [`file`], fill: rgb("#dce4f0"), name: <file>),

    node((3, 0.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <fmid>),
    edge(<file>, <fmid>, "-"),

    node((0, 0.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <fb0>),
    node((3, 0.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <fb1>),
    node((6, 0.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <fb2>),

    edge(<fb0>, <fb2>, "-"),

    node((0, 1), [`def a`], fill: rgb("#dce4f0"), name: <deffoo>),
    node((3, 1), [#raw("\"\\n\"")], fill: rgb("#f5f5f5"), name: <ws>),
    node((6, 1), [`def b`], fill: rgb("#dce4f0"), name: <defbar>),

    edge(<fb0>, <deffoo>, "-"),
    edge(<fb1>, <ws>, "-"),
    edge(<fb2>, <defbar>, "-"),

    node((0, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <foomid>),
    edge(<deffoo>, <foomid>, "-"),

    node((-2, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <foob0>),
    node((2, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <foob1>),
    edge(<foob0>, <foob1>, "-"),

    node((-2, 2), [`"def"`], fill: rgb("#eaeaea"), name: <t0>),
    node((-1, 2), [`" "`], fill: rgb("#f5f5f5"), name: <t1>),
    node((0, 2), [`"a"`], fill: rgb("#eaeaea"), name: <t2>),
    node((1, 2), [`...`], stroke: none, name: <t3>),
    node((2, 2), [`"Nat.zero"`], fill: rgb("#eaeaea"), name: <t4>),

    edge(<foob0>, <t0>, "-"),
    edge((-1, 1.5), <t1>, "-"),
    edge(<foomid>, <t2>, "-"),
    edge((1, 1.5), <t3>, "-"),
    edge(<foob1>, <t4>, "-"),

    node((6, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <barmid>),
    edge(<defbar>, <barmid>, "-"),

    node((4, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <barb0>),
    node((8, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <barb1>),
    edge(<barb0>, <barb1>, "-"),

    node((4, 2), [`"def"`], fill: rgb("#eaeaea"), name: <u0>),
    node((5, 2), [`" "`], fill: rgb("#f5f5f5"), name: <u1>),
    node((6, 2), [`"b"`], fill: rgb("#eaeaea"), name: <u2>),
    node((7, 2), [`...`], stroke: none, name: <u3>),
    node((8, 2), [`"a"`], fill: rgb("#eaeaea"), name: <u4>),

    edge(<barb0>, <u0>, "-"),
    edge((5, 1.5), <u1>, "-"),
    edge(<barmid>, <u2>, "-"),
    edge((7, 1.5), <u3>, "-"),
    edge(<barb1>, <u4>, "-"),
  ),
  caption: [CST for the two-definition file. Whitespace is stored in separate trivia tokens.],
) <fig:cst-example>

==== Trivia separation and whitespace edits

If the user adds extra spaces within `def a`, only the affected trivia token changes. The content tokens (`"def"`, `"a"`, `":="`, `"Nat.zero"`) are structurally identical. The CST hash does change (the trivia token is different), but lowering discards trivia, so the AST hashes the same as before. No downstream query is invalidated. This is a property of trivia separation in the CST and lowering, not of green trees per se.

==== Position independence and insertion

Green trees store no absolute positions. A definition's subtree is determined entirely by its tokens and their structure, not by where it sits in the file. This means inserting a new definition `c` before `b` does not invalidate `b`'s elaboration: `b`'s subtree is structurally identical before and after the insertion.

The elaboration pipeline uses _paths_ --- lists of child indices relative to a subtree root --- rather than absolute positions. A path `[2, 1]` means "child 2 of the subtree, then child 1 of that". Diagnostics and hovers are keyed by path relative to the declaration's subtree. After the insertion, the `declarationIndex` query (which maps names to indices) recomputes --- `b` is now at a different index --- but `b`'s subtree hashes the same, so `elabDecl b` is not recomputed. Only `c` is elaborated.

If nodes stored absolute byte offsets, every node after the insertion point would have a different offset, producing a structurally different tree. Every query depending on those nodes would recompute, even though the source code is semantically unchanged.

=== Language server integration

Desugaring produces, alongside the AST, a `SourceMap` that bidirectionally maps paths in the CST to paths in the AST:

```lean
structure SourceMap where
  cstToAst : HashMap Path Path
  astToCst : HashMap Path Path
```

The map is populated during desugaring: as each AST node is constructed from a CST node, an entry is added to both tables. The language server uses it in both directions:

- _Hover_: given a cursor position, the CST is walked to find the path of the token under the cursor. `cstToAst` maps this to the AST path. Hover content is keyed by AST path, so the lookup is direct.
- _Diagnostics_: the elaborator records diagnostics at AST paths. `astToCst` maps these back to CST paths, which are converted to source spans by summing widths from the root.

Source positions are reconstructed only at this final step. The entire elaboration pipeline operates on paths, never on byte offsets. Path-based lookup is $O("depth")$ rather than $O("size")$.

=== Error recovery

On a parse error, a diagnostic is emitted and the parser skips to the next top-level declaration boundary (`def`, `inductive`, `axiom`, etc.). A single malformed declaration does not prevent the rest of the file from being elaborated.

A separate converter from `Lean.Syntax` to `Ast` via the metaprogramming framework is available for inline test cases in Lean source files, but is not used by the main pipeline.

