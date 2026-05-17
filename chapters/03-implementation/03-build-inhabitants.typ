== Build inhabitants <sec:build-inhabitants>

Three inhabitants of `Build` are verified against `compute`: `Busy` runs `compute` directly, `LessBusy` adds within-build memoisation, and `Shake` adds persistent cross-build verifying traces. Two effect-layer extensions, `ShakeTrace` and `ShakeCancel`, inherit the agreement theorem without revisiting the proof.

=== Busy

`Busy` calls `compute` directly. The build is from scratch each time; there is no cache. The agreement proof is `rfl`.

```lean
def Busy (tasks : Tasks ℭ) :
    Build ℭ J tasks Id Id where
  σ      := J
  init   := id
  inputs := Input.get
  set i v := modify fun store => Input.set store i v
  build q store :=
    (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

`Busy` is the baseline against which every other inhabitant is checked.

=== LessBusy

`LessBusy` caches results within a single build, so each query is computed at most once per build. Each cache entry is a `Value`, which carries a proof that it equals `compute`. The `fetch` function checks the cache first; on a miss, it runs the task, caches the result, and returns it:

```lean
def fetch (q₀ : ℭ.Q) :
    StateM (VCache tasks ι₀) (Value tasks ι₀ q₀) := do
  if let some v := (← get).get? q₀ then return v
  let v ← run tasks ι₀ q₀ (fun q _ => fetch q)
  modify (·.insert q₀ v)
  return v
termination_by ℭ.wf.wrap q₀
```

Termination follows from the well-founded relation on queries. The `run` function executes the task and produces a proven `Value` via the free theorem.

The proof constructs a concrete `MonadAction (StateM VCache) Id`:

```lean
def action : MonadAction (StateM (VCache tasks ι₀)) Id where
  rel P m b := ∀ s, P (m.run' s) b
  rel_pure hab _ := hab
  rel_bind hma hk s := hk _ _ (hma s) _
```

A stateful computation `m` is related to a pure value `b` when, from any starting state, `m`'s return value satisfies the relation with `b`. Each cached fetch returns the same value as `compute` (the cache entries carry their own proofs), so `Tasks.freeTheorem` gives the overall result.

The top-level definition ties `fetch` into the `Build` type:

```lean
def LessBusy (tasks : Tasks ℭ) : Build ℭ J tasks Id Id where
  σ      := J
  init   := id
  inputs := Input.get
  set i v := modify fun store => Input.set store i v
  build q store :=
    let ι₀ := Input.get store
    let cache₀ : LessBusy.VCache tasks ι₀ := DHashMap.emptyWithCapacity 1024
    let (v, _) := LessBusy.fetch tasks ι₀ q cache₀
    (v, store)
```

An empty cache is passed as the initial state. Each `fetch` call populates it, and the returned `v` carries a proof that it equals `compute`.

=== Shake <sec:shake>

`LessBusy` starts fresh on each build. `Shake` persists the cache across builds, using fingerprints to determine which entries are still valid. Dependencies are tracked by dedicated records:

```lean
structure InputDep (I : Type) where
  key  : I

structure InputDepHash (I H : Type) extends InputDep I where
  hash : H

structure QueryDep (ℭ : BuildConfig) (q₀ : ℭ.Q) where
  q   : ℭ.Q
  rel : ℭ.rel q q₀

structure QueryDepHash (ℭ : BuildConfig) (q₀ : ℭ.Q) (H : Type)
    extends QueryDep ℭ q₀ where
  hash : H
```

Each cached `Memo` carries a universally quantified invariant over these records:

```lean
structure Memo (q : ℭ.Q) where
  value     : ℭ.R q
  inputDeps : Array (InputDepHash ℭ.I H)
  queryDeps : Array (QueryDepHash ℭ q H)
  invariant :
    ∀ (ι : ∀ i, ℭ.V i),
      (∀ p ∈ inputDeps, hI p.key (ι p.key) = p.hash) →
      (∀ p ∈ queryDeps, hR p.q (compute tasks ι p.q) = p.hash) →
      value = compute tasks ι q
```

The invariant says: for _any_ input function `ι`, if every recorded input fingerprint matches `ι` and every recorded dependency fingerprint matches `compute` under `ι`, then `value` equals `compute tasks ι q`. The universal quantification over `ι` is what lets the same memo be valid across builds with different inputs.

On a cache hit, `verifyInputs` checks each recorded input fingerprint against the current inputs, and `verifyDeps` recursively fetches each dependency (getting a proven `Value`) and checks its fingerprint. If both pass, the memo's `invariant` directly gives the correctness proof.

On a cache miss, `runRecompute` evaluates the task via a free monad tree @swierstra2008datatypes and builds a fresh `Memo`. The invariant proof uses `FM.evalTree_cross`: if two sets of inputs and dependencies agree at every position recorded in the trace (checked via injective embeddings $h_I : forall i. ℭ.V i arrow.hook H$ and $h_R : forall q. ℭ.R q arrow.hook H$), the free monad tree evaluates to the same result. The injectivity of the hash functions is what makes fingerprint comparison sound: `hash a = hash b` implies `a = b`. The verified Shake takes the embeddings as parameters; the elaborator instantiates them with the standard `Hashable`.

The elaborator's tasks are a single `Tasks` value, independent of which `Build` inhabitant executes them.

=== Effect layers <sec:effect-layers>

The `Build` type carries two type constructors `n` and `m` that wrap each query's result:

```lean
build : ∀ q store, n (m (Value tasks (inputs store) q) × σ)
```

`n` is an outer effect threaded around the entire build step; `m` is an inner effect carried alongside the proven `Value`. `Busy`, `LessBusy`, and the basic `Shake` of @sec:shake all instantiate both to `Id`, the trivial effectless monad. Replacing one or both with a richer monad gives a verified build system with new observable behaviour, without revisiting the correctness proof: the `Value` payload is unchanged, so its `spec` field still witnesses agreement with `compute`.

*Tracing.* `ShakeTrace` instantiates `n` with `TraceT ℭ.Q m`, a state transformer over a forest of dependency nodes recording the query, its wall-clock duration, and its child queries:

```lean
inductive DepNode (Q : Type) where
  | mk (q : Q) (durationNs : Nat) (children : Array (DepNode Q))

abbrev Forest (Q : Type) := Array (DepNode Q)
abbrev TraceT (Q : Type) (m : Type → Type) := StateT (Forest Q) m
```

Each invocation of the `Shake` fetch passes through `bracket`, which reads a monotonic clock before and after the inner computation, then pushes a fresh `DepNode` onto the surrounding trace:

```lean
def bracket (q : Q) (body : TraceT Q m α) : TraceT Q m α := fun outer => do
  let t0 ← IO.monoNanosNow
  let (a, inner) ← body #[]
  let t1 ← IO.monoNanosNow
  pure (a, outer.push (.mk q (t1 - t0) inner))
```

`ShakeTrace` is the standard `Shake` with `bracket` supplied to a generic `Build` parametrised by an `m` that supports the outer state and `IO`. The result of a build is a `Forest ℭ.Q` whose shape mirrors the dynamic dependency tree.

*Cancellation.* `ShakeCancel` instantiates `m` with `Except Cancelled` and constrains the surrounding monad with a `MonadCancel` class:

```lean
class MonadCancel (m : Type u → Type v) where
  CanCancel {α : Type u} : m α → Prop
  checkpoint : m PUnit

class LawfulMonadCancel (m : Type u → Type v)
    [Monad m] [MonadAttach m] [MonadCancel m] : Prop where
  canCancel_bind_imp : ∀ {α β} (ma : m α) (k : α → m β),
    CanCancel (ma >>= k) → CanCancel ma ∨ ∃ a, CanReturn ma a ∧ CanCancel (k a)
  not_canCancel_pure : ∀ {α} (a : α), ¬ CanCancel (pure a : m α)
```

The `Id` monad has `CanCancel _ := False`, so the cancellation interface is trivially satisfied when no cancellation is wanted. For a cancellable monad (such as a state transformer over `IO.Ref Bool`), `checkpoint` reads the cancellation flag and throws `Cancelled` if it is set. The `Shake` fetch loop is rewritten to call `MonadCancel.checkpoint` before each cache lookup:

```lean
def fetchCancel (persist) (ι₀) (q₀) :
    StateT (Store hI hR tasks ι₀) m (Value tasks ι₀ q₀) := do
  monadLift (MonadCancel.checkpoint : m PUnit)
  let (vcache, cache) ← get
  if let some ⟨(v, _), _⟩ := vcache.get? q₀ then return v
  ...
```

Memos completed before the checkpoint that raised are persisted via the supplied `persist` callback, so the next build sees a populated store and re-fetches only the queries that were in flight. The top-level `ShakeCancel` packages this fetch into a `Build ℭ J tasks BaseIO (Except Cancelled)`; an inhabitant by construction, so the correctness theorem of @sec:free-theorem applies unchanged.

=== Native implementations

Alongside the verified inhabitants, the repository ships three operational drop-in replacements: `Salsa`, a Lean rebuild-on-demand variant with reverse-dependency tracking; and `SalsaC` and `ShakeC`, C ports of `Salsa` and `Shake` compiled to native code and called through the Lean runtime ABI. All three implement the same `Build` interface as the verified inhabitants, so the elaborator and language server consume them interchangeably:

```lean
@[extern "lean_shake_build"]
opaque shakeCBuild
    [BEq ℭ.I] [Hashable ℭ.I] [∀ i, Hashable (ℭ.V i)]
    [BEq ℭ.Q] [Hashable ℭ.Q] [∀ q, Hashable (ℭ.R q)]
    [Input ℭ J] :
    Tasks ℭ → ∀ q,
    ShakeRT.Store ℭ J → ℭ.R q × ShakeRT.Store ℭ J

def ShakeC (tasks : Tasks ℭ) : Build ℭ J tasks Id Id where
  ...
  build q store :=
    let (r, s) := shakeCBuild tasks q store
    (⟨r, sorry⟩, s)
```

`Salsa`, `SalsaC`, and `ShakeC` are `Build` inhabitants whose `build` field carries the agreement certificate as a `sorry`: the axiom that the underlying implementation computes the same value as `compute` on the same `Tasks`. They are selected when raw throughput is preferred over the structural proof carried by `Shake`. @sec:incremental-eval reports them alongside `Shake`.
