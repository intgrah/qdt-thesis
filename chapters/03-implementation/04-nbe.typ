== Normalisation by evaluation <sec:nbe>

#import "@preview/fletcher:0.5.8": diagram, edge, node

#figure(
  diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    node-corner-radius: 3pt,
    spacing: (30pt, 20pt),

    node((0, 0), [`Tm` (syntax)], fill: rgb("#e8f0fe"), name: <syn1>),
    node((1, 0), [`VTm` (values)], fill: rgb("#e8f0fe"), name: <val>),
    node((2, 0), [`Tm` (syntax)], fill: rgb("#e8f0fe"), name: <syn2>),

    edge(<syn1>, <val>, "->", label: [`eval`]),
    edge(<val>, <syn2>, "->", label: [`quote`]),

    node((1, 0.7), text(size: 0.85em)[`Env n m`], stroke: none),
    edge(<val>, (1, 0.5), "--", stroke: 0.3pt),
  ),
  caption: [NbE evaluates syntax into values via an environment, and quotes values back to syntax.],
) <fig:nbe-flow>

=== Semantic domain

Values (`VTm`, `VTy`) represent terms in weak head normal form, using de Bruijn _levels_ @debruijn1972lambda rather than indices:

```lean
inductive VTm : Nat → Type
  | u'      : Universe → VTm n
  | neutral : Neutral n → VTm n
  | lam     : Name → VTy n → ClosTm n → VTm n
  | pi'     : Name → VTm n → ClosTm n → VTm n
  | glued   : Neutral n → Name → List Universe → VTm n
```

A `neutral` is a head (variable or constant) applied to a spine of eliminators. A `lam` carries a closure --- an `Env n m` paired with a `Tm (m + 1)`. Beta-reduction evaluates the body in the extended environment. A `glued` value carries the folded neutral form (for quotation) alongside the constant's name and universe arguments; unfolding happens on demand when the conversion checker or whnf forces it.

A de Bruijn _index_ counts inward from the binding site: in $lambda x. lambda y. x$, $x$ has index 1. A de Bruijn _level_ counts outward from the root: $x$ has level 0. Indices shift when the context grows; levels do not.

NbE frequently _weakens_ values --- embedding them into a larger scope when a closure is opened. Under indices, weakening traverses the entire value to shift every variable. Under levels, it is a no-op. The scope parameter `n` in `VTm n` enforces well-scoping at the type level; weakening becomes a proof obligation that `omega` discharges, and the data is reused via `unsafeCast`.

=== Closures

Closures are defunctionalised: a lambda carries its body as syntax paired with the captured environment, rather than a host-language function `VTm -> VTm` (HOAS). HOAS is faster @kovacs2023smalltt but requires a non-strictly-positive inductive (`lam : (VTm -> VTm) -> VTm`), which Lean's kernel rejects. Defunctionalisation keeps the evaluator within the logic.

=== Evaluation

`Tm.eval` interprets syntax in an environment of values, indexed by scope size:

```lean
partial def Tm.eval {n c} : Tm c → SemM n c (VTm n)
  | .u' i         => return .u' i
  | .var i        => return (← read).get i
  | .const name us => do
      let some _ ← fetchConstantInfo name
        | return .neutral ⟨.const name us, .nil⟩
      if (← fetchDefinition name).isSome then
        return .glued ⟨.const name us, .nil⟩ name us
      else
        return .neutral ⟨.const name us, .nil⟩
  | .lam x a body => return .lam x (← a.eval) ⟨← read, body⟩
  | .app fn arg   => do (← fn.eval).app (← arg.eval)
  | .pi' x a b    => return .pi' x (← a.eval) ⟨← read, b⟩
  | .proj i t     => do (← t.eval).proj i
  | .letE _ _ t b => do b.eval (.cons (← t.eval) (← read))
```

Constants evaluate to _glued_ values when a definition exists, carrying the folded neutral alongside name and universe arguments --- no body is fetched. Axioms and opaques produce plain neutrals. Applications dispatch via `VTm.app`: beta-reduction for lambdas, spine extension for neutrals and glued values.

=== Weak head normalisation

`VTm.whnf` reduces until the outermost form is canonical (lambda, Pi, universe) or irreducible (variable-headed neutral):

- *$delta$-reduction*: when the head is a defined constant, `whnf` fetches the definition body, evaluates it with the appropriate universe substitution, and re-applies the spine. This is the only point at which a body is materialised --- evaluation merely records name and universes in the glued value.
- *$iota$-reduction*: when a fully-applied recursor has a constructor as its major premise, `whnf` substitutes the constructor's fields into the minor premise.

A glued value that is never forced --- because the conversion checker matched it in flex mode --- never triggers a fetch of the definition body.

=== Quotation

`VTm.quote` converts values back to syntax. Closures are applied to a fresh variable at the current level and the result quoted, converting levels to indices. Glued nodes quote to the folded form (the neutral), preserving definition names rather than inlining bodies.

