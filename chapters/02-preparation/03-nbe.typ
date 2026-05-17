#import "common.typ": *

== Normalisation by evaluation <sec:nbe-theory>

Conversion calls from @sec:bidirectional-theory reduce terms to compare them. _Normalisation by evaluation_ (NbE) @abel2013normalization interprets terms into a _semantic domain_ of _values_. A $lambda$ becomes a _closure_, a body paired with the environment of its captured variables; a $beta$-step extends the environment with the argument's value, and the body is evaluated under the extended environment.

Two functions complete the round trip. _Evaluation_ takes a term and an environment to a value; _quotation_ (or _readback_) takes a value back to a term.

A value is either _canonical_ ($lambda$, $Pi$, universe, or constructor) or _neutral_: a variable or recursor whose head is not yet reducible, applied to a _spine_ of arguments. Evaluation reduces to _weak head normal form_ (WHNF): the outermost constructor is decided, with reductions under binders deferred. Quotation descends into spines and forces closures under fresh binders. Conversion of two values is a structural walk: at canonicals of the same shape, recurse into subterms (entering closures with a fresh variable); at neutrals, compare heads and spines.

Consider $(lambda x. f thin x) thin a$ at the empty environment, with $f$ a constant whose body is unavailable. The pieces of the term, drawn out in @fig:nbe-trace, end up in three different places: the binder $x$ joins the argument $a$ as an environment binding $x mapsto a$; the body $f thin x$ becomes the new focus; the lambda itself and the surrounding application are consumed. Continuing the WHNF of the body, the variable $x$ is looked up in the environment to yield $a$, and the head $f$, having no body to unfold, applies to $a$ to give the neutral value $f dot.c a$. Quotation reads this neutral back as the syntactic term $f thin a$.

#figure(
  {
    import "@preview/fletcher:0.5.8": diagram, edge, node

    diagram(
      node-stroke: none,
      node-inset: 3pt,
      spacing: (16pt, 18pt),

      node((-2.5, 1), [$lambda$], name: <l>),
      node((-3.5, 2), [$x$], name: <x>),
      node((-1.5, 2), [$f thin x$], name: <body>),
      node((-0.5, 1), [$a$], name: <a>),

      edge(<l>, <x>, stroke: 0.4pt),
      edge(<l>, <body>, stroke: 0.4pt),

      node((2.5, 1.2), [$x mapsto a$], name: <env>),
      node((2.5, 2), [$f thin x$], name: <focus>),
      node((1.4, 1.2), text(size: 0.85em)[env]),
      node((1.4, 2), text(size: 0.85em)[focus]),

      edge(<x>, <env>, "->", bend: 25deg),
      edge(<a>, <env>, "->", bend: -10deg),
      edge(<body>, <focus>, "->", bend: -10deg),
    )
  },
  caption: [$(lambda x. thin f thin x) thin a$ taken apart by $beta$. The binder $x$ and the argument $a$ form the new environment binding; the body $f thin x$ becomes the new focus.],
) <fig:nbe-trace>

_Glued evaluation_ refines the algorithm for the case where the term being reduced names a defined constant. A definition introduced by `def c := body` makes $c$ definitionally equal to `body` by $delta$-reduction. A conversion checker that unfolds $delta$ eagerly pays the cost of normalising `body` on every encounter, even when the two sides being compared agree without ever needing `body`. _Glued_ evaluation @kovacs2024unfolding @kovacs2023smalltt avoids the eager cost. A constant $c$ evaluates to a pair of its _folded_ representation (the name $c$ and its universe arguments) and a thunk producing its unfolded value. Conversion compares folded forms first, on the speculation that two glued values with the same head and matching spines are equal. Only when the speculation fails does the checker force the thunk and try again.

Glued evaluation and the speculative conversion regime are due to Kovács's smalltt @kovacs2023smalltt @kovacs2024unfolding; qdt adopts both, and treats each forced thunk as the moment a cross-declaration dependency edge is recorded for the build system.

The glued representation gives the build system the hook it needs. Forcing $c$'s thunk is the moment the elaborator commits to depending on $c$'s body; the dependency edge is not declared in the source, only observed when conversion fires $delta$. @sec:conv describes the qdt implementation of this algorithm.
