== Normalisation by evaluation <sec:nbe>

#import "@preview/fletcher:0.5.8": diagram, edge, node

The conversion rule requires deciding definitional equality, which in turn requires reducing terms. The naive approach, repeatedly rewriting syntax until a normal form is reached, performs substitution one variable at a time, each time traversing the term. Normalisation by evaluation (NbE) @abel2013normalization avoids this by interpreting syntax into a _semantic domain_ of values, where substitution happens in bulk through environments rather than syntactic traversal.

_Evaluation_ maps syntax into values; _quotation_ (or _readback_) maps values back to syntax. The round trip produces a normal form.

#figure(
  diagram(
    node-stroke: 0.6pt,
    node-inset: 6pt,
    spacing: (30pt, 20pt),

    node((0, 0), [`Tm` (syntax)], fill: rgb("#dce4f0"), name: <syn>),
    node((1, 0), [`VTm` (values)], fill: rgb("#e8dfd0"), name: <val>),

    edge(<syn>, <val>, "->", label: [`eval`], bend: 20deg),
    edge(<val>, <syn>, "->", label: [`quote`], bend: 20deg),
  ),
  caption: [The NbE round trip.],
) <fig:nbe-flow>

In a type checker, we rarely need full normal forms. Most conversion checks succeed or fail after examining only the outermost constructor. So evaluation stops at _weak head normal form_ (WHNF): it reduces the head of a term until it is a lambda, a Pi, a universe, or an irreducible variable, then stops. Subterms are reduced only on demand, when the conversion checker descends into them.

=== Values and variables

Values represent terms in WHNF. A value is either canonical (lambda, Pi, universe) or _neutral_: a variable or constant applied to a spine of arguments that cannot reduce further because the head is blocked.

Variables are represented using de Bruijn _levels_ rather than _indices_. An index counts inward from the binding site: in $lambda x. lambda y. x$, the variable $x$ has index 1. A level counts outward from the root of the context: $x$ has level 0. The difference matters when opening a closure under a binder: adding a new variable to the context shifts every index but changes no level. Since evaluation constantly opens closures, levels avoid the cost of traversing values to adjust variable references.

=== Closures

A closure represents a function body waiting for its argument. In _higher-order abstract syntax_ (HOAS), a closure is a host-language function `VTm -> VTm`: applying it is a native function call. In _defunctionalised_ closures, a closure is a pair of the body's syntax and the captured environment: applying it re-evaluates the body in the extended environment.

HOAS is generally faster, but requires a non-strictly-positive inductive type (`lam : (VTm -> VTm) -> VTm`), which Lean 4's kernel over-approximately rejects, due to the possibility of unsoundness. I use defunctionalised closures to keep the evaluator within the language's logic.

=== Evaluation

Evaluation interprets syntax in an environment mapping bound variables to their values. Variables look up their value in the environment. Lambdas and Pis capture the current environment to form a closure. Application of a lambda to an argument evaluates the body in the closure's environment extended with the argument. This is where substitution happens, without traversing the body's syntax. Let-bindings are handled the same way: the bound value is evaluated and added to the environment, then the body is evaluated.

Constants receive special treatment. A defined constant (one with a body) evaluates to a _glued_ value: a pair of the folded form (the constant's name and universe arguments) and the information needed to unfold it. The body is not fetched during evaluation; it is deferred until `whnf` forces it. This lazy unfolding is important for incrementality: if the conversion checker compares two glued values with the same head and succeeds without forcing either side, no dependency on the definition body is recorded.

=== Weak head normalisation

`whnf` takes a value and reduces it until the outermost form is canonical or irreducible. For most values this is immediate. The interesting cases are glued values and recursor applications. When `whnf` encounters a glued value, it fetches the definition body, evaluates it with the appropriate universe substitution, re-applies the accumulated spine of arguments, and continues reducing ($delta$-reduction). This is the only point at which a definition body is materialised. When a recursor is fully applied and its major premise is a constructor, $iota$-reduction fires: the constructor's fields are substituted into the matching branch.

=== Quotation

Quotation converts values back to syntax. Closures are opened by applying them to a fresh variable at the current de Bruijn level, and the result is recursively quoted. Levels are converted back to indices during this process. Glued values quote to their folded form (the constant name), preserving definition boundaries rather than inlining bodies.
