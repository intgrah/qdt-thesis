== The build framework <sec:build-framework>

The build framework is a Lean 4 formalisation of the polymorphic Task type @mokhov2018build, extended with the four properties identified in @sec:requires: dependent result types, well-foundedness, structural parametricity on tasks, and effect orthogonality. This section defines the type and its reference semantics; @sec:build-inhabitants presents the cached executors that inhabit it.

=== Setup

Parsing returns a syntax tree, elaboration returns a typed term, diagnostics return an array of errors. Each query has its own result type. We separate the key space into _inputs_ `I` (set externally) and _queries_ `Q` (computed), each with a dependent value type:

$ V : I -> sans("Type"), quad R : Q -> sans("Type"). $

Termination needs a well-founded relation on queries; a task at query `q₀` may only fetch queries `q` with `rel q q₀`. The fields bundle into a configuration:

```lean
structure BuildConfig : Type 1 where
  I : Type;  V : I → Type
  Q : Type;  R : Q → Type
  rel : Q → Q → Prop
  wf  : WellFounded rel
```

An input store is a value `J` with a typeclass providing `get` and `set` operations satisfying `get_set_self` and `get_set_other` (set updates exactly one input). The simplest instance is `Function.update` on `∀ i, ℭ.V i`; the file-system instance reads and writes paths.

=== Task

A task specifies how to produce one query's result. It consumes inputs and dependencies (any query `q` strictly preceding `q₀` under `ℭ.rel`) and returns a value of the target type. A task is described once and runs under any monad: pure recomputation under `Id`, a stateful build under `StateM σ`, a dependency trace under a writer monad. Caching, scheduling, and execution order are the responsibility of inhabitants of `Build`, not of the task.

Parametricity @reynolds1983types is the property that gives this its teeth. A polymorphic function cannot inspect values of its abstract type parameters: a function of type `∀ α, List α → List α` can only rearrange, duplicate, or drop elements. A task is polymorphic over its effect monad in an analogous way, and the free theorem @wadler1989theorems says that two instantiations agree on related handlers. In Haskell the theorem is automatic. In Lean it is not: a polymorphic term can in principle inspect its type argument through typeclass dispatch or decidable equality, and parametricity for type constructors of higher kind cannot be derived internally @voigtlander2009free @atkey2012relational. Each task pays the fee at construction by carrying a certificate.

The certificate quantifies over a Voigtländer-style _monad action_ @voigtlander2009free, a relation lifter between two monads preserving `pure` and `>>=`:

```lean
structure MonadAction (κ₁ κ₂ : Type → Type) [Monad κ₁] [Monad κ₂] where
  rel       : (α → β → Prop) → (κ₁ α → κ₂ β → Prop)
  rel_pure  : R a b → rel R (pure a) (pure b)
  rel_bind  : rel R ma mb → (∀ a b, R a b → rel S (ka a) (kb b))
            → rel S (ma >>= ka) (mb >>= kb)
```

`rel` sends a value relation `R : α → β → Prop` to a computation relation `rel R : κ₁ α → κ₂ β → Prop`. The two laws require that pure values from related inputs are related, and that binds preserve relatedness over pointwise-related continuations.

A `Task ℭ q₀ α` then bundles a polymorphic computation `fn` with the certificate `param`:

```lean
structure Task (ℭ : BuildConfig) (q₀ : ℭ.Q) (α : Type) : Type 1 where
  fn    : ∀ (f : Type → Type) [Monad f],
          (∀ i, f (ℭ.V i)) → (∀ q, ℭ.rel q q₀ → f (ℭ.R q)) → f α
  param {κ₁ κ₂ : Type → Type} [Monad κ₁] [Monad κ₂]
    (A : MonadAction κ₁ κ₂)
    {ι₁ : ∀ i, κ₁ (ℭ.V i)} {ι₂ : ∀ i, κ₂ (ℭ.V i)}
    (f₁ : ∀ q, ℭ.rel q q₀ → κ₁ (ℭ.R q))
    (f₂ : ∀ q, ℭ.rel q q₀ → κ₂ (ℭ.R q)) :
    (∀ i, A.rel Eq (ι₁ i) (ι₂ i)) →
    (∀ q hq, A.rel Eq (f₁ q hq) (f₂ q hq)) →
    A.rel Eq (fn κ₁ ι₁ f₁) (fn κ₂ ι₂ f₂)
```

`fn` takes any monad `f`, a way to read each input as an `f`-computation, and a way to fetch each dependency as an `f`-computation. The output has type `f α`. Monad polymorphism abstracts the runtime: the body of `fn` can only sequence reads and fetches through `pure` and `bind`.

`param` reads: for any monad action `A` between `κ₁` and `κ₂`, if the input and fetch handlers are pointwise `A.rel Eq`-related, the two instantiations of `fn` produce `A.rel Eq`-related results. The certificate is discharged constructively at each primitive (`Task.pure`, `Task.bind`, `Task.input`, `Task.fetch`); compositions inherit theirs via `do`-notation, so a task written in monadic style obtains one without explicit proof obligation.

The dependency constraint `ℭ.rel q q₀` is encoded in the type of the fetch handler: a task cannot ask for itself or for any cyclic dependency. The recursive definition of `compute` (below) terminates by induction on `ℭ.wf`. A configuration with cyclic dependencies has no terminating evaluation; requiring `ℭ.wf` rules out exactly those configurations.

=== Specification

A family of tasks indexed by target query is `Tasks ℭ := ∀ q, Task ℭ q (ℭ.R q)`. The reference semantics `compute` runs each task in `Id`, recursively recomputing every dependency with no memoisation:

```lean
def compute (tasks : Tasks ℭ) (ι : ∀ i, ℭ.V i) (q : ℭ.Q) : ℭ.R q :=
  (tasks q).fn Id ι (fun q' _ => compute tasks ι q')
termination_by ℭ.wf.wrap q
```

A `Value` pairs a result with a proof it equals `compute`:

```lean
structure Value (tasks : Tasks ℭ) (ι : ∀ i, ℭ.V i) (q : ℭ.Q) where
  val  : ℭ.R q
  spec : val = compute tasks ι q
```

`Build` is the interface every cached executor implements. The state `σ` advances as the build runs; the outer monad `n` carries execution effects; the inner `m` is a free monad for tracing or cancellation. Correctness is independent of `n` and `m`, holding via the `spec` field of `Value`.

```lean
structure Build (ℭ : BuildConfig) (J : Type) [Input ℭ J] (tasks : Tasks ℭ)
    (n m : Type → Type) : Type 1 where
  σ      : Type
  init   : J → σ
  inputs : σ → ∀ i, ℭ.V i
  set    : ∀ i, ℭ.V i → StateM σ Unit
  build  : ∀ q store, n (m (Value tasks (inputs store) q) × σ)
```

Any inhabitant of `Build` produces the same result as `compute`. @sec:build-inhabitants exhibits three: `Busy` (no caching), `LessBusy` (intra-build), and `Shake` (cross-build verifying traces).

=== Theorems for a fee <sec:free-theorem>

`LessBusy` and `Shake` run tasks in `StateM Cache`; correctness is stated against `compute`, which runs them in `Id`. The fee paid at task construction buys a framework-level lemma `Tasks.freeTheorem`: for any monad action with `Id` as the second monad, given pointwise-related inputs and fetches, the task result in the first monad is related to `compute` at the top-level query.

```lean
theorem Tasks.freeTheorem (tasks : Tasks ℭ) (q₀ : ℭ.Q)
    (F : MonadAction κ Id) (ι₀ : ∀ i, ℭ.V i) (ι₁ : ∀ i, κ (ℭ.V i))
    (fetch₁ : ∀ q, ℭ.rel q q₀ → κ (ℭ.R q))
    (hι     : ∀ i,    F.rel Eq (ι₁ i)        (ι₀ i))
    (hfetch : ∀ q hq, F.rel Eq (fetch₁ q hq) (compute tasks ι₀ q)) :
    F.rel Eq ((tasks q₀).fn κ ι₁ fetch₁) (compute tasks ι₀ q₀)
```

The proof has two steps. Apply the task's `param` with `F`, the supplied fetches in $κ$, and `fun q _ => compute tasks ι₀ q` as the second fetch family; the hypotheses `hι` and `hfetch` discharge the relatedness side-conditions. This yields

$
  F."rel" "Eq" thin ((sans("tasks") thin q_0).sans("fn") thin κ thin ι_1 thin sans("fetch")_1) thin ((sans("tasks") thin q_0).sans("fn") thin sans("Id") thin ι_0 thin (lambda q . sans("compute") thin sans("tasks") thin ι_0 thin q)).
$

Unfolding `compute` once on the right rewrites this to `compute tasks ι₀ q₀`. The certificate carried by each task is what turns this from an external appeal to parametricity into a theorem in Lean.

`LessBusy` and `Shake` supply the specific monad action, the _cache action_, relating stateful computations to pure values by "return the same value from every starting state":

```lean
def cacheAction : MonadAction (StateM (VCache tasks ι₀)) Id where
  rel P m b := ∀ s, P (m.run' s) b
  rel_pure hab _ := hab
  rel_bind hma hk s := hk _ _ (hma s) _
```

With this action, `Tasks.freeTheorem`'s conclusion specialises to: if every cache entry returned by `fetch` equals `compute` at its query, the cached task result equals `compute` at $q_0$. The full Shake proof, including the cross-input invariant that lets memos survive across builds, is in #ref(<ch:appendix-proofs>, supplement: none).
