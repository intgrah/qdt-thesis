== Architecture

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-fill: rgb("#dce4f0"),
    node-inset: 6pt,
    spacing: (40pt, 30pt),
    mark-scale: 120%,

    // Top row: Source text, Source positions, Hover position
    node((0, 0), [Source text], fill: rgb("#eaeaea"), name: <src>),
    node((1, 0), [Source positions], fill: rgb("#f0dede"), name: <pos>),
    node((1.8, 0), [Hover position], fill: rgb("#def0de"), name: <hover>),

    // Main pipeline (column 0)
    node((0, 1), [CST], name: <cst>),
    node((0, 2), [AST], name: <ast>),
    node((0, 3), [Type checker], name: <tc>),
    node((0, 4.5), [Core terms], name: <core>),

    edge(<src>, <cst>, "->", label: [_parse_]),

    // Desugar: CST -> midpoint -> AST, with branch to source map
    node((0, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <mid-desugar>),
    edge(<cst>, <mid-desugar>, "-", label: [_desugar_]),
    edge(<mid-desugar>, <ast>, "->"),
    node((1.4, 1.5), align(center)[Source map], fill: rgb("#e8dfd0"), width: 150pt, name: <sm>),
    edge(<mid-desugar>, <sm>, "-->", stroke: 0.4pt),

    edge(<ast>, <tc>, "->"),

    // Type check: TC -> Core, with two branch points for diagnostics and type info
    node((0, 3.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <mid-tc1>),
    node((0, 4), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <mid-tc2>),
    edge(<tc>, <mid-tc1>, "-"),
    edge(<mid-tc1>, <mid-tc2>, "-"),
    edge(<mid-tc2>, <core>, "->"),
    node((1, 3.5), [Diagnostics], fill: rgb("#f0dede"), name: <diag>),
    edge(<mid-tc1>, <diag>, "-->", stroke: 0.4pt),
    node((1.8, 3.5), [Type info], fill: rgb("#def0de"), name: <tyinfo>),
    node((1.8, 4), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <corner-ty>),
    edge(<mid-tc2>, <corner-ty>, "--", stroke: 0.4pt),
    edge(<corner-ty>, <tyinfo>, "-->", stroke: 0.4pt),

    // Subroutine of type checker (left)
    node((-1, 3), [Conversion + NbE], fill: rgb("#e8dfd0"), name: <conv>),
    edge(<tc>, <conv>, "<->"),

    // Diagnostics -> through source map -> source positions (left side, vertical)
    edge(<diag>, <pos>, "->"),

    // Hover position -> through source map -> type info (right side, vertical)
    edge(<hover>, <tyinfo>, "->"),
  ),
  caption: [
    Elaboration pipeline. Source text is parsed to a CST, then desugared to an AST and a source map between CST and AST paths. The type checker produces core terms and emits diagnostics keyed by AST paths. Diagnostics are mapped through the source map to recover source positions.
  ],
) <fig:pipeline>

The pipeline stages (@fig:pipeline) are described in the following sections:

- *Parsing* (@sec:parsing): a Pratt parser produces a green-tree CST, then desugars to an AST and a source map.
- *Bidirectional type checking* (@sec:bidirectional): the AST is checked against expected types or synthesises its own, calling into NbE and conversion checking.
- *Normalisation by evaluation* (@sec:nbe): terms are evaluated into a semantic domain using defunctionalised closures.
- *Conversion checking* (@sec:conv): decides definitional equality with rigid, flex, and full modes to avoid unnecessary unfolding.
- *Inductive types* (@sec:inductive): declarations are elaborated into type formers, constructors, and recursors.

The remaining sections cover cross-cutting concerns:

- *Incremental elaboration* (@sec:incremental): the build system decomposes elaboration into per-declaration queries, memoises results, and recomputes only what changed.
- *Language server* (@sec:lsp): diagnostics and hover information are mapped through the source map and served to a VSCode extension.
- *Formal verification* (@sec:verification): three build systems are proven correct against batch evaluation.

Components are connected by query dependencies, not direct function calls. The parser produces a `cst` query result; the desugarer an `ast` query; each declaration's elaborated form an `elabDecl` query depending on `constant` queries for every name it references. When a file changes, only the affected queries are recomputed.

To illustrate how the components interact, consider the elaboration of two definitions:

```lean
def id.{u} (A : Type u) (x : A) : A := x
def foo : Type 1 := id.{2} (Type 1) Type
```

*Parsing.* The source is parsed into a green-tree CST, then desugared to an AST with two definition nodes at indices 0 and 1. The `declarationIndex` query maps the name `id` to index 0 and `foo` to index 1.

*Elaborating `id`.* The `elabDecl` query for `id` fires. The universe parameter list is `[u]`. The parameter telescope is elaborated left to right:

- `A : Type u` --- the annotation is a valid universe, so `A` is bound with type $"Type"_u$.
- `x : A` --- the annotation refers to the parameter just bound. After evaluation, `x` is bound with type $A$.

The return type `A` refers to the first parameter. The body `x` is checked against `A` by context lookup. The elaborated constant has type $Pi (A : "Type"_u) . Pi (x : A) . A$ and body $lambda A . lambda x . x$.

*Elaborating `foo`.* The `elabDecl` query for `foo` fires. The expected type $"Type"_1$ is checked (it has type $"Type"_2$). The body `id.{2} (Type 1) Type` is an application, handled by `inferTm`:

+ *Infer the head.* `id` triggers `fetchConstant`, issuing a `constant` query and recording a dependency. The type is instantiated at level 2: $Pi (A : "Type"_2) . Pi (x : A) . A$. Evaluation produces a glued value: a neutral head `.const id [2]` paired with name and universe arguments for deferred unfolding.

+ *Check the first argument.* `Type 1` is checked against $"Type"_2$. Inferred type: $"Type"_2$. Conversion: $"Type"_2 = "Type"_2$ --- success. The codomain closure is evaluated with $A$ bound to $"Type"_1$, yielding $Pi (x : "Type"_1) . "Type"_1$.

+ *Check the second argument.* `Type` ($"Type"_0$) is checked against $"Type"_1$. Inferred: $"Type"_1$. Conversion: $"Type"_1 = "Type"_1$ --- success.

+ *Subsumption.* Inferred result $"Type"_1$ against expected $"Type"_1$. Conversion succeeds.

No delta-reduction of `id` was needed --- the result type follows entirely from `id`'s Pi type, without inspecting its body. The glued value was never forced.

*Query dependencies.* `elabDecl foo` depends on `constant id`. If `id`'s body later changes but its type remains $Pi (A : "Type"_u) . Pi (x : A) . A$, the hash is unchanged and `foo` is not recomputed. Only if `id`'s type changes does `foo` re-fire.
