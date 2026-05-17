=== Normalisation by evaluation <sec:nbe>

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
  caption: [NbE round trip.],
) <fig:nbe-flow>

The core syntax `Tm`/`Ty` is the output of elaboration; the semantic domain `VTm`/`VTy` is what evaluation produces. Both are _intrinsically scoped_: the type `Tm n` (and `VTm n`) is indexed by the number of bound variables in scope, so a de Bruijn index or level can only refer to a binder the type system already knows about. Out-of-range references do not typecheck in Lean.

```lean
inductive Ty : Nat → Type
  | u  : Universe → Ty n
  | pi : Name → Ty n → Ty (n + 1) → Ty n
  | el : Tm n → Ty n

inductive Tm : Nat → Type
  | u'    : Universe → Tm n
  | var   : Idx n → Tm n
  | const : Name → List Universe → Tm n
  | lam   : Name → Ty n → Tm (n + 1) → Tm n
  | app   : Tm n → Tm n → Tm n
  | pi'   : Name → Tm n → Tm (n + 1) → Tm n
  | proj  : Nat → Tm n → Tm n
  | letE  : Name → Ty n → Tm n → Tm (n + 1) → Tm n
```

```lean
inductive VTy : Nat → Type
  | u  : Universe → VTy n
  | pi : Name → VTy n → ClosTy n → VTy n
  | el : Neutral n → VTy n

inductive VTm : Nat → Type
  | u'      : Universe → VTm n
  | neutral : Neutral n → VTm n
  | lam     : Name → VTy n → ClosTm n → VTm n
  | pi'     : Name → VTm n → ClosTm n → VTm n
  | glued   : Neutral n → Name → List Universe → VTm n

inductive Neutral : Nat → Type | mk {n} : Head n → Spine n → Neutral n
inductive Head    : Nat → Type | var {n} : Lvl n → Head n | const {n} : Name → List Universe → Head n
inductive Spine   : Nat → Type | nil {n} | app {n} : Spine n → VTm n → Spine n | proj {n} : Spine n → Nat → Spine n
inductive ClosTm  : Nat → Type | mk {n m} : Env n m → Tm (m + 1) → ClosTm n
```

Three differences distinguish the two presentations. First, `Tm.var` uses a de Bruijn index `Idx n`, whereas a value can reference a variable only inside a `Neutral`, where the head is a level `Lvl n`. Second, application and projection do not appear as value constructors; an application of a blocked head accumulates in `Spine`, and the value's `lam` and `pi'` cases close over a `ClosTm`/`ClosTy` rather than carrying syntax under a binder. The closure is how substitution is deferred. Third, a value-only constructor `VTm.glued` records a definition that has not yet been unfolded, holding the spine accumulated against the constant's name together with the universe arguments needed to instantiate the body once $delta$-reduction fires.

==== Representation

Values represent terms in _weak head normal form_ (WHNF): a value is either canonical (a lambda, Pi, or universe) or _neutral_, a variable or constant applied to a spine of arguments that cannot reduce further because the head is blocked.

==== Closures

HOAS is generally faster, but a closure containing a host-language function has no extensional structure to hash: hashing a `VTm -> VTm` would reduce to hashing a pointer, and pointer hashes are not stable across builds. Shake's early cutoff depends on `Hashable (Val q)` for every query result, so any value reachable from a `Val` must be hashable from its structure. Defunctionalised closures, a pair of syntax and environment, admit a structural hash.

==== Evaluation

A defined constant (one with a body) evaluates to a _glued_ value: a pair of the folded form (the constant's name and universe arguments) and the information needed to unfold it. The body is not fetched during evaluation; it is deferred until `whnf` forces it.

==== Weak head normalisation

`whnf` takes a value and reduces it until the outermost form is canonical or irreducible. When `whnf` encounters a glued value, it fetches the definition body, evaluates it with the appropriate universe substitution, re-applies the accumulated spine of arguments, and continues reducing ($delta$-reduction). This is the only point at which a definition body is materialised. When a recursor is fully applied and its major premise is a constructor, $iota$-reduction fires: the constructor's fields are substituted into the matching branch.
