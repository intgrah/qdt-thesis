#import "../../template.typ": metrics, num

== Build inhabitants <sec:build-inhabitants>

Four inhabitants of `Build` are verified against `compute`: `Busy` runs `compute` directly, `LessBusy` adds within-build memoisation, `Shake` adds persistent cross-build verifying traces, and `ShakeStandardRdeps` augments the persistent cache with reverse-dependency tracking so that an unchanged input short-circuits the trace walk entirely. Two effect-layer extensions, `ShakeTrace` and `ShakeCancel`, inherit the agreement theorem without revisiting the proof.

=== Busy

`Busy` calls `compute` directly. The build is from scratch each time and there is no cache. The agreement proof is by definition.

```lean
def Busy (tasks : Tasks ℭ) : Build ℭ J tasks Id Id where
  σ := J;  init := id;  inputs := Input.get
  set i v := modify (Input.set · i v)
  build q store := (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

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

The proof supplies the cache action of @sec:free-theorem. Each cached fetch returns the same value as `compute` (the cache entries carry their own proofs), so `Tasks.freeTheorem` gives the overall result.

The top-level definition ties `fetch` into the `Build` type:

```lean
def LessBusy (tasks : Tasks ℭ) : Build ℭ J tasks Id Id where
  ...  -- σ, init, inputs, set as in Busy
  build q store :=
    let ι₀ := Input.get store
    let (v, _) := LessBusy.fetch tasks ι₀ q (DHashMap.emptyWithCapacity 1024)
    (v, store)
```

An empty cache is passed as the initial state. Each `fetch` call populates it, and the returned `v` carries a proof that it equals `compute`.

=== Shake <sec:shake>

`LessBusy` starts fresh on each build. `Shake` persists the cache across builds, using fingerprints to determine which entries are still valid. Dependencies are tracked by dedicated records:

```lean
structure InputDepHash (I H : Type) where
  key : I;  hash : H
structure QueryDepHash (ℭ : BuildConfig) (q₀ : ℭ.Q) (H : Type) where
  q : ℭ.Q;  rel : ℭ.rel q q₀;  hash : H
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

On recompute the task evaluates as a free monad tree @swierstra2008datatypes, and the invariant proof uses `FM.evalTree_cross`: if two sets of inputs and dependencies agree at every position recorded in the trace (checked via injective embeddings $h_I : forall i. ℭ.V i arrow.hook H$ and $h_R : forall q. ℭ.R q arrow.hook H$), the free monad tree evaluates to the same result. The injectivity of the hash functions is what makes fingerprint comparison sound: `hash a = hash b` implies `a = b`. The verified Shake takes the embeddings as parameters; the elaborator instantiates them with the standard `Hashable`.

The verified Lean `Shake` lives in `Incremental/Shake/` and uses `runST` with mutable references for the memo table and in-progress cache.

=== Effect layers <sec:effect-layers>

The `Build` type carries two type constructors `n` and `m` that wrap each query's result:

```lean
build : ∀ q store, n (m (Value tasks (inputs store) q) × σ)
```

`n` is an outer effect threaded around the entire build step; `m` is an inner effect carried alongside the proven `Value`. `Busy`, `LessBusy`, and the basic `Shake` of @sec:shake all instantiate both to `Id`, the trivial effectless monad. Replacing one or the other with a richer monad gives a verified build system with new observable behaviour, without revisiting the correctness proof: the `Value` payload is unchanged, so its `spec` field still witnesses agreement with `compute`.

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
  CanCancel {α} : m α → Prop
  checkpoint : m PUnit
class LawfulMonadCancel (m) [Monad m] [MonadAttach m] [MonadCancel m] : Prop where
  canCancel_bind_imp : CanCancel (ma >>= k) →
    CanCancel ma ∨ ∃ a, CanReturn ma a ∧ CanCancel (k a)
  not_canCancel_pure : ¬ CanCancel (pure a : m α)
```

The `Id` monad has `CanCancel _ := False`, so the cancellation interface is trivially satisfied when no cancellation is warranted. For a cancellable monad (such as one that reads an `IO.Ref Bool`), `checkpoint` reads the cancellation flag and throws `Cancelled` if it is set. The `Shake` fetch loop is rewritten to call `MonadCancel.checkpoint` before each cache lookup:

```lean
def fetchCancel (persist) (ι₀) (q₀) := do
  monadLift (MonadCancel.checkpoint : m PUnit)
  let (vcache, cache) ← get
  if let some ⟨(v, _), _⟩ := vcache.get? q₀ then return v
  ...
```

Memos completed before the checkpoint that raised are persisted via the supplied `persist` callback, so the next build sees a populated store and re-fetches only the queries that were in flight. The top-level `ShakeCancel` packages this fetch into a `Build ℭ J tasks BaseIO (Except Cancelled)`; an inhabitant by construction, so the correctness theorem of @sec:free-theorem applies unchanged.

=== Reverse dependencies <sec:shake-standard-rdeps>

The basic `Shake` of @sec:shake verifies every cached entry on every build, since the only persistent state is the trace of input and query fingerprints. A no-op edit still walks the whole cache (@sec:incremental-eval). `ShakeStandardRdeps` adds a fourth verified inhabitant that records reverse-dependency edges as the build runs, and uses them at `set` time to mark the transitive closure of _possibly-dirty_ queries. A subsequent `build` skips both the input-fingerprint check and the recursive query-fingerprint walk for any query not in the dirty set.

The procedure is three steps. On recompute of a query $q$, for each input $i$ it read append $(i, q)$ to `inputRdeps`, and for each query $d$ it fetched append $(d, q)$ to `queryRdeps`. On `set i v` whose hash differs from the cached input, seed the dirty set with every $q$ such that $(i, q) ∈$ `inputRdeps`, then walk forward under `queryRdeps` to its transitive closure: every cached query that could have read $i$, directly or through a chain of fetches, becomes _possibly-dirty_. On `build q`, if $q$ is not in the dirty set and the cache has an entry for $q$, return it with no fingerprint check; otherwise recompute, append the new rdeps, and drop $q$ from the dirty set. Verification cost becomes O(invalidation set) instead of O(cache).

The persistent state extends Shake's cache with three arrays:

```lean
structure Persist where
  cache      : DHashMap ℭ.Q (Memo hI hR tasks)
  queryRdeps : Array (ℭ.Q × ℭ.Q)
  inputRdeps : Array (ℭ.I × ℭ.Q)
  dirty      : Array ℭ.Q
```

Each entry $(d, q)$ in `queryRdeps` records that query $q$ fetched $d$ during its last recompute; each $(i, q)$ in `inputRdeps` records that $q$ read input $i$. The `dirty` array is the working set of queries whose cached memo cannot be trusted.

Correctness is the conjunction of four invariants on `Persist`:

```lean
structure WellFormed (ι₀) (p : Persist) : Prop where
  sound : ∀ q mm, p.cache[q]? = some mm → q ∉ p.dirty →
    (∀ d ∈ mm.inputDeps, hI d.key (ι₀ d.key) = d.hash) ∧
    (∀ d ∈ mm.queryDeps, hR d.q (compute tasks ι₀ d.q) = d.hash)
  complete : ∀ q mm, p.cache[q]? = some mm →
    (∀ d ∈ mm.inputDeps, (d.key, q) ∈ p.inputRdeps) ∧
    (∀ d ∈ mm.queryDeps, (d.q, q) ∈ p.queryRdeps)
  closed : ∀ q mm, p.cache[q]? = some mm → ∀ d ∈ mm.queryDeps, d.q ∈ p.cache
  downClosed : ∀ q mm, p.cache[q]? = some mm → q ∉ p.dirty →
    ∀ d ∈ mm.queryDeps, d.q ∉ p.dirty
```

`Sound` says every clean cached memo's stored fingerprints still match the current inputs and dependencies, so its universally quantified `invariant` field discharges agreement with `compute` immediately. `Complete` says each cached dependency edge is registered in the rdeps arrays, which is what lets `set` find every cached entry affected by an input change. `Closed` says the cache is transitively populated below every cached entry. `DownClosed` says cleanliness is downward-closed under the dependency relation, so a clean memo can call `Sound.value` on its dependencies without revisiting them.

The `Build`'s state type is a subtype carrying `WellFormed` as an irrelevant proof:

```lean
σ := { sp : J × Persist // WellFormed (Input.get sp.1) sp.2 }
```

`init` returns the empty `Persist`, where every invariant is vacuous via `DHashMap.get?_emptyWithCapacity`. `set i v` first checks whether the new input hashes the same as the old; by injectivity of $h_I$ the input is then unchanged, and the existing `Persist` carries through with `WellFormed` transported by `Input.get j' = Input.get j`. Otherwise it appends the transitive rdeps closure of $i$ to `dirty`:

```lean
def invalidate (p : Persist) (i : ℭ.I) : Persist :=
  { p with dirty := p.dirty ++ closure p.queryRdeps (seedOf p.inputRdeps i) }
```

`closure` performs a bounded breadth-first walk over `queryRdeps`, with the bound `seed.size + rdeps.size + 1` justified by the nodup invariant on the visited set. `invalidate_preserves_downClosed` then establishes that every queryDep of any cached entry that remains clean after invalidation was already clean before it, since the closure is closed under the rdeps edge.

`build q` calls `populate q`, defined by well-founded recursion on `ℭ.rel`. The fast path applies when $q$ is not in `p.dirty` and the cache hits: `Sound.value` strips the memo's `invariant` field directly, returning the cached value with its agreement certificate. Otherwise `runWalk` traces the task tree as in @sec:shake, building a fresh `Memo` from the trace, and the four invariants are re-established on the inserted `Persist`:

- `Sound` and `Complete` extend across the insert via `recordRdeps_preserves_sound` and `recordRdeps_preserves_complete`, both routed through a single `cache_insert_cases` helper that case-splits on whether the lookup key equals the freshly inserted one.
- `Closed` and `DownClosed` lift from the runtime witnesses `hDepsInCache` and `hDepsNotDirty` carried by `runWalk`'s result: every query fetched during the recompute is now cached and clean.

Preservation of `Sound` across `invalidate` runs by well-founded recursion on `ℭ.rel`: at each cached entry still clean after invalidation, the inductive hypothesis at every queryDep reverifies its hash under the updated input (the dep is clean by `DownClosed` + `closure_step_closed`), and `mm.invariant` recovers agreement. The closure itself terminates by a lexicographic measure with an explicit fuel bound against the universe of queries reachable through `queryRdeps`. The full walkthrough is in @ch:appendix-proofs-rdeps.

@sec:incremental-eval reports `ShakeStandardRdeps` alongside the basic `Shake` and the unverified `shake-rdeps`.

=== Native implementations

Alongside the verified inhabitants, the repository ships three operational drop-in replacements: `Salsa`, a Lean rebuild-on-demand variant with reverse-dependency tracking; and `SalsaC` and `ShakeC`, C ports of `Salsa` and `Shake` compiled to native code and called through the Lean runtime ABI. All three implement the same `Build` interface as the verified inhabitants, so the elaborator and language server consume them interchangeably:

```lean
@[extern "lean_shake_build"]
opaque shakeCBuild [Input ℭ J] [BEq ℭ.I] [Hashable ℭ.I] [∀ i, Hashable (ℭ.V i)]
    [BEq ℭ.Q] [Hashable ℭ.Q] [∀ q, Hashable (ℭ.R q)] :
    Tasks ℭ → ∀ q, ShakeRT.Store ℭ J → ℭ.R q × ShakeRT.Store ℭ J

def ShakeC (tasks : Tasks ℭ) : Build ℭ J tasks Id Id where
  ...  -- σ, init, inputs, set as in Shake
  build q store := let (r, s) := shakeCBuild tasks q store; (⟨r, sorry⟩, s)
```

`Salsa`, `SalsaC`, and `ShakeC` are `Build` inhabitants whose `build` field carries the agreement certificate as a `sorry`: the axiom that the underlying implementation computes the same value as `compute` on the same `Tasks`. The C ports are #num(metrics.rows.shake_c) and #num(metrics.rows.salsa_c) lines respectively; they match Lean's runtime ABI (constructor field order and scalar layout for `Memo` and `Store`, closure arity for the `fetch` and `input` callbacks, reference counting protocol for allocated objects) and skip Lean's closure allocation and monadic bind dispatch on each query. They are selected when raw throughput is preferred over the structural proof carried by `Shake`. @sec:incremental-eval reports them alongside `Shake`.
