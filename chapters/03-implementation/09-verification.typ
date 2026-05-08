== Formal verification <sec:verification>

The build system framework is formalised in Lean 4 with machine-checked proofs. We refine the "Build Systems à la Carte" (BSALC) framework @mokhov2018build in three ways, each forced by the requirements of a dependently typed elaborator.

=== Refinements over BSALC

BSALC uses a single key type `k` with a uniform value type `v`. A type checker needs different result types for different queries: parsing returns a syntax tree, elaboration returns a typed term, diagnostics are an array of errors. Without dependent result types, every fetch would require a runtime cast. We separate the key space into _inputs_ `I` (file contents, set externally) and _queries_ `Q` (computed results), each with a dependent value type:

$ V : I -> "Type", quad R : Q -> "Type" $

BSALC does not address termination: the Haskell implementation simply assumes tasks do not cycle. For a total specification we need a well-foundedness condition. The dependency relation is indexed by the current input state, because different source files can induce different dependency orders among queries:

TODO: No it isn't

$
  sans("rel") : (Pi_i V(i)) -> Q -> Q -> sans("Prop"), quad sans("wf") : forall iota. sans("WellFounded")(sans("rel")_iota)
$

These are bundled into a configuration:

```lean
structure BuildConfig : Type 1 where
  I : Type; V : I → Type
  Q : Type; R : Q → Type
  rel : (∀ i, V i) → Q → Q → Prop
  wf : ∀ ι, WellFounded (rel ι)
```

TODO: fix

A task for query $q_0$ under input state $iota_0$ is polymorphic in an effect $f$. It receives two callbacks: one to read inputs, one to fetch query results. The fetch callback requires a proof that the fetched query precedes $q_0$ in the dependency relation:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [c f],
    (∀ i, f (ℭ.V i)) →
    (∀ q, ℭ.rel ι₀ q q₀ → f (ℭ.R q)) →
    f α
```

The polymorphism in $f$ is the key design: the elaborator's tasks are written once, and the build system chooses the monad. `compute` (the batch specification) instantiates $f$ with `Id`; LessBusy and Shake instantiate it with `StateM Cache`. The free theorem (@sec:free-theorem) exploits this polymorphism to prove they produce the same result.

=== Correctness

A correct build system produces the same result as `compute`, a reference semantics defined by well-founded recursion. `compute` runs each task in `Id` (the trivial monad, no effects), recursively recomputing every dependency from scratch:

```lean
def compute (tasks : Tasks c ℭ) (ι : ∀ i, ℭ.V i) (q : ℭ.Q) : ℭ.R q :=
  tasks q Id ι (fun q' _ => compute tasks ι q')
termination_by ℭ.wf.wrap q
```

A build system carries private state `σ` and returns a value with a proof that it equals `compute`:

```lean
structure Build (c) (ℭ : BuildConfig) (J : Type) [Input ℭ J] where
  σ : Type
  init : J → σ
  build :
    (tasks : Tasks c ℭ) → (q : ℭ.Q) → (store : σ) →
      { r : ℭ.R q // r = compute tasks (inputs store) q } × σ
```

Any inhabitant is correct by construction. The elaborator's `tasks` value is defined once and works with any `Build` inhabitant. This separation means the build strategy can be swapped without touching the elaborator: one can use a verified Lean implementation during development and a fast C implementation in production, confident that both compute the same results. Three build systems inhabit this type:

*Busy* calls `compute` directly. Correctness follows by definition.

```lean
def Busy : Build c ℭ J where
  build tasks q store :=
    (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

=== The free theorem <sec:free-theorem>

LessBusy and Shake run tasks in `StateM Cache`, a monad threading a cache of previously computed results. However correctness is stated against `compute`, which runs tasks in `Id` (the trivial monad with no effects). The free theorem establishes that a task produces the same result in both monads, provided the fetches return the same values.

We argue for the correctness of these build systems via _parametricity_ (Wadler @wadler1989theorems). For example, a function of type `∀ a, List a → List a` can only rearrange, duplicate, or drop elements --- it cannot inspect them, because `a` is abstract. This forces it to commute with `map`: whatever positions it selects, it selects the same way regardless of what occupies them. A `Task` is polymorphic in its monad in the same way: it can only sequence fetches and combine results, never inspect which monad it runs in. If the fetches return the same values in both monads, the task produces the same final result.

To formalise this, we define a `MonadAction` relating two monads --- a family of relations on their carrier types, preserving `pure` and `>>=`:

```lean
structure MonadAction (κ₁ κ₂ : Type → Type) [Monad κ₁] [Monad κ₂] where
  rel : (α → β → Prop) → κ₁ α → κ₂ β → Prop
  rel_pure : R a b → rel R (pure a) (pure b)
  rel_bind : rel R ma mb → (∀ a b, R a b → rel S (ka a) (kb b))
    → rel S (ma >>= ka) (mb >>= kb)
```

The free theorem then states: if inputs and fetches are pointwise related, the task result is related:

```lean
axiom Task.freeTheorem :
    (hι : ∀ i, F.rel Eq (ι₁ i) (ι₂ i)) →
    (hfetch : ∀ q hq, F.rel Eq (fetch₁ q hq) (fetch₂ q hq)) →
    F.rel Eq (t κ₁ ι₁ fetch₁) (t κ₂ ι₂ fetch₂)
```

Since `Task` is polymorphic in a type constructor `f` constrained by `Monad`, this requires higher-kinded parametricity (Voigtländer @voigtlander2009free). Parametricity cannot be proved internally in Lean; it is stated as an axiom. The axiom is incompatible with `Classical.choice`; the formalisation avoids choice throughout.

From the axiom, we derive `Tasks.freeTheorem`: specialising to `κ₁ := StateM Cache` and `κ₂ := Id`, if the cache provides the same values as `compute` for every fetch, the overall task result equals `compute`. The proof unfolds `compute` once and applies the axiom.

=== LessBusy

Busy recomputes every dependency from scratch, exponential in the depth of the dependency graph. LessBusy avoids this by caching results within a single build, so each query is computed at most once. Each cache entry is a dependent pair `{ r : ℭ.R q // r = compute tasks ι q }`, bundling a value with its correctness proof. The `fetch` function checks the cache first; on a miss, it runs the task, caches the result, and returns it:

```lean
def fetch (q₀ : ℭ.Q) :
    StateM VCache (Value q₀) := do
  if let some v := (← get).get? q₀ then return v
  let v ← run q₀ (fun q hq => fetch q)
  modify (·.insert q₀ v)
  return v
termination_by ℭ.wf.wrap q₀
```

Termination follows from the well-founded relation: each recursive `fetch` call provides a proof `ℭ.rel q' q₀`, so the recursion decreases. The `run` function executes the task and produces a proven `Value`; this is where the free theorem is used.

The proof constructs a concrete `MonadAction (StateM VCache) Id`:

```lean
def action : MonadAction (StateM VCache) Id where
  rel P m b := ∀ s, P (m s).1 b
```

This says: a stateful computation `m` is related to a pure value `b` when, from any starting state, `m`'s return value satisfies the relation with `b`. Each cached fetch returns the same value as `compute` (the cache entries carry their own proofs), so `Tasks.freeTheorem` gives the overall result.

The top-level definition ties `fetch` into the `Build` type:

```lean
def LessBusy : Build Monad ℭ J where
  build tasks q store :=
    let ι₀ := Input.get store
    let (v, _) := fetch tasks ι₀ q (DHashMap.empty)
    (v, store)
```

The empty cache is passed as the initial state. Each `fetch` call populates it, and the returned `v` carries a proof that it equals `compute`.

=== Shake

LessBusy starts fresh on each build; the cache is discarded between invocations. Shake fills this gap by persisting the cache across builds, using fingerprints to determine which entries are still valid. Each cached `Memo` carries a universally quantified invariant:

```lean
structure Memo (q : ℭ.Q) where
  value : ℭ.R q
  inputDeps : List ((i : ℭ.I) × H)
  deps : List (Σ' (q' : ℭ.Q) (_ : ℭ.rel q' q), H)
  invariant :
    ∀ (ι : ∀ i, ℭ.V i),
      (∀ p ∈ inputDeps, hI p.1 (ι p.1) = p.2) →
      (∀ p ∈ deps, hR p.1 (compute tasks ι p.1) = p.2.2) →
      value = compute tasks ι q
```

The invariant says: for _any_ input function `ι`, if every recorded input fingerprint matches `ι` and every recorded dependency fingerprint matches `compute` under `ι`, then `value` equals `compute tasks ι q`. This is universally quantified over `ι`: the same memo is valid across builds with different inputs, as long as the fingerprints match.

On a cache hit, `verifyInputs` checks each recorded input fingerprint against the current inputs, and `verifyDeps` recursively fetches each dependency (getting a proven `Value`) and checks its fingerprint. If both pass, the memo's `invariant` directly gives the correctness proof.

On a cache miss, `runRecompute` evaluates the task via a free monad tree and builds a fresh `Memo`. The invariant proof uses `FM.evalTree_cross`: if two sets of inputs and dependencies agree at every position recorded in the trace (checked via injective embeddings `hI : ℭ.V i ↪ H` and `hR : ℭ.R q ↪ H`), the free monad tree evaluates to the same result. The injectivity of the hash functions (`Function.Embedding`) is what makes fingerprint comparison sound: `hash a = hash b` implies `a = b`. In practice, the `Hashable` instances use 64-bit hashes that are not injective; collisions are possible but astronomically unlikely. The proof assumes an ideal hash function, an injective function into 64 bit integers.

The elaborator's tasks are a single `Tasks` value, independent of which on`Build` executes them --- incremental elaboration is provably equivalent to `compute`.

The formalisation comprises approximately 1,500 lines of Lean across the core library (Basic, Busy, LessBusy, Shake, FreeTheorem, FreeMonad).
