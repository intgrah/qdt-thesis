#import "common.typ": *

== Incremental computation

The dominant cost in elaboration is conversion checking. Type checking a single definition may trigger many conversion checks, each of which may unfold and normalise arbitrarily large terms. In a batch elaborator, this cost is paid once. In an interactive setting, most of these checks need not be repeated --- only those whose dependencies actually changed. A query-based system can track which definitions each check unfolded, and skip the rest.

=== Build systems à la carte

Mokhov et al. @mokhov2018build observe that build systems solve the problem of bringing outputs up to date with respect to changed inputs. They capture Make, Shake, Bazel, and others as instances of a single polymorphic type.

The central abstraction is the _task_. A task is a recipe: it requests the values of other keys through a callback, and the build system decides how those requests are fulfilled. A task is polymorphic in an effect $f$:

$ Task thin c thin k thin v = forall f. thin [c thin f] => (k -> f thin v) -> f thin v $

A task receives a _fetch_ callback that retrieves the value of any key, producing its result in $f$. The constraint $c$ on $f$ determines what the task can do with fetched values: if $c = sans("Applicative")$, dependencies are static; if $c = sans("Monad")$, the task may inspect one result to decide what else to fetch, giving dynamic dependencies.

A collection of tasks $Tasks thin c thin k thin v = k -> sans("Maybe") thin (Task thin c thin k thin v)$ assigns a task to each non-input key. The paper decomposes build systems along two axes: the _scheduler_ (topological, restarting, or suspending) determines the order of task execution, while the _rebuilder_ (dirty bits, verifying traces, or constructive traces) determines whether a key needs recomputation:

#table(
  columns: 4,
  [], [Topological], [Restarting], [Suspending],
  [Dirty bit], [Make], [Excel], [-],
  [Verifying traces], [Ninja], [-], [Shake],
  [Constructive traces], [CloudBuild], [Bazel], [-],
  [Deep constr. traces], [Buck], [-], [Nix],
)

Dependent type elaboration requires monadic tasks (dynamic dependencies) and verifying traces (early cutoff), placing us at the Shake cell.

The polymorphism of `Task` makes correctness modular: the elaborator defines tasks without knowing which build system will execute them, and vice versa. Like the separation between Lean's elaborator and kernel, a small trusted component --- the build system --- guarantees a global property, independent of the untrusted elaborator's complexity.

=== Our formulation

We formalise the framework in Lean 4, with several refinements over the Haskell presentation.

==== Separating inputs from queries

The paper uses a single key type `k` and distinguishes inputs from computed values by whether `Tasks` returns `Nothing`. We instead separate them at the type level: input keys `I` with values `V : I -> Type`, and query keys `Q` with results `R : Q -> Type`. A task can read inputs via `input i` and fetch query results via `fetch q`, as distinct operations:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [c f], (∀ i, f (V i)) → (∀ q, f (R q)) → f α
```

Tasks are now total --- every query has a task, and `Maybe` is eliminated. The dependent types `V : I -> Type` and `R : Q -> Type` let different queries return different result types --- essential when "what is the type of $x$?" and "what are the declarations in file $p$?" have different answers.

==== Well-founded termination

We further refine the task type with a well-foundedness condition. To define which sets of tasks terminate, we require the dependency relation on queries to be well founded. The relation depends on the inputs: given any set of inputs, it must be well founded.

The parameters are bundled into a configuration record:

```lean
structure BuildConfig : Type 1 where
  I : Type
  V : I → Type
  Q : Type
  R : Q → Type
  rel : (∀ i, V i) → Q → Q → Prop
  wf : ∀ ι, WellFounded (rel ι)
```

`rel` is indexed by the input state `ι`: different source files can induce different dependency orders. The task type carries `ι₀` and `q₀`, and fetch requires a proof that `q` precedes `q₀`:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [c f],
    (∀ i, f (ℭ.V i)) →
    (∀ q, ℭ.rel ι₀ q q₀ → f (ℭ.R q)) →
    f α
```

Busy evaluation (the naive strategy that always recomputes) is then provably terminating by well-founded recursion, with no runtime cycle detection.

==== Build system structure

A build system is a structure with private state `σ`, an initialiser, and a build function:

```lean
structure Build (J : Type) [Input ℭ J] : Type 1 where
  σ : Type
  init : J → σ
  inputs : σ → ∀ i, ℭ.V i
  set : ∀ i, ℭ.V i → StateM σ Unit
  build : Tasks c ℭ → ∀ q, StateM σ (ℭ.R q)
```

`inputs` extracts the current input state from the build state; `set` updates an input. The separation enforces by construction that a build system cannot modify its own computed results --- only inputs can be set externally.

=== Correctness

A correct build system produces the same result as `compute`, a reference semantics defined by well-founded recursion. `compute` runs each task in the identity monad, recursively computing every dependency from scratch --- exponential time, but it serves as a specification, not a practical evaluator.

```lean
def compute (tasks : Tasks c ℭ) (ι : ∀ i, ℭ.V i) (q : ℭ.Q) : ℭ.R q :=
  tasks q Id ι (fun q' _ => compute tasks ι q')
termination_by ℭ.wf.wrap q
```

A verified `Build` returns not just a result, but a _proof_ that it equals `compute`:

```lean
structure Build (c) (ℭ : BuildConfig) (J : Type) [Input ℭ J] : Type 1 where
  σ : Type
  init : J → σ
  inputs : σ → ∀ i, ℭ.V i
  set : ∀ i, ℭ.V i → StateM σ Unit
  build :
    (tasks : Tasks c ℭ) → (q : ℭ.Q) → (store : σ) →
      { r : ℭ.R q // r = compute tasks (inputs store) q } × σ
```

`{ r // r = compute tasks (inputs store) q }` is a dependent pair: a value `r` with a proof that it agrees with `compute`. Any inhabitant of `Build` is correct by construction.

==== Busy

The simplest correct build system is _Busy_, which calls `compute` directly. Its correctness proof is `rfl`:

```lean
def Busy : Build c ℭ J where
  build tasks q store :=
    (⟨compute tasks (Input.get store) q, rfl⟩, store)
```

==== LessBusy: memoisation

_LessBusy_ memoises intermediate results, avoiding redundant recomputation within a single build. Each cache entry pairs a value with its correctness proof. Correctness follows from a _free theorem_ (see below): if the memoised values are correct, the overall build is correct.

==== Shake: incremental rebuilding

_Shake_ extends memoisation across builds by storing fingerprints of each query's dependencies. On a subsequent build, if the recorded fingerprints still match, the cached value is reused without re-executing the task.

The correctness invariant lives inside each cached entry:

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

In words: if every fingerprint recorded at build time still matches, the cached value equals what batch evaluation would produce.

`invariant` says: if every recorded input fingerprint still matches, and every dependency fingerprint matches, then `value` equals batch evaluation. Shake takes injective fingerprint functions `hI : ∀ i, ℭ.V i ↪ H` and `hR : ∀ q, ℭ.R q ↪ H`, so fingerprint equality implies value equality.

All three inhabit the same `Build` type, correct by construction. The elaborator's tasks are a single `Tasks` value, independent of which `Build` executes them --- incremental elaboration is provably equivalent to batch.

==== The free theorem

The correctness proofs of LessBusy and Shake rely on a _free theorem_ for tasks.

A `Task` is polymorphic in its effect $f$: it works with any monad satisfying $c$, and cannot inspect which monad it runs in. If we run the same task in `Id` (as in `compute`) and `StateM Cache` (as in LessBusy), and both provide the same values for every fetch, the task must produce the same result.

This is _relational parametricity_ @reynolds1983types @wadler1989theorems, extended to type constructor classes @voigtlander2009free and higher kinds @atkey2012relational. It is formalised as:

```lean
axiom Task.freeTheorem :
    (hι : ∀ i, F.rel Eq (ι₁ i) (ι₂ i)) →
    (hfetch : ∀ q hq, F.rel Eq (fetch₁ q hq) (fetch₂ q hq)) →
    F.rel Eq (t κ₁ ι₁ fetch₁) (t κ₂ ι₂ fetch₂)
```

In plain terms: a task cannot observe which monad it runs in, so two runs with pointwise-equal inputs produce the same output.

Parametricity cannot be proved internally in Lean, so it is stated as an axiom. The proof strategy for LessBusy and Shake: show the cache provides the same values as `compute` for every fetch (by induction on the well-founded relation), then apply the free theorem.
