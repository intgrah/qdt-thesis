== Architecture

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-fill: rgb("#e8f0fe"),
    node-inset: 6pt,
    node-corner-radius: 3pt,
    spacing: (20pt, 18pt),

    node((0, 0), [Source text], name: <src>),
    node((0, 1), [CST], name: <cst>),
    node((0, 2), [AST], name: <ast>),
    node((0, 3), [Type checker], name: <tc>),
    node((0, 4), [Core terms], name: <core>),

    edge(<src>, <cst>, "->", label: [_parse_]),
    edge(<cst>, <ast>, "->", label: [_desugar_]),
    edge(<ast>, <tc>, "->"),
    edge(<tc>, <core>, "->"),

    node((1.5, 3.5), [Conversion + NbE], name: <conv>),

    edge(<tc>, <conv>, "<->"),
  ),
  caption: [
    Elaboration pipeline. Source text is parsed to a CST, then desugared to an AST. The type checker produces core terms, calling the conversion checker and NbE evaluator as subroutines. Each stage is a query memoised by the build system.
  ],
) <fig:pipeline>

Each stage of the pipeline (@fig:pipeline) is described in a separate section:

- *Parsing* (@sec:parsing): a Pratt parser produces a green-tree CST and desugared AST. Green trees ensure whitespace edits do not invalidate downstream queries.
- *Bidirectional type checking* (@sec:bidirectional): the AST is checked against expected types or synthesises its own, calling the evaluator and conversion checker.
- *Normalisation by evaluation* (@sec:nbe): terms are evaluated into a semantic domain using defunctionalised closures and de Bruijn levels.
- *Conversion checking* (@sec:conv): decides definitional equality with rigid, flex, and full modes to avoid unnecessary unfolding.
- *Inductive types* (@sec:inductive): declaratoins are elaborated into type formers, constructors, and recursors with iota-reduction rules.
- *Incremental elaboration* (@sec:incremental): the build system decomposes elaboration into per-declaration queries, memoises results, and recomputes only what changed.
- *Language server* (@sec:lsp): diagnostics and hover information served to a VSCode extension.

The elaboration monad and query system are described in @sec:incremental.

Components are connected by query dependencies, not direct function calls. The parser produces a `cst` query result; the desugarer an `ast` query; each declaration's elaborated form an `elabDecl` query depending on `constant` queries for every name it references. When a file changes, only the affected queries are recomputed.

=== Worked example

We trace the elaboration of two definitions:

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
