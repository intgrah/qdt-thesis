= Evaluation <ch:evaluation>

We evaluate correctness, performance, and incrementality.

== Correctness

The primary test is the standard library: 2,200 lines of qdt code across 36 files, covering natural number arithmetic, propositional equality, well-founded recursion, sigma types, monadic abstractions, and the Ackermann function. Every definition is fully explicit and type-checked from scratch on each run.

Equality proofs serve as integration tests for the conversion checker: `Eq.refl.{0} Nat 6` at type `Nat.add 2 4 = 6` succeeds only if the elaborator correctly reduces `Nat.add 2 4` to `6` via iota-reduction.

== Batch elaboration performance

Cold-start elaboration of the full stdlib (no cached results) completes in 438ms (median of three runs: 447ms, 408ms, 438ms).

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

*Busy* calls `compute` directly. Correctness: `rfl`.

```lean
def Busy : Build c ℭ J where
  build tasks q store :=
    (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

*LessBusy* memoises intermediate results within a single build. Each cache entry pairs a value with its correctness proof. Correctness follows from the free theorem (below).

*Shake* extends memoisation across builds by storing fingerprints of each query's dependencies. On a subsequent build, if fingerprints still match, the cached value is reused. The correctness invariant lives inside each cached entry:

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

If every fingerprint recorded at build time still matches, the cached value equals what `compute` would produce. Shake takes injective fingerprint functions, so fingerprint equality implies value equality.

The elaborator's tasks are a single `Tasks` value, independent of which `Build` executes them --- incremental elaboration is provably equivalent to `compute`.

=== The free theorem

The correctness proofs of LessBusy and Shake rely on a _free theorem_ for tasks.

A `Task` is polymorphic in `f`: it works with any monad satisfying `c`, and cannot inspect which monad it runs in. If we run the same task in `Id` (as in `compute`) and `StateM Cache` (as in LessBusy), and both provide the same values for every fetch, the task must produce the same result. This is _relational parametricity_ @reynolds1983types @wadler1989theorems, extended to type constructor classes @voigtlander2009free and higher kinds @atkey2012relational:

```lean
axiom Task.freeTheorem :
    (hι : ∀ i, F.rel Eq (ι₁ i) (ι₂ i)) →
    (hfetch : ∀ q hq, F.rel Eq (fetch₁ q hq) (fetch₂ q hq)) →
    F.rel Eq (t κ₁ ι₁ fetch₁) (t κ₂ ι₂ fetch₂)
```

Parametricity cannot be proved internally in Lean, so it is stated as an axiom. Parametricity is incompatible with the axiom of choice; the formalisation avoids `Classical.choice` throughout. The proof strategy for LessBusy and Shake: show the cache provides the same values as `compute` for every fetch (by induction on the well-founded relation), then apply the free theorem.

The formalisation comprises approximately 1,500 lines of Lean 4 across the core library (Basic, Busy, LessBusy, Shake, FreeTheorem, FreeMonad).

== Incremental re-elaboration

We measure re-elaboration time after targeted edits, compared to batch.

TODO: table comparing incremental vs batch times for targeted edits.

== Discussion

TODO

