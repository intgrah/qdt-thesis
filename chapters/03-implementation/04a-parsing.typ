=== Parsing <sec:parsing>

The parser is a hand-rolled Pratt parser @pratt1973top, implemented as combinators over `ParserFn := State → State`, where `State` carries the input string, current byte position, a stack of partial `Cst` nodes, and an accumulating error log. Source text is first parsed to a concrete syntax tree (`Cst`) retaining trivia and exact token widths, then lowered to an abstract syntax tree (`Ast`) that strips trivia and expands surface syntax.

==== Green trees

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

===== Example

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

===== Trivia and position independence

Take the two-declaration file from @fig:cst-example and consider two edits. Adding extra spaces inside `def a` changes only the surrounding trivia token; the content tokens (`"def"`, `"a"`, `":="`, `"Nat.zero"`) are byte-for-byte identical, so the `def a` subtree hashes the same after lowering discards the trivia. Inserting a new declaration `c` between `a` and `b` leaves `b`'s subtree alone: a definition's subtree is determined by its tokens and their structure, and green tree nodes carry no absolute offsets.

The elaboration pipeline uses _paths_, lists of child indices relative to a subtree root, rather than absolute positions. A path `[2, 1]` means "child 2 of the subtree, then child 1 of that". Diagnostics and hovers are keyed by path relative to the declaration's subtree. After the `c` insertion, the `declarationIndex` query (which maps names to indices) recomputes because `b` sits at a different index, but `b`'s subtree hashes the same, so `elabDecl b` is reused from the cache. Only `c` is elaborated.

If nodes stored absolute byte offsets, every node after the insertion point would have a different offset, producing a structurally different tree, and every query depending on those nodes would recompute even though the source code is semantically unchanged.

==== Language server integration

Lowering produces, alongside the AST, a `SourceMap` that records the source span (byte range in the original input) of each AST path:

```lean
structure SourceMap where
  astToSpan : HashMap Path Span
```

The map is populated during lowering: when an AST node is constructed from a CST subtree, its AST path is associated with the span of that subtree, computed by accumulating token widths from the root. The language server uses this in two directions:

- _Hover_: given a cursor codepoint position, `astPathAtPosition` scans the entries to find the deepest AST path whose span contains the position. Hover content is keyed by AST path, so the subsequent lookup is direct.
- _Diagnostics_: the elaborator records diagnostics at AST paths. `spanForAstPath` looks up the recorded span, which the LSP layer converts into a UTF-16 range for the editor.

Source positions are materialised only at this final step. The entire elaboration pipeline operates on paths, never on byte offsets.

==== Error recovery

On a parse error, a diagnostic is emitted and the parser skips to the next top-level declaration boundary (`def`, `inductive`, `axiom`, etc.). A single malformed declaration does not prevent the rest of the file from being elaborated.

