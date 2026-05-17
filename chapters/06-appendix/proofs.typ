= Verification of Shake <ch:appendix-proofs>

This appendix walks through the Lean proof that the Shake cache is sound. It uses the build framework of #ref(<sec:build-framework>, supplement: none): each query $q$ has a result type, each input $i$ has a value type, the family of tasks describes how to compute every query, and the reference semantics, called compute, is defined by well-founded recursion. Code is excerpted from `Incremental/Basic.lean`, `Incremental/FreeMonad.lean`, and `Incremental/Shake/Basic.lean`.

== The proof obligation

Shake records what it observed during a build using two small record types. An #emph[input dependency] is a pair $(i, h)$ where $i$ is the input that was read and $h$ is the fingerprint of the value it returned. A #emph[query dependency] is a triple $(q, π, h)$: the fetched query, a proof that $q$ precedes the current query in the well-founded order, and the fingerprint of the fetched result. Both records are parametric in a hash type $H$. Concrete builds instantiate $H$ to 64-bit integers, but the verification only relies on injectivity of two hash embeddings: one for input values, written $h_I$, and one for query results, written $h_R$. The cache-miss step takes both as parameters.

A Shake #emph[memo] for a query $q$ bundles a computed value with arrays of these records and a universally quantified invariant (`Memo`):

```lean
structure Memo (q : ℭ.Q) where
  value : ℭ.R q
  inputDeps : Array (InputDepHash ℭ.I H)
  queryDeps : Array (QueryDepHash ℭ q H)
  invariant :
    ∀ (ι : ∀ i, ℭ.V i),
      (∀ p ∈ inputDeps, hI p.key (ι p.key) = p.hash) →
      (∀ p ∈ queryDeps, hR p.q (compute tasks ι p.q) = p.hash) →
      value = compute tasks ι q
```

The invariant promises that whenever every recorded input fingerprint agrees with $ι$ and every recorded dependency fingerprint agrees with what compute returns under $ι$, the stored value equals the reference value at $q$ under $ι$. Quantifying over $ι$ is what lets a memo persist across builds: the same record stays valid under any input change that does not disturb the fingerprints.

The cache-miss step of Shake executes the task once under the current input function, call it $ι_0$, and packages the result into a fresh memo. The proof obligation is its invariant field, named `cacheMiss_invariant`: from observations made on a single run under $ι_0$, derive the universally quantified statement above. Discharging it has three ingredients: a parametricity interface for tasks (#ref(<sec:parametric-task>, supplement: none)), a free-monad reification of tasks under which a cross-input lemma is provable by induction (#ref(<sec:fm-reification>, supplement: none)), and an instrumented run that bridges the imperative recompute back to the reification (#ref(<sec:trace-action>, supplement: none)). #ref(<sec:cache-miss>, supplement: none) assembles them.

== Parametric task interpretation <sec:parametric-task>

Each task is a parametric function: given any monad $f$ and an interpretation of inputs and fetches in $f$, it produces a value in $f$. To reason about two different interpretations of the same task simultaneously, the formalisation uses the #emph[monad actions] of #ref(<sec:build-framework>, supplement: none). A monad action between two monads $κ_1$ and $κ_2$ is a function that, given any relation $R$ between two (possibly distinct) types $α$ and $β$, returns a relation between computations of type $κ_1 thin α$ and $κ_2 thin β$. Write this lifted relation as $R^*$. It is required to satisfy two closure laws:

- Respect for pure: if $R(a, b)$ then $R^*("pure"(a), "pure"(b))$.
- Respect for bind: if $R^*(m_1, m_2)$ holds, and whenever $R(a, b)$ the continuations satisfy $S^*(k_1(a), k_2(b))$, then $S^*(m_1 ">>=" k_1, m_2 ">>=" k_2)$.

A canonical example is a logical relation parameterised by a state: pair stateful computations whose return values are related, after running both from any starting state. The trace action of #ref(<sec:trace-action>, supplement: none) is one such; the appendix uses two others.

Every task carries a parametricity certificate (`Task.param`): for any monad action $A$ and any two input families and two fetch families related pointwise by $A$ at the equality relation, the two interpretations of the task itself are related by $A$ at equality. The certificate is populated constructively by the four primitive task constructors, so the proofs depend on no external parametricity axiom. Choosing the action (deciding what "related" means) is what specialises this generic statement into the lemma needed at each step of the soundness proof.

== Free-monad reification <sec:fm-reification>

Tasks are opaque parametric functions, so direct induction over them is impossible. To recover induction, each task is reified into a free monad whose constructors mirror the three primitive moves a task can make:

```lean
inductive FM (ℭ : BuildConfig) (q₀ : ℭ.Q) (α : Type) : Type
  | pure (a : α) : FM ℭ q₀ α
  | input (i : ℭ.I) (k : ℭ.V i → FM ℭ q₀ α) : FM ℭ q₀ α
  | fetch (q : ℭ.Q) (hq : ℭ.rel q q₀) (k : ℭ.R q → FM ℭ q₀ α) : FM ℭ q₀ α
```

A tree is interpreted against an input function $ι$ and a dependency oracle $r$. The function `evalTree` walks the tree, taking inputs from $ι$ and fetches from $r$, and returns the value at the eventually reached leaf. Two companion functions, `evalTrace_inputs` and `evalTrace_deps`, return the lists of input and dependency entries visited #emph[along the path the tree takes under the supplied oracles]. Both lists depend on $ι$ and $r$: at an input node the continuation is fed the value $ι(i)$, so different input functions can drive the walker into different subtrees and the recorded trace differs accordingly. Each input entry records the input index and the value read; each dependency entry records the query, its precedence proof, and the value returned by the oracle. An immediate consequence (lemma `evalTrace_deps_value`) is that, for every entry in the dependency trace, the recorded value is precisely what the oracle returned at that query.

The cross-input lemma `evalTree_cross` states that if a second pair of oracles agrees with the first at every entry the first pair caused to be recorded, then the tree evaluates to the same result under both pairs. The proof is by structural induction on the tree. At an input or fetch node, the head of the recorded trace pins down the value used at that step, forcing both evaluators to descend into the same continuation; the inductive hypothesis handles the rest.

Two further FM primitives package a single move as a tree returning its result: `pureInput` produces an input node whose continuation is `pure`, and `pureFetch` does the same for fetch. Using them, every task can itself be reified by interpreting it in the free monad: `tasksTree` is the tree obtained by running the task at $q_0$ in FM with these two primitives as the input and fetch interpretations.

```lean
def tasksTree (tasks : Tasks ℭ) (q₀ : ℭ.Q) : FM ℭ q₀ (ℭ.R q₀) :=
  (tasks q₀).fn (FM ℭ q₀) FM.pureInput FM.pureFetch
```

To relate this transcript to the reference semantics, define a monad action between FM and the identity monad whose underlying relation pairs a tree with a value when evaluating the tree produces that value. Closure under pure is immediate. Closure under bind uses an `evalTree_bind` equation showing that evaluating a tree then evaluating the continuation on the result equals evaluating the bound tree directly. Specialising the task's parametricity certificate at this action with the same $ι$ and the same oracle on both sides yields the bridge lemma `tasksTree_eval_compute`:

```lean
theorem tasksTree_eval_compute (tasks : Tasks ℭ) (q₀ : ℭ.Q)
    (ι : ∀ i, ℭ.V i) :
    FM.evalTree ι (compute tasks ι) (tasksTree ℭ tasks q₀) =
      compute tasks ι q₀
```

Composing this bridge with the cross-input lemma lifts the latter from FM to the reference semantics. The statement uses the trace of the syntactic transcript under the first input function:

```lean
theorem compute_cross (tasks : Tasks ℭ) (q₀ : ℭ.Q)
    (ι ι' : ∀ i, ℭ.V i)
    (hin : ∀ p ∈ FM.evalTrace_inputs ι (compute tasks ι)
        (tasksTree ℭ tasks q₀), ι' p.i = p.v)
    (hdep : ∀ p ∈ FM.evalTrace_deps ι (compute tasks ι)
        (tasksTree ℭ tasks q₀),
      compute tasks ι' p.q = p.r) :
    compute tasks ι q₀ = compute tasks ι' q₀
```

This is the closing tool of the appendix: two input functions that agree at the trace entries produced by the first compute to the same value at $q_0$.

== Trace action <sec:trace-action>

The cross-input lemma above reasons about trees, but Shake runs the task in a state-transformer monad that accumulates two arrays as the task executes. The recording is asymmetric. Each input read pushes a fresh hashed input entry onto the input array, unconditionally: reading an input is cheap, and verifying a duplicate at cache-hit time costs nothing. Each fetched dependency, by contrast, is pushed onto the dependency array #emph[only if no entry with the same query is already there]. The reason is that at cache-hit time the dependency array is replayed to recursively verify each fetched query, and fetching the same query twice would defeat the purpose of the cache.

The deduplicating push is a small operation, `dedupPush`: given a new entry and an accumulator, return the accumulator unchanged if it already contains an entry with the same query, and append the new entry otherwise. Folding `dedupPush` over a list of dependency entries (hashing each value along the way) gives the operation `pushAll`, which produces the final array Shake stores.

Deduplication discards information, but the soundness of recording only one representative per query is captured by `pushAll_complete`. The statement: if every entry in the input list satisfies that hashing its recorded value yields a fixed function of its recorded query (the "target" function from queries to hashes), then for every input entry the result array contains a witness entry with the same query and the same target hash. Concretely, after deduplication every distinct query has exactly one representative, and that representative carries the correct hash. The cache-miss proof instantiates the target with the function sending each query $q$ to $h_R$ applied to $q$ and to compute under $ι_0$ at $q$.

The bridge from the imperative run to the syntactic transcript is the monad action `traceAction`. Given an imperative computation and a tree, the relation says that on any successful return from any starting state, three things hold simultaneously:

- The produced value relates (under the underlying relation) to the value obtained by evaluating the tree at $ι_0$ and compute under $ι_0$.
- The final input array is the initial input array, extended by the hashed input trace of the tree at the same oracles.
- The final dependency array is the initial dependency array, extended via `pushAll` by the hashed dependency trace.

"Successful return" is captured by a `CanReturn` predicate: an imperative computation can return some final state-and-value pair when running it from a given starting state may yield that pair. For deterministic monads like the identity or pure state monads this is just functional equality of the run with `pure`; for richer monads (exceptions, IO) it picks out the genuinely possible returns.

Two atomic-task lemmas, `runInput'_rel` and `runFetch'_rel`, verify that the imperative primitives Shake uses for each move satisfy the trace-action relation against the syntactic primitives. The first says: running the imperative "read input $i$" primitive pushes the single hashed entry for $i$ at $ι_0(i)$ onto the input array and matches the trace of `pureInput`. The second says: running the imperative "fetch $q$" primitive (after consulting the cache to obtain a verified value $v$) pushes the deduplicated entry for $q$ at $v$ onto the dependency array and matches the trace of `pureFetch`. The proofs of both lemmas are direct: each imperative primitive is a single state update, and the corresponding tree primitive walks exactly one node.

Specialising the task's parametricity certificate at the trace action, with these two lemmas as the input and fetch hypotheses, yields a single statement: the full imperative run of the task at $q_0$ is trace-action-related to the full syntactic transcript `tasksTree`.

== Cache-miss invariant <sec:cache-miss>

Starting the imperative run from the empty initial state and instantiating the trace-action relation at the actual return gives three concrete observations about the final state: the value produced, the input array `ins`, and the dependency array `deps`. The first conjunct of the relation, combined with `tasksTree_eval_compute`, gives that the value equals compute at $q_0$ under $ι_0$. The second conjunct, with empty initial input array, says that `ins` is the input trace under $ι_0$ and compute under $ι_0$, hashed entry-wise and converted to an array. The third, with empty initial dependency array, says that `deps` is the result of folding `pushAll` over the dependency trace from the empty array.

These three observations are precisely the hypotheses of the named lemma:

```lean
theorem cacheMiss_invariant {ι₀ : ∀ i, ℭ.V i} {q₀ : ℭ.Q}
    {value : ℭ.R q₀}
    {ins : Array (InputDepHash ℭ.I H)}
    {deps : Array (QueryDepHash ℭ q₀ H)}
    (hval : value = compute tasks ι₀ q₀)
    (hin_trace : ins =
      ((FM.evalTrace_inputs ι₀ (compute tasks ι₀) (tasksTree ℭ tasks q₀)).map
        fun p => ⟨⟨p.i⟩, hI p.i p.v⟩).toArray)
    (hdep_trace : deps =
      pushAll hR (FM.evalTrace_deps ι₀ (compute tasks ι₀) (tasksTree ℭ tasks q₀))
        (#[] : Array (QueryDepHash ℭ q₀ H))) :
    ∀ (ι : ∀ i, ℭ.V i),
      (∀ p ∈ ins, hI p.key (ι p.key) = p.hash) →
      (∀ p ∈ deps, hR p.q (compute tasks ι p.q) = p.hash) →
      value = compute tasks ι q₀
```

Fix an arbitrary $ι$ together with the input-hash agreement and dependency-hash agreement assumed by the invariant. Below, an input entry's input index and recorded value are written `i` and `v`; a dependency entry's query, precedence proof, and recorded value are written `q`, `π`, and `r`; and the hash field on either kind of entry is written `hash`. The proof has three steps.

+ #emph[Input promotion.] Take an entry of the input trace under $ι_0$ with index `i` and recorded value `v`. By the second observation, the stored input array contains the hashed pair $(#text[`i`], h_I (#text[`i`], #text[`v`]))$. The input-hash agreement at this stored entry equates $h_I (#text[`i`], ι(#text[`i`]))$ with $h_I (#text[`i`], #text[`v`])$. Injectivity of $h_I$ at `i` strips the embedding, leaving $ι(#text[`i`]) = #text[`v`]$. So $ι$ and $ι_0$ agree at every entry of the input trace.
+ #emph[Dependency promotion.] Take an entry of the dependency trace under $ι_0$ and compute under $ι_0$, with query `q` and recorded value `r`. By `evalTrace_deps_value`, the recorded value `r` is compute at `q` under $ι_0$. Applying `pushAll_complete` with the target function sending each $q'$ to $h_R$ of $q'$ and compute at $q'$ under $ι_0$ produces a witness in the stored dependency array whose query is `q` and whose hash is the target value $h_R (#text[`q`], #emph[compute under] ι_0 #emph[at] #text[`q`])$. The dependency-hash agreement at the witness, applied to the same witness, equates $h_R (#text[`q`], #emph[compute under] ι #emph[at] #text[`q`])$ with $h_R (#text[`q`], #emph[compute under] ι_0 #emph[at] #text[`q`])$. Injectivity of $h_R$ at `q` strips this to compute at `q` under $ι$ equals compute at `q` under $ι_0$, which equals `r`. So compute under $ι$ and compute under $ι_0$ agree at every entry of the dependency trace.
+ #emph[Closing.] The cross-input lemma `compute_cross`, applied with the two agreements just established, gives compute at $q_0$ under $ι_0$ equals compute at $q_0$ under $ι$. Composing with the first observation (that the value equals compute at $q_0$ under $ι_0$) proves the value equals compute at $q_0$ under $ι$, as required.

Plugging this lemma into the cache-miss branch of Shake's run discharges the invariant field of the freshly built memo directly, completing the verified construction.
