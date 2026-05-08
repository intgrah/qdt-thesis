= Preparation <ch:preparation>

#import "@preview/curryst:0.5.1": prooftree, rule

#let Task = math.sans("Task")
#let Tasks = math.sans("Tasks")
#let Build = math.sans("Build")
#let Id = math.sans("Id")

== Dependent type theory

We implement a dependent type theory in the tradition of Martin-Löf. The reader is assumed to be familiar with the simply typed lambda calculus; we focus on the features that distinguish our system.

=== Syntax

The core theory maintains a syntactic distinction between _types_ and _terms_ (Tarski-style universes). The grammar is:

$
  ell &::= n | 0 | sans("succ")(ell) | max(ell, ell) & quad "(universe levels)" \
  A, B &::= sans("Type")_ell | Pi (x : A). B | sans("El")(t) & quad "(types)" \
  t, s &::= sans("Type'")_ell | x_i | c.{overline(ell)} | lambda (x : A). t | t thin s | Pi' (x : t). s | t.k | sans("let") thin x : A := t thin sans("in") thin s & quad "(terms)"
$

Universe levels $ell$ form an algebra of named variables $n$, zero, successor, and binary maximum. Types include universes $sans("Type")_ell$, dependent function types $Pi (x : A). B$, and the decoding operation $sans("El")(t)$ which converts a term-level code into a type. The term formers $sans("Type'")_ell$ and $Pi' (x : t). s$ are codes for the corresponding type formers. Variables $x_i$ are de Bruijn indices, $c.{overline(ell)}$ are global constants applied to universe level arguments, and $t.k$ is projection of the $k$-th field.

In Russell-style theories (as in Lean 4 itself), types and terms share a single syntactic sort: a $sans("Type")$ expression may appear both as a type and as a term. In our Tarski-style formulation, every position in the syntax tree is unambiguously either a type or a term. The decoding operation $sans("El")$ bridges the two: if $Delta; Gamma tack.r t : sans("Type")_ell$, then $sans("El")(t)$ is a well-formed type.

Russell-style universes admit a simpler implementation --- a single syntactic sort removes the need for `El` coercions and duplicated type/term formers. We choose Tarski style despite this cost because it admits a cleaner categorical semantics: $sans("Type")_ell$ is an object and $sans("El")$ is a morphism, corresponding directly to the structure of a universe in a category with families @dybjer1996internal. The two styles are known to be equivalent up to translation, but the translation is non-trivial, and the metatheory of Tarski universes is easier to present and reason about formally.

=== Judgement forms

The theory has six judgement forms, parameterised by a global environment $Delta$ and a local context $Gamma$:

$
  & tack.r Delta thin sans("sig")                   & quad & "global environment well-formedness" \
  & Delta; Gamma tack.r                             & quad & "context well-formedness" \
  & Delta; Gamma tack.r A thin sans("type")         & quad & "type well-formedness" \
  & Delta; Gamma tack.r t : A                       & quad & "term typing" \
  & Delta; Gamma tack.r A equiv B thin sans("type") & quad & "judgemental type equality" \
  & Delta; Gamma tack.r a equiv b : A               & quad & "judgemental term equality"
$

The global environment $Delta$ maps constant names to their definitions and types. The local context $Gamma$ is a telescope of typed bindings.

=== Type formation rules

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $sans("U")$,
    $Delta; Gamma tack.r sans("Type")_ell thin sans("type")$,
    $Delta; Gamma tack.r$,
  )),
  prooftree(rule(
    name: $sans("El")$,
    $Delta; Gamma tack.r sans("El")(t) thin sans("type")$,
    $Delta; Gamma tack.r t : sans("Type")_ell$,
  )),
  prooftree(rule(
    name: $Pi sans("-F")$,
    $Delta; Gamma tack.r Pi (x : A). B thin sans("type")$,
    $Delta; Gamma tack.r A thin sans("type")$,
    $Delta; Gamma, x : A tack.r B thin sans("type")$,
  )),
))

=== Typing rules

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $sans("Var")$,
    $Delta; Gamma tack.r x_i : Gamma(i)$,
    $Delta; Gamma tack.r$,
  )),
  prooftree(rule(
    name: $sans("Const")$,
    $Delta; Gamma tack.r c.{overline(ell)} : A$,
    $Delta; Gamma tack.r$,
    $Delta(c) = A$,
  )),
))

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $Pi sans("-I")$,
    $Delta; Gamma tack.r lambda (x : A). b : Pi (x : A). B$,
    $Delta; Gamma tack.r A thin sans("type")$,
    $Delta; Gamma, x : A tack.r b : B$,
  )),
  prooftree(rule(
    name: $Pi sans("-E")$,
    $Delta; Gamma tack.r f thin a : B[a\/x]$,
    $Delta; Gamma tack.r f : Pi (x : A). B$,
    $Delta; Gamma tack.r a : A$,
  )),
))

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $sans("Let")$,
    $Delta; Gamma tack.r sans("let") thin x : A := a thin sans("in") thin b : B[a\/x]$,
    $Delta; Gamma tack.r a : A$,
    $Delta; Gamma, x : A tack.r b : B$,
  )),
  prooftree(rule(
    name: $sans("Conv")$,
    $Delta; Gamma tack.r t : B$,
    $Delta; Gamma tack.r t : A$,
    $Delta; Gamma tack.r A equiv B thin sans("type")$,
  )),
))

The conversion rule allows a term of type $A$ to be given type $B$ whenever $A$ and $B$ are definitionally equal.

=== Definitional equality

Definitional equality is the congruence closure of the following computation rules:

- $beta$-reduction: $quad (lambda (x : A). b) thin a equiv b[a\/x]$
- $delta$-reduction: $quad c.{overline(ell)} equiv t quad$ when $Delta(c) = t$
- $zeta$-reduction: $quad sans("let") thin x : A := a thin sans("in") thin b equiv b[a\/x]$
- $eta$-conversion: $quad f equiv lambda (x : A). f thin x quad$ at function type
- $iota$-reduction: recursor applied to a constructor computes to the corresponding branch

The full relation includes congruence, symmetry, transitivity, and closure under the conversion rule for types.

=== Universe polymorphism

Definitions may be parameterised by universe level variables. For example:

```
def id.{u} (α : Type u) (x : α) : α := x
```

At each use site, levels are instantiated explicitly: `id.{0}` or `id.{v}`. There is no universe level inference.

=== Inductive types

The theory supports user-defined inductive families. An inductive declaration introduces a type, its constructors, and a _recursor_. We illustrate with `Vector`, a length-indexed list:

```
inductive Vector.{u} (α : Type u) : Nat → Type u where
  | nil : Vector α Nat.zero
  | cons (n : Nat) (head : α) (tail : Vector α n) : Vector α (Nat.succ n)
```

This declaration generates:
- The type `Vector.{u} : (α : Type u) → Nat → Type u`
- Constructors `Vector.nil.{u} : (α : Type u) → Vector α Nat.zero` and `Vector.cons.{u} : (α : Type u) → (n : Nat) → α → Vector α n → Vector α (Nat.succ n)`
- A recursor `Vector.rec.{v, u}` that eliminates a `Vector` by providing a case for `nil` and a case for `cons`:

```
Vector.rec.{v, u} :
  (α : Type u) →
  (C : (n : Nat) → Vector α n → Type v) →
  C Nat.zero (Vector.nil α) →
  ((n : Nat) → (head : α) → (tail : Vector α n) → C n tail → C (Nat.succ n) (Vector.cons α n head tail)) →
  (n : Nat) → (xs : Vector α n) → C n xs
```

All computation on inductives proceeds through the recursor. There is no primitive pattern matching. The computational rule (_iota-reduction_) fires when the recursor is applied to a constructor --- for example, applying `Vector.rec` to `Vector.cons` reduces to the `cons` branch with the fields and recursive result as arguments.

As an example, `Vector.map` applies a function to each element:

```
def Vector.map.{u, v} (α : Type u) (β : Type v) (n : Nat) (f : α → β)
    : Vector.{u} α n → Vector.{v} β n :=
  Vector.rec.{v, u} α (fun k _ => Vector.{v} β k)
    (Vector.nil.{v} β)
    (fun m h _ => Vector.cons.{v} β m (f h))
    n
```

Structures (single-constructor inductives) additionally support _projections_ $t.k$, which extract the $k$-th field from a constructor application.

== Elaboration

The typing rules above are declarative: they specify _what_ is well-typed, but not _how_ to check it. Elaboration is the algorithmic process that implements these rules. We describe the three components of our elaboration pipeline: bidirectional type checking directs the flow of type information, normalisation by evaluation decides definitional equality efficiently, and conversion checking controls how aggressively definitions are unfolded.

=== Bidirectional type checking

_Bidirectional type checking_ @dunfield2021bidirectional splits type checking into two mutually recursive judgements:

- *Checking* $Gamma tack.r e <= A$: verify that $e$ has type $A$, where $A$ is already known.
- *Inference* $Gamma tack.r e => A$: compute the type $A$ of $e$.

Type information flows _downwards_ in checking mode and _upwards_ in inference mode. The bidirectional presentation partitions each rule by mode:

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $sans("Var")$,
    $Gamma tack.r x_i => Gamma(i)$,
    $$,
  )),
  prooftree(rule(
    name: $sans("Anno")$,
    $Gamma tack.r (e : A) => A$,
    $Gamma tack.r e <= A$,
  )),
))

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $Pi sans("-I")$,
    $Gamma tack.r lambda x. b <= Pi (x : A). B$,
    $Gamma, x : A tack.r b <= B$,
  )),
  prooftree(rule(
    name: $Pi sans("-E")$,
    $Gamma tack.r f thin a => B[a slash x]$,
    $Gamma tack.r f => Pi (x : A). B$,
    $Gamma tack.r a <= A$,
  )),
))

#align(center, stack(
  dir: ltr,
  spacing: 2em,
  prooftree(rule(
    name: $sans("Sub")$,
    $Gamma tack.r e <= A$,
    $Gamma tack.r e => B$,
    $Gamma tack.r A equiv B thin sans("type")$,
  )),
))

Variables and applications are inferred; lambdas are checked against a known $Pi$ type. The subsumption rule $sans("Sub")$ bridges the modes: an inferred term may be used in a checking position if its inferred type is convertible with the expected type. Each term form has a unique applicable rule in each mode, so the checker is syntax-directed and does not backtrack.

This design avoids metavariables entirely. Systems with implicit arguments (Lean, Agda, Rocq) use metavariables and pattern unification to fill in unsynthesisable information; our system instead requires the programmer to provide all type information explicitly. This keeps the elaborator simple and --- crucially for incrementality --- means that elaboration of one definition cannot produce side effects (solved metavariables) that affect other definitions.

=== Normalisation by evaluation

The $sans("Sub")$ rule requires deciding definitional equality, which in turn requires reducing terms. _Normalisation by evaluation_ (NbE) @abel2013normalization evaluates syntax into a _semantic domain_ of values, where definitional equality can be checked by structural comparison.

The semantic domain consists of _values_ in weak head normal form. Closures --- a term paired with its environment --- stand for unevaluated function bodies. Neutral terms --- a variable or constant head applied to a _spine_ (a sequence of eliminators: applications and projections) --- represent computations blocked on an unknown.

The syntax uses de Bruijn _indices_ (counting from the innermost binder), while values use de Bruijn _levels_ (counting from the outermost binder). This avoids the need to shift indices during substitution. _Evaluation_ interprets syntax in an environment of values: variables are looked up, lambdas become closures, and applications perform beta-reduction or extend neutral spines. _Quotation_ converts values back to syntax by applying closures to fresh variables and converting levels to indices.

A constant $c.{overline(ell)}$ is not unfolded during initial evaluation --- it is left as a neutral. Its definition body is only retrieved and evaluated on demand, during weak head normalisation. This is significant for incrementality: the elaborator only creates a dependency on $c$'s definition body if conversion checking actually needs to unfold it.

=== Glued evaluation

Unfolding every definition to its normal form is wasteful: most conversion checks succeed or fail long before full normalisation. _Glued evaluation_ @kovacs2023smalltt addresses this by pairing each defined constant with two representations: a _folded_ form (the neutral $c.{overline(ell)}$) and an _unfolded_ form (the definition body, available lazily). A glued value $sans("glued")(c.{overline(ell)}, t)$ carries both.

Conversion checking first compares the folded (head) forms. If both sides have the same head constant, they may be equal without unfolding. Only when the heads differ does the checker force the unfolded form. This reduces the amount of computation and --- for incrementality --- reduces the number of definition bodies the elaborator depends on.

=== Conversion checking

With NbE and glued evaluation, conversion checking compares two values by structural descent: matching heads recurse into subterms, lambdas are applied to a fresh variable, and glued values with the same head constant are compared without unfolding. Following @kovacs2023smalltt, the checker uses three modes (rigid, flex, full) to control how eagerly definitions are unfolded, avoiding unnecessary work and, for incrementality, avoiding unnecessary dependencies. The full algorithm is described in @sec:conv.

=== The cost of elaboration

The dominant cost in elaboration is conversion checking. Type checking a single definition may trigger many conversion checks, each of which may unfold and normalise arbitrarily large terms. In a batch elaborator, this cost is paid once. But in an interactive setting, where a user edits one definition and expects rapid feedback, the question is: which of these conversion checks must be repeated?

A naive incremental system that invalidates everything after the edit point (as existing proof assistants do) repeats all of them. A query-based system can do better: it tracks which definitions each conversion check actually unfolded, and only repeats those checks whose dependencies have changed.

== Incremental computation

=== Existing approaches

Existing proof assistants offer limited incrementality. Lean 4 saves snapshots of elaboration state and resumes from the most recent valid checkpoint before an edit. Agda's `--caching` flag reuses results for the unchanged prefix of declarations in interactive mode. coq-lsp re-checks from the first modified sentence onward. All three treat the file as a sequence and reprocess a suffix: if definition 5 of 200 changes, definitions 6 through 200 are re-checked, regardless of whether they depend on definition 5.

For conventional languages, query-based incrementality is well-established. Rust-analyzer uses Salsa @salsa2018, a framework that tracks dependencies between queries and uses early cutoff to avoid recomputation when results are unchanged. The key property that makes this work for Rust is the clean separation between signatures and bodies: changing a function body without changing its type cannot affect downstream type checking, so downstream queries are never invalidated.

Fredriksson's _sixty_ @fredriksson2019sixty is the only prior work to apply query-based incrementality to a dependently typed language. It is built on Rock, a Haskell library inspired by the same "Build Systems à la Carte" framework. Sixty demonstrates that the approach is viable, but does not formalise the underlying build system or verify that incremental results agree with batch elaboration.

=== Why dependent types require dynamic dependencies

In a conventional compiler, the dependency graph between definitions is static: it is determined by imports and name resolution, and can be computed before type checking begins. A build system like Make, which requires dependencies to be declared upfront, suffices.

In a dependently typed elaborator, the dependency graph is not known upfront. Conversion checking may or may not need to unfold a given definition body, depending on the specific terms being compared --- which in turn depend on the types of other definitions, which may themselves require conversion checking. Dependencies are discovered _during_ elaboration.

This rules out build systems with static dependencies (Make, Bazel). What is needed is a system that supports _dynamic dependencies_ --- dependencies discovered during task execution --- and _early cutoff_ --- skipping dependents when a recomputed result is unchanged. Early cutoff is especially important because definition bodies change more often than their types: without it, any body change would cascade through every downstream definition that _might_ unfold it, even if the type is unaffected.

=== Build systems à la carte

Mokhov et al. @mokhov2018build observe that build systems solve the problem of bringing outputs up to date with respect to changed inputs. They introduce a framework that captures Make, Shake, Bazel, and others as instances of a single polymorphic type.

The central abstraction is the _task_, which describes how to compute a value from its dependencies. A task is polymorphic in an effect $f$:

$ Task thin c thin k thin v = forall f. thin [c thin f] => (k -> f thin v) -> f thin v $

A task receives a _fetch_ callback that retrieves the value of any key, and produces its own value in the effect $f$, chosen by the build system. The constraint $c$ on $f$ determines what the task can do with the results of its fetches: if $c = sans("Applicative")$, dependencies are static and known upfront; if $c = sans("Monad")$, the task may inspect the result of one fetch to decide what else to fetch, giving dynamic dependencies.

A collection of tasks $Tasks thin c thin k thin v = k -> sans("Maybe") thin (Task thin c thin k thin v)$ assigns a task to each non-input key. The paper decomposes build systems along two axes: the _scheduler_ (topological, restarting, or suspending) determines the order of task execution, while the _rebuilder_ (dirty bits, verifying traces, or constructive traces) determines whether a key needs recomputation:

#table(
  columns: 4,
  [], [Topological], [Restarting], [Suspending],
  [Dirty bit], [Make], [Excel], [-],
  [Verifying traces], [Ninja], [-], [Shake],
  [Constructive traces], [CloudBuild], [Bazel], [-],
  [Deep constr. traces], [Buck], [-], [Nix],
)

Dependent type elaboration requires monadic tasks (dynamic dependencies) and verifying traces (early cutoff). This places us at the Shake cell of the design space --- not by arbitrary choice, but because the properties of elaboration demand it.

The polymorphism of the `Task` type is what makes correctness modular. The elaborator defines tasks without knowing which build system will execute them; the build system executes tasks without knowing what they compute. Correctness decomposes into two independent obligations: (1) each task computes the right result given correct fetches, and (2) the build system calls tasks with valid inputs and caches correctly. This is analogous to the separation between Lean's elaborator and kernel: a small trusted component (the build system) guarantees a global property (incrementality is correct), independent of the complexity of the untrusted component (the elaborator).

=== Our formulation

We formalise the framework in Lean 4, making several refinements to the paper's Haskell presentation.

==== Separating inputs from queries

The paper uses a single key type `k` and distinguishes inputs from computed values by whether `Tasks` returns `Nothing`. We instead separate them at the type level: input keys `I` with values `V : I → Type`, and query keys `Q` with results `R : Q → Type`. A task can read inputs via `input i` and fetch query results via `fetch q`, as distinct operations:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [c f], (∀ i, f (V i)) → (∀ q, f (R q)) → f α
```

Tasks are now total --- every query has a task, and `Maybe` is eliminated. The dependent types `V : I → Type` and `R : Q → Type` allow different queries to have different result types, which is essential for a type checker where "what is the type of $x$?" and "what are the declarations in file $p$?" return values of different types.

==== Well-founded termination

In order to properly define which sets of tasks terminate, we require that the dependency relation on queries be well founded. This relation is dependent on the set of inputs: given any set of inputs, the relation must be well founded.

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

The relation `rel` is indexed by the input state `ι`: different source files can induce different dependency orders among queries. The task type is then refined: it carries the current input state `ι₀` and origin query `q₀`, and the `fetch` callback requires a proof that the fetched query `q` precedes `q₀` in the relation:

```lean
def Task (α : Type) : Type 1 :=
  ∀ (f : Type → Type) [Monad f],
    (∀ i, f (V i)) →            -- read an input
    (∀ q, rel ι₀ q q₀ → f (R q)) → -- fetch a query (with proof)
    f α                          -- produce a result
```

Reading this bottom-up: a `Task` producing `α` is a program that, given any monad `f`, an input-reading callback, and a query-fetching callback, produces `f α`. The monad is universally quantified so that the same task works under different build strategies. The proof argument `rel ι₀ q q₀` ensures that cycles are ruled out statically, making batch evaluation terminating by well-founded recursion.

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

The `inputs` field extracts the current input state from the build state, while `set` updates an input value. The separation of inputs from queries enforces by construction that a build system cannot modify its own computed results --- only inputs can be set externally.

== Related work

=== Efficient elaboration

Kovacs's _smalltt_ @kovacs2023smalltt demonstrates that high-performance elaboration is achievable through careful attention to evaluation strategies. It combines higher-order abstract syntax (HOAS), glued evaluation, and approximate conversion checking to achieve type-checking speeds that significantly outperform production systems on benchmarks. Several of these techniques --- particularly approximate conversion checking with rigid/flex/full modes and glued evaluation --- directly influenced the design of our elaborator.

=== Lean 4

Lean 4 @moura2021lean is the primary reference for the surface language and inductive type machinery. Our elaborator supports the same declaration forms (`def`, `inductive`, `structure`, `axiom`) and the same recursor-based elimination. The core theory departs from Lean's kernel in using Tarski-style rather than Russell-style universes, and in omitting metavariables and implicit arguments entirely.

== Starting point

Prior to starting the project, I had experience implementing type checkers for simply typed languages, but had not implemented a dependently typed elaborator or a build system. I was already familiar with type theory and had prior experience working on the OCaml compiler.

No implementation code was written before the project started. The project was initially planned in Rust, but an early switch was made to OCaml, and then to Lean 4. These transitions occurred during the project and are discussed in the Implementation chapter. No existing codebases were used as a basis; several projects were consulted as references, including smalltt, sixty, and Lean 4's source.
