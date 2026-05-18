=== Normalisation by evaluation <sec:nbe>

The elaborator's NbE follows the algorithm of @sec:nbe-theory: evaluation maps syntax to values in WHNF, quotation reads them back, and defined constants evaluate to glued values whose bodies are forced on demand. This section fixes the data types and the `whnf` function that drive it.

The syntax `Tm`/`Ty` is the output of elaboration; the semantic domain `VTm`/`VTy` is what evaluation produces. Both are intrinsically scoped: `Tm n` and `VTm n` are indexed by the number of bound variables in scope, so a de Bruijn index or level can only refer to a binder the type system already knows about. Out-of-range references do not typecheck in Lean.

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

inductive Neutral : Nat → Type
  | mk {n} : Head n → Spine n → Neutral n
inductive Head : Nat → Type
  | var {n} : Lvl n → Head n
  | const {n} : Name → List Universe → Head n
inductive Spine : Nat → Type
  | nil {n} | app {n} : Spine n → VTm n → Spine n
  | proj {n} : Spine n → Nat → Spine n
inductive ClosTm : Nat → Type
  | mk {n m} : Env n m → Tm (m + 1) → ClosTm n
```

Three differences distinguish the two presentations. First, `Tm.var` uses a de Bruijn index `Idx n`, whereas a value can reference a variable only inside a `Neutral`, where the head is a level `Lvl n`. Second, application and projection do not appear as value constructors; an application of a blocked head accumulates in `Spine`, and the value's `lam` and `pi'` cases close over a `ClosTm`/`ClosTy` rather than carrying syntax under a binder. Third, the value-only constructor `VTm.glued` records a definition that has not yet been unfolded, holding the spine accumulated against the constant's name together with the universe arguments needed to instantiate the body once $delta$-reduction fires.

==== Weak head normalisation

`whnf` reduces a value until its outermost form is canonical or irreducible. Forcing a `VTm.glued` fetches the constant's body, evaluates it under the recorded universe substitution, re-applies the accumulated spine, and continues ($delta$-reduction). This is the only point at which a definition body is materialised. $iota$-reduction fires when a recursor is fully applied and its major premise is a constructor: the constructor's fields are substituted into the matching branch.
