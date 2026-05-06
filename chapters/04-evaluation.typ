= Evaluation <ch:evaluation>

We evaluate correctness, performance, and incrementality.

== Correctness

The primary test is the standard library: 2,200 lines of qdt code across 36 files, covering natural number arithmetic, propositional equality, well-founded recursion, sigma types, monadic abstractions, and the Ackermann function, via well-founded recursion.

Equality proofs exercise the conversion checker: `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeeds only if the elaborator correctly reduces `Nat.add 2 4` to `6` via iota-reduction.

== Batch elaboration performance

TODO: re-measure on final code with hardware spec.

== Conversion checking performance

We stress-test the evaluator and conversion checker with Church-encoded benchmarks from Kovacs's normalisation-bench @kovacs2023smalltt. These encode natural numbers as lambda terms, then check definitional equality between two independently computed values of the same normal form, forcing $n$ beta-reductions on each side.

#figure(
  table(
    columns: (auto, auto),
    align: (left, right),
    table.header([*Benchmark*], [*Time (ms)*]),
    [Nat 10K], [176],
    [Nat 100K], [1,708],
    [Nat 1M], [16,417],
  ),
  caption: [Church numeral conversion checking. Time scales linearly with $n$.],
)

For comparison, smalltt @kovacs2023smalltt handles Nat 5M in 90ms using HOAS closures compiled by GHC. The constant-factor gap is due to our defunctionalised closure representation: each beta-reduction re-interprets the body in an extended environment, whereas HOAS compiles the closure to a native function call.

== Scaling benchmarks

We compare wall-clock time between qdt and Lean 4 on synthetic programs of increasing size. Lean's time includes startup (~300ms) and kernel checking, which qdt does not perform. Each generator produces a file with $N$ definitions following a specific dependency pattern.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Benchmark*], [*$N$*], [*qdt (ms)*], [*Lean (ms)*]),
    [Discrete], [1,000], [60], [834],
    [Discrete], [5,000], [320], [2,995],
    [Discrete], [10,000], [692], [5,739],
    [Random], [1,000], [85], [901],
    [Random], [5,000], [479], [3,823],
    [Random], [10,000], [949], [7,439],
    [Chain], [100], [17], [368],
    [Chain], [500], [127], [672],
    [Chain], [1,000], [342], [952],
    [Triangle], [25], [22], [463],
    [Triangle], [50], [101], [964],
    [Triangle], [75], [274], [1,872],
    [Triangle], [100], [587], [3,074],
    [Triangle], [150], [1,835], [6,477],
  ),
  caption: [Elaboration time for synthetic benchmarks. Lean's time includes startup and kernel checking.],
)

- _Discrete_ ($n_i := sans("Nat.zero")$): independent definitions, isolates per-definition overhead.
- _Random_ ($n_i := sans("Nat.succ") thin n_j$ for random $j < i$): realistic dependency shape.
- _Chain_ ($n_i := sans("Nat.succ") thin n_(i-1)$): linear dependency chain, stresses recursive query resolution.
- _Triangle_ ($n_i := n_0 + n_1 + dots + n_(i-1)$): conversion-heavy, each definition reduces a sum of predecessors.

== Formal verification

The build system framework is formalised in Lean 4 with machine-checked proofs. We refine the "Build Systems à la Carte" framework @mokhov2018build with dependent types, separated inputs and queries, and a well-foundedness condition.

=== Formulation

The parameters are bundled into a configuration:

```lean
structure BuildConfig : Type 1 where
  I : Type; V : I → Type
  Q : Type; R : Q → Type
  rel : (∀ i, V i) → Q → Q → Prop
  wf : ∀ ι, WellFounded (rel ι)
```

Inputs (`I`, `V`) and queries (`Q`, `R`) are separated, with result types depending on the key --- different queries can return different types. The relation `rel` encodes the dependency order, indexed by the input state. It must be well-founded for any input.

The task type refines the original: inputs and queries have distinct callbacks, result types are dependent, and fetch requires a well-foundedness proof:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [c f],
    (∀ i, f (ℭ.V i)) →
    (∀ q, ℭ.rel ι₀ q q₀ → f (ℭ.R q)) →
    f α
```

The task receives two callbacks: `input` reads an input value `ℭ.V i`, and `fetch` retrieves a query result `ℭ.R q`. The fetch callback requires a proof that `q` precedes `q₀` in the dependency relation, making termination provable by well-founded recursion.

=== Correctness

A correct build system produces the same result as `compute`, a reference semantics defined by well-founded recursion. `compute` runs each task in `Id`, recursively computing every dependency from scratch --- exponential time, serving as a specification:

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

Any inhabitant is correct by construction. Three build systems inhabit this type:

*Busy* calls `compute` directly. Correctness is by definition --- the returned value is `compute`'s output.

```lean
def Busy : Build c ℭ J where
  build tasks q store :=
    (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

=== The free theorem

The correctness proofs of LessBusy and Shake both rely on a _free theorem_ for tasks, arising from relational parametricity @reynolds1983types @wadler1989theorems @voigtlander2009free @atkey2012relational.

A `Task` is polymorphic in `f` --- it works with any monad satisfying `c` and cannot observe which monad it runs in. To formalise this, we define a `MonadAction` relating two monads: a family of relations `rel` on their carrier types, preserving `pure` and `>>=`:

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

Parametricity cannot be proved internally in Lean; it is stated as an axiom. The axiom is incompatible with `Classical.choice`; the formalisation avoids choice throughout.

From the axiom, we derive `Tasks.freeTheorem`: specialising to `κ₁ := StateM Cache` and `κ₂ := Id`, if the cache provides the same values as `compute` for every fetch, the overall task result equals `compute`. The proof unfolds `compute` once and applies the axiom.

=== LessBusy

_LessBusy_ memoises intermediate results within a single build. Each cache entry is a dependent pair `{ r : ℭ.R q // r = compute tasks ι q }` --- a value with its correctness proof. The `fetch` function checks the cache first; on a miss, it runs the task, caches the result, and returns it:

```lean
def fetch (q₀ : ℭ.Q) :
    StateM VCache (Value q₀) := do
  if let some v := (← get).get? q₀ then return v
  let v ← run q₀ (fun q hq => fetch q)
  modify (·.insert q₀ v)
  return v
termination_by ℭ.wf.wrap q₀
```

Termination follows from the well-founded relation: each recursive `fetch` call provides a proof `ℭ.rel q' q₀`, so the recursion decreases. The `run` function executes the task and produces a proven `Value` --- this is where the free theorem is used.

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

_Shake_ extends memoisation across builds by storing fingerprints of each query's dependencies. Each cached `Memo` carries a universally quantified invariant:

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

The invariant says: for _any_ input function `ι`, if every recorded input fingerprint matches `ι` and every recorded dependency fingerprint matches `compute` under `ι`, then `value` equals `compute tasks ι q`. This is universally quantified over `ι` --- the same memo is valid across builds with different inputs, as long as the fingerprints match.

On a cache hit, `verifyInputs` checks each recorded input fingerprint against the current inputs, and `verifyDeps` recursively fetches each dependency (getting a proven `Value`) and checks its fingerprint. If both pass, the memo's `invariant` directly gives the correctness proof.

On a cache miss, `runRecompute` evaluates the task via a free monad tree and builds a fresh `Memo`. The invariant proof uses `FM.evalTree_cross`: if two sets of inputs and dependencies agree at every position recorded in the trace (checked via injective embeddings `hI : ℭ.V i ↪ H` and `hR : ℭ.R q ↪ H`), the free monad tree evaluates to the same result. The injectivity of the hash functions (`Function.Embedding`) is what makes fingerprint comparison sound: `hash a = hash b` implies `a = b`.

The elaborator's tasks are a single `Tasks` value, independent of which `Build` executes them --- incremental elaboration is provably equivalent to `compute`.

The formalisation comprises approximately 1,500 lines of Lean 4 across the core library (Basic, Busy, LessBusy, Shake, FreeTheorem, FreeMonad).

== Incremental re-elaboration

We measure re-elaboration time after targeted edits on the standard library, using a retained Shake store. The Shake build system is instrumented to count cache hits (queries whose fingerprints match and are reused) and recomputed queries. After a cold build populates the store, each edit modifies one input and triggers a rebuild against the existing cache.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Edit*], [*Time (ms)*], [*Speedup*]),
    [Cold build (no cache)], [1,027], [$1 times$],
    [No-op (retained store, no changes)], [129], [$8.0 times$],
    [Whitespace (append newline to entry file)], [127], [$8.1 times$],
    [Leaf (append definition to Ackermann.qdt)], [172], [$6.0 times$],
    [Hub (append definition to Nat.qdt)], [170], [$6.0 times$],
  ),
  caption: [Incremental re-elaboration of the standard library after targeted edits. Speedup is relative to cold build.],
)

The no-op rebuild verifies every fingerprint in the store but recomputes nothing --- the 129ms is the cost of traversing the dependency graph and checking hashes. The whitespace edit has the same cost: the green tree representation absorbs the whitespace change, the AST hashes the same, and no downstream query is invalidated.

The leaf edit appends a new definition to `Ackermann.qdt`, a file that no other file imports. The `declarationIndex` query for that file is invalidated (a new name appears), and the new definition is elaborated, but no other file's queries are affected. The hub edit appends a definition to `Nat.qdt`, which is imported by five other files. Despite the wider dependency fan-out, the rebuild takes the same time: the new definition does not change any existing constant's type or body, so the `constant` queries for existing Nat definitions hash the same, and early cutoff prevents the cascade from propagating to dependent files.

== Discussion

The incremental results demonstrate that the query-based architecture achieves its goal: after an edit, re-elaboration time is proportional to the amount of work that actually changed, not the size of the file or the number of dependents. The 6--8$times$ speedup over cold build on the standard library reflects the fact that most queries are unchanged after a typical edit.

The scaling benchmarks show that qdt's per-definition elaboration cost is competitive with Lean 4 (which additionally performs kernel checking). The conversion checker scales linearly on Church-encoded benchmarks, with a constant-factor gap from the defunctionalised closure representation.

The formal verification ensures that incremental results are provably equivalent to batch evaluation. The free theorem bridges the gap between the memoising build systems and the specification, with all proof obligations discharged except the parametricity axiom.

