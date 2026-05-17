== Design goal <sec:design-goal>

@sec:requires identified four obligations a build framework must support to admit a machine-checked agreement theorem: dependent result types, well-foundedness, structural parametricity carried on tasks, and effect orthogonality. This chapter constructs a framework that satisfies them, instantiates it with three caching strategies, and wires the elaborator into it.

The construction proceeds in four steps. @sec:build-framework defines the `Build` interface and the `compute` reference semantics that every inhabitant must agree with, with the parametricity certificate carried as a field of `Task`. @sec:build-inhabitants exhibits three inhabitants: `Busy` runs `compute` directly, `LessBusy` adds within-build memoisation, and `Shake` adds cross-build persistence with verifying traces. Two effect-layer extensions, `ShakeTrace` and `ShakeCancel`, are derived from `Shake` without revisiting the agreement proof. @sec:elaborator presents the elaborator as a single `Tasks` value, independent of which inhabitant executes it, and records the constants the conversion checker unfolds so that invalidation is keyed on actual dependencies rather than file boundaries. @sec:lsp wraps the executor for editor interaction.

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-fill: rgb("#dce4f0"),
    node-inset: 6pt,
    spacing: (40pt, 30pt),
    mark-scale: 120%,

    node((0, 0), [Source text], fill: rgb("#eaeaea"), name: <src>),
    node((1, 0), [Source positions], fill: rgb("#f0dede"), name: <pos>),
    node((1.8, 0), [Hover position], fill: rgb("#def0de"), name: <hover>),

    node((0, 1), [CST], name: <cst>),
    node((0, 2), [AST], name: <ast>),
    node((0, 3), [Type checker], name: <tc>),
    node((0, 4.5), [Core terms], name: <core>),

    edge(<src>, <cst>, "->", label: [_parse_]),

    node((0, 1.5), none, stroke: none, inset: 0pt, width: 1pt, height: 1pt, name: <mid-desugar>),
    edge(<cst>, <mid-desugar>, "-", label: [_desugar_]),
    edge(<mid-desugar>, <ast>, "->"),
    node((1.4, 1.5), align(center)[Source map], fill: rgb("#e8dfd0"), width: 150pt, name: <sm>),
    edge(<mid-desugar>, <sm>, "-->", stroke: 0.4pt),

    edge(<ast>, <tc>, "->"),

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

    node((-1, 3), [Conversion + NbE], fill: rgb("#e8dfd0"), name: <conv>),
    edge(<tc>, <conv>, "<->"),

    edge(<diag>, <pos>, "->"),

    edge(<hover>, <tyinfo>, "->"),
  ),
  caption: [
    Elaboration pipeline. Source text is parsed to a CST, then desugared to an AST and a source map between CST and AST paths. The type checker produces core terms and emits diagnostics keyed by AST paths. Diagnostics are mapped through the source map to recover source positions.
  ],
) <fig:pipeline>
