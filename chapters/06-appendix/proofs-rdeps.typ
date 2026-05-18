= Verification of reverse-dependency optimisation <ch:appendix-proofs-rdeps>

This appendix walks through the verification of `ShakeStandardRdeps`, the rdeps-augmented Shake inhabitant of @sec:shake-standard-rdeps. It reuses the cache-miss invariant of @ch:appendix-proofs and adds the structural invariants that let `set` and `build` short-circuit. The following code is from `Incremental/Shake/StandardRdeps.lean`.

== Persistent state and invariants

The persistent state extends Shake's `Cache` with two reverse-dependency arrays and a working set of dirty queries:

```lean
structure Persist where
  cache      : DHashMap ℭ.Q (Memo hI hR tasks)
  queryRdeps : Array (ℭ.Q × ℭ.Q)
  inputRdeps : Array (ℭ.I × ℭ.Q)
  dirty      : Array ℭ.Q
```

A pair $(d, q) ∈$ `queryRdeps` records that $q$'s last recompute fetched $d$; a pair $(i, q) ∈$ `inputRdeps` records that $q$ read input $i$. Four invariants over a `Persist` $p$ together form `WellFormed ι₀ p`:

```lean
def Sound (ι₀ : ∀ i, ℭ.V i) (p : Persist) : Prop :=
  ∀ q mm, p.cache.get? q = some mm → q ∉ p.dirty →
    (∀ d ∈ mm.inputDeps, hI d.key (ι₀ d.key) = d.hash) ∧
    (∀ d ∈ mm.queryDeps, hR d.q (compute tasks ι₀ d.q) = d.hash)

def Complete (p : Persist) : Prop :=
  (∀ q mm, p.cache.get? q = some mm → ∀ d ∈ mm.inputDeps, (d.key, q) ∈ p.inputRdeps) ∧
  (∀ q mm, p.cache.get? q = some mm → ∀ d ∈ mm.queryDeps, (d.q,   q) ∈ p.queryRdeps)

def Closed (p : Persist) : Prop :=
  ∀ q mm, p.cache.get? q = some mm → ∀ d ∈ mm.queryDeps, ∃ mm', p.cache.get? d.q = some mm'

def DownClosed (p : Persist) : Prop :=
  ∀ q mm, p.cache.get? q = some mm → q ∉ p.dirty →
    ∀ d ∈ mm.queryDeps, d.q ∉ p.dirty

structure WellFormed (ι₀ : ∀ i, ℭ.V i) (p : Persist) : Prop where
  sound      : Sound ι₀ p
  complete   : Complete p
  closed     : Closed p
  downClosed : DownClosed p
```

- _Sound_: a clean cached entry's recorded hashes match the live inputs and dependency values. Composed with `mm.invariant` (the universally quantified field of `Memo`, proved at cache-miss time by `cacheMiss_invariant`), it gives `value = compute tasks ι₀ q` on the spot.
- _Complete_: every dependency edge of every cached memo is registered in the rdeps arrays. Invalidating an input reaches every affected cached query through the rdeps graph.
- _Closed_: the cache is downward closed under the query-dependency relation: a cached memo never points at an absent dep.
- _DownClosed_: cleanliness is downward closed under the same relation: a clean memo's deps are clean.

The `Build`'s state is the subtype that carries `WellFormed` as an irrelevant proof:

```lean
σ := { sp : J × Persist // WellFormed (Input.get sp.1) sp.2 }
```

Each operation produces a fresh subtype value; the proof obligation discharged at each step is preservation of the four invariants.

== Reverse-dependency closure <sec:rdeps-closure>

`invalidate` extends the dirty set by the transitive rdeps closure of an input change:

```lean
def invalidate (p : Persist) (i : ℭ.I) : Persist :=
  { p with dirty := p.dirty ++ closure p.queryRdeps (seedOf p.inputRdeps i) }
```

`seedOf p.inputRdeps i` extracts the queries that have $i$ as a recorded input dependency. `closure` performs a bounded breadth-first walk over the `queryRdeps` edge relation starting from this seed.

Cycles in `queryRdeps` mean structural termination cannot see why the walk terminates. The recursion is instead made well-founded on a lexicographic measure with a static upper bound on the visited set's size:

```lean
def closureGo (rdeps : Array (ℭ.Q × ℭ.Q)) (bound : Nat) (worklist : List ℭ.Q)
    (visited : Array ℭ.Q) (hv : visited.size ≤ bound) : Array ℭ.Q :=
  match worklist with
  | []      => visited
  | k :: ws =>
    if visited.toList.contains k then closureGo rdeps bound ws visited hv
    else if h : visited.size < bound then
      let new := rdeps.foldl (init := []) fun acc (p, c) =>
        if p == k then c :: acc else acc
      closureGo rdeps bound (new ++ ws) (visited.push k) (by simp; omega)
    else visited
termination_by (bound - visited.size, ws.length)
```

- _Push branch._ `visited.size` grows; the measure drops in its first component.
- _Skip branch._ `worklist` shortens; the second component drops while the first stays equal.

The top-level `closure` instantiates `bound` at $|"seed"| + |"rdeps"| + 1$. Both characterising lemmas thread two additional invariants through the recursion: `visited.toList` is `Nodup`, and its elements lie in the ambient set `seed.toList ++ rdeps.toList.map (·.snd)`. The push branch preserves these via two auxiliary lemmas (`push_toList_nodup` adds $k$ to the nodup list because $k$ was not already there, `push_toList_inUniv` adds $k$ because $k$ came off the worklist which is itself contained in the ambient set).

The `else visited` branch is dead: if `visited.size = bound`, then by `List.Subperm.length_le` applied to the `Nodup` list against the ambient set, `visited.toList.length` is at most the ambient set's length, which is $|"seed"| + |"rdeps"| = "bound" - 1$, contradicting `visited.toList.length = bound`. `visited_size_lt` packages this contradiction.

Two lemmas characterise the result:

- `closureGo_worklist_subset` says every member of the worklist is in the result. Proof by structural induction over the worklist; recursive calls remain in range because of the `Nodup`/`Subperm` argument above.
- `closureGo_step_closed_aux` says the result is closed under the rdeps edge: if $k$ is in the result and $(k, q')$ is in `rdeps`, then $q'$ is too. The proof carries a stronger invariant through the induction: every visited $k$ has its rdeps targets either already visited or still in the worklist, and shows each step preserves it.

Specialising to `closure`:

```lean
theorem closure_step_closed (rdeps : Array (ℭ.Q × ℭ.Q)) (seed : Array ℭ.Q)
    (k : ℭ.Q) (hk : k ∈ closure rdeps seed)
    (q' : ℭ.Q) (he : (k, q') ∈ rdeps) :
    q' ∈ closure rdeps seed
```

Together with `closure_seed_subset` (every seed element ends up in the closure), it discharges `invalidate`'s preservation lemmas.

== Preservation under set <sec:rdeps-set>

`set i v` dispatches on whether the input value's hash changed:

- _Unchanged hash._ Injectivity of $h_I$ at $i$ gives that the input function is pointwise unchanged. The `Persist` is reused verbatim, and `WellFormed` transports across `Input.get j' = Input.get j` by `▸`.
- _Changed hash._ `set i v` produces `invalidate p i`. `Complete` and `Closed` ignore the dirty set and carry through unchanged; the two non-trivial preservation lemmas are:

```lean
theorem invalidate_preserves_downClosed
    (p : Persist) (i : ℭ.I) (hC : Complete p) (hD : DownClosed p) :
    DownClosed (invalidate p i)

theorem invalidate_preserves_sound
    (p : Persist) (ι₀ : ∀ i, ℭ.V i) (i : ℭ.I) (v : ℭ.V i)
    (hS : Sound ι₀ p) (hC : Complete p) (hCl : Closed p) (hD : DownClosed p) :
    Sound (Function.update ι₀ i v) (invalidate p i)
```

_DownClosed under invalidate._ Take a clean cached entry $(q, m)$ after invalidation and a queryDep $d$ of $m$. The post-invalidation dirty set is `p.dirty ++ closure …`, and cleanliness of $q$ means $q$ is in neither summand:

- From the original `DownClosed`, $d$.`q` $∉$ `p.dirty`.
- If $d$.`q` were in `closure`, then by `closure_step_closed` applied to the edge $(d.q, q) ∈$ `queryRdeps` (supplied by `Complete`), so would $q$ --- contradicting cleanliness.

So $d$.`q` is in neither summand and stays clean.

_Sound under invalidate._ By well-founded induction on `ℭ.rel`. The conclusion to prove at $q$ for a clean cached memo `mm` is that every recorded input fingerprint matches $h_I$ at the updated $ι₀$, and every recorded dep fingerprint matches $h_R$ at `compute` under the updated $ι₀$.

- _Input case._ By `Complete`, $(d$.`key`, $q) ∈$ `inputRdeps`. If $d$.`key` $= i$ then $q$ would be in the closure seed and hence dirty, contradiction; otherwise the input is unchanged at $d$.`key` and the old hash agreement applies.
- _Dep case_ at a queryDep $d$ of `mm`. The old `Sound` at $q$ (legal because $q ∉$ `p.dirty`, since $q$ is clean after invalidation, which only added to `dirty`) gives `hR d.q (compute tasks ι₀ d.q) = d.hash`. By `Closed`, $d$.`q` has a cached memo `mm′`; by the original `DownClosed` at $q$, $d$.`q` was clean before invalidation; by `closure_step_closed`, $d$.`q` is not in the closure either, so $d$.`q` stays clean after invalidation. The IH at $d$.`q` therefore gives that `mm′` is `Sound` under the updated $ι₀$. Apply `mm′.invariant` twice, once at the old $ι₀$ with the agreements from the old `Sound` at $d$.`q`, giving `mm′.value = compute tasks ι₀ d.q`, and once at the updated $ι₀$ with the agreements from the IH, giving `mm′.value = compute tasks (updated ι₀) d.q`. Composing, the two `compute`s at $d$.`q` agree. Rewriting the old `Sound`'s dep agreement at $d$ by this equality yields the required agreement under the updated input.

`wellFormed_invalidate` packages the four conclusions: `Complete` and `Closed` carry through unchanged, `DownClosed` and `Sound` use the preservation lemmas above.

== Preservation under build

`populate q` is defined by `ℭ.wf.fix` on `ℭ.rel`, with body `populateBody`. The result type at each query is

```lean
structure PopulateResult (q : ℭ.Q) (pIn : Persist) where
  persist        : Persist
  value          : Value tasks ι₀ q
  hWF            : WellFormed ι₀ persist
  hNotDirty      : q ∉ persist.dirty
  memo           : Memo hI hR tasks q
  hCache         : persist.cache.get? q = some memo
  hValEq         : memo.value = value.val
  hCacheMono     : ∀ q' mm', pIn.cache.get? q' = some mm' →
                     ∃ mm'', persist.cache.get? q' = some mm''
  hDirtyAntiMono : ∀ q', q' ∈ persist.dirty → q' ∈ pIn.dirty
```

so a successful populate carries: the updated `Persist` with its `WellFormed` proof, a verified `Value`, the inserted memo and its location in the cache, and two monotonicity witnesses (the new cache extends the old, the new dirty set is contained in the old). `populateBody` dispatches on whether the cached entry can be trusted:

_Fast path._ If $q$ is not in `p.dirty` and `p.cache.get? q = some mm`, then `Sound.value`

```lean
def Sound.value (hS : Sound ι₀ p) :
    ∀ q mm, p.cache.get? q = some mm → q ∉ p.dirty →
      mm.value = compute tasks ι₀ q :=
  fun q mm hG hN =>
    let ⟨hI', hR'⟩ := hS q mm hG hN
    mm.invariant ι₀ hI' hR'
```

strips `mm.invariant` against the live hash agreements and returns the cached value with its agreement certificate. The `Persist` is unchanged, so `WellFormed` carries through verbatim.

_Recompute path._ `populateRecompute` calls `runWalk`, a function that walks the free-monad reification `tasksTree ℭ tasks q` (from @ch:appendix-proofs) interpreting each `FM.input` against the live $ι₀$, each `FM.fetch q'` against a recursive `populate q'`, and recording the trace as it goes. Bind its result to $r$. `runWalk` returns

```lean
structure RunWalkResult (t : FM ℭ q₀ α) (pIn : Persist)
    (accQueryDeps : Array (QueryDepHash ℭ q₀ H)) where
  value          : α
  persist        : Persist
  hWF            : WellFormed ι₀ persist
  inputDepsList  : List (InputDepHash ℭ.I H)
  queryDepsArr   : Array (QueryDepHash ℭ q₀ H)
  hValue         : value = FM.evalTree ι₀ (compute tasks ι₀) t
  hInputDeps     : inputDepsList = (FM.evalTrace_inputs ι₀ (compute tasks ι₀) t).map
                                     (fun e => ⟨⟨e.i⟩, hI e.i e.v⟩)
  hQueryDeps     : queryDepsArr  = pushAll hR
                                     (FM.evalTrace_deps ι₀ (compute tasks ι₀) t)
                                     accQueryDeps
  hDepsInCache   : ∀ d ∈ FM.evalTrace_deps ι₀ (compute tasks ι₀) t,
                     ∃ mm, persist.cache.get? d.q = some mm
  hDepsNotDirty  : ∀ d ∈ FM.evalTrace_deps ι₀ (compute tasks ι₀) t,
                     d.q ∉ persist.dirty
  hCacheMono     : ∀ q' mm', pIn.cache.get? q' = some mm' →
                     ∃ mm'', persist.cache.get? q' = some mm''
  hDirtyAntiMono : ∀ q', q' ∈ persist.dirty → q' ∈ pIn.dirty
```

The three load-bearing fields are `hDepsInCache`, `hDepsNotDirty`, and the two monotonicity witnesses. Each `FM.fetch q` in the trace produced a `PopulateResult` at $q$; its `hCache` and `hNotDirty` witness that $q$ is cached and clean in the local persist after the child call. As the rest of `runWalk` runs further child calls, those witnesses survive thanks to the recursive `hCacheMono`/`hDirtyAntiMono`.

A fresh `Memo` is built from the trace, with `cacheMiss_invariant` (from @ch:appendix-proofs) discharging its universally quantified `invariant` field. The new cache is `r.persist.cache.insert q memo`, and the new dependency edges are added by `recordRdeps`:

```lean
def recordRdeps (q : ℭ.Q) (mm : Memo q) (p : Persist) : Persist :=
  let p := mm.inputDeps.foldl (init := p) fun p d =>
    { p with inputRdeps := p.inputRdeps.push (d.key, q) }
  mm.queryDeps.foldl (init := p) fun p d =>
    { p with queryRdeps := p.queryRdeps.push (d.q, q) }
```

Alongside, the dirty set drops $q$ via filter. The four `WellFormed` invariants on the resulting `Persist` are re-established by four preservation lemmas, all sharing one dispatch helper for reasoning about lookup-after-insert:

```lean
private theorem cache_insert_cases
    {p : Persist} {q q' : ℭ.Q} {memo : Memo q} {mm' : Memo q'}
    (hG : (p.cache.insert q memo).get? q' = some mm') :
    (∃ h : q = q', mm' = h ▸ memo) ∨ (q ≠ q' ∧ p.cache.get? q' = some mm')
```

Proof: rewrite with `DHashMap.get?_insert` and dispatch on `(q == q') = true`. In the `true` branch, `LawfulBEq` strips the boolean and `cases hG` substitutes `mm' = memo`; in the `false` branch, the lookup falls through to the underlying cache and $q ≠ q'$ comes from `beq_self_eq_true`.

The four preservation arms:

- `recordRdeps_preserves_sound`. On the inserted side ($q' = q$), apply `cacheMiss_verify_ins` and `cacheMiss_verify_deps`: each of these states that the freshly built `memo` has hash agreements at the trace, derived from the same trace observations Shake uses in @ch:appendix-proofs. On the inherited side ($q' ≠ q$), the dirty set has shrunk only by filtering out $q$, so $q' ∉$ filtered implies $q' ∉$ original, and the old `Sound` applies.
- `recordRdeps_preserves_complete`. On the inserted side, two helpers `inputPass_inputRdeps_adds` and `queryPass_queryRdeps_adds` witness that the freshly pushed rdeps edges $(d, q)$ for each $d ∈$ `memo.inputDeps`/`memo.queryDeps` are present. On the inherited side, two mono lemmas `foldl_inputRdeps_mono`/`foldl_queryRdeps_mono` carry the existing edges across the two pushes.
- `Closed` on the inserted entry: `hDepsInCache` from `runWalk` gives, for every dep $d$ in the trace, that $d.q$ is cached. The trace deps and `memo.queryDeps` differ only by the dedup-and-push pass; `pushAll_origin` matches each element of the output array to a trace dep with the same `.q`, so the cached witness lifts. A dual helper `cache_insert_get?_exists` then lifts the cached witness from the pre-insert cache to the inserted one.
- `DownClosed` on the inserted entry runs the same lift on `hDepsNotDirty` instead of `hDepsInCache`. On existing entries, filter-monotonicity preserves not-dirty.

`populate q` returns a `PopulateResult` whose `hWF` field is the new `WellFormed` and whose `value` field carries the agreement certificate `value = compute tasks ι₀ q`.

== Commentary

Two ideas carry the proof:

- `DownClosed` is what makes the recursion legal. The fast path of `populateBody` needs each dep clean for `Sound.value` to apply, and the well-founded induction in `invalidate_preserves_sound` needs each dep clean to invoke the IH at it.
- The Shake trick of universally quantifying `mm.invariant` over the input function carries through into the rdeps induction. Applying it twice at the same memo, once at the old $ι₀$, once at the updated $ι₀$, bridges the two `compute`s at a dep without revisiting Shake's cross-input lemma.

`Complete`, `recordRdeps_preserves_complete`, and the push-membership lemmas are mechanical: they record graph edges and replay them. The closure is a standard BFS with a static bound, with the wrinkle that the bound argument lets the `else visited` branch be dead rather than a graceful early exit. `cache_insert_cases` saves four near-identical proofs about lookup-after-insert from being written four times.
