= Implementation <ch:implementation>

This chapter describes the implementation of the elaborator. We follow the pipeline from source text to elaborated output: parsing, bidirectional type checking, normalisation by evaluation, conversion checking, inductive type elaboration, and the incremental build architecture that ties them together.

The implementation is written in Lean 4. Throughout this chapter, code snippets are excerpts from the implementation. // TODO: cite the specific line count.

== Architecture

We structure the elaborator as a collection of cooperating components. Source text is parsed by a hand-rolled monadic Pratt parser (#link(<sec:parsing>)[Section]) into a concrete syntax tree and a desugared abstract syntax tree. The AST is elaborated by a bidirectional type checker (#link(<sec:bidirectional>)[Section]) that uses normalisation by evaluation (#link(<sec:nbe>)[Section]) to reduce terms and a conversion checker (#link(<sec:conv>)[Section]) to decide definitional equality. Inductive declarations (#link(<sec:inductive>)[Section]) are elaborated into types, constructors, and recursors. All of this is decomposed into fine-grained queries memoised by a Shake-based build system (#link(<sec:incremental>)[Section]), and diagnostics and hover information are served to a VSCode extension via the Language Server Protocol (#link(<sec:lsp>)[Section]).

The core of the elaborator is the `ElabM` monad:

```lean
abbrev ElabM :=
  Task Monad config ι₀ q₀
  |> StateT ElabState
  |> ReaderT ElabContext
```

Here `config : BuildConfig` bundles the input and query types, while `ι₀` and `q₀` are the current input state and origin query carried along for the well-founded dependency relation.

Each transformer serves a distinct purpose:

- `Task` is the incremental query monad. Fetches through `Task.fetch` register dependencies in the Shake graph.
- `StateT ElabState` threads mutable elaboration state: the local environment of constants elaborated so far, a cache of fetched constants, and accumulated diagnostics and hover information.
- `ReaderT ElabContext` carries read-only context: the file path, the current declaration name, the universe parameter list of the current definition, and a path into the AST for diagnostic positions.

An earlier iteration of the design used `WriterT ElabInfo` instead of threading diagnostics through `ElabState`. Microbenchmarks showed this introduced significant overhead: every monadic `>>=` invoked the monoid append on the `ElabInfo` tuple, even when nothing was emitted. Replacing `WriterT` with a push-only interface over `StateT` arrays produced a measurable speedup on repeated-conversion benchmarks. // TODO: cite the specific numbers.

The components are connected by query dependencies, not by direct function calls. The parser's output is the `Val` of a `Key.cst` query; the AST is the `Val` of a `Key.ast` query; each declaration's elaborated form is the `Val` of a `Key.elabDecl` query, which depends on `Key.constant` queries for every referenced name. This structure makes the system incremental: when an input changes, the build system walks the dependency graph backward and invalidates exactly the queries that transitively depended on it.

== Parsing <sec:parsing>

The parser is a hand-rolled recursive descent Pratt parser, implemented as monadic combinators over `StateT State (Except ParseError)`. Parsing proceeds in two stages: the source text is first parsed to a concrete syntax tree (`Cst`) that retains trivia and exact token widths, and the CST is then desugared to an abstract syntax tree (`Ast`) that strips trivia and expands surface syntax.

The parser itself is unremarkable --- every language needs one, and Pratt parsing is a well-understood technique for operator precedence. The interesting design choice is the representation of the CST.

=== Green trees

The CST follows the _green tree_ pattern (used by Roslyn and rust-analyzer). Nodes and tokens are tagged by `SyntaxNodeKind`, and positions are not stored explicitly:

```lean
inductive Cst : Type
  | token (kind : SyntaxNodeKind) (val : String)
  | node (kind : SyntaxNodeKind) (children : Array Cst)
with
  @[computed_field]
  width : Cst → Nat
    | .token _ val => val.length
    | .node _ children => children.map width |>.sum
```

Each node carries only its kind and children; its _width_ is a computed field summing the widths of its descendants. A source position is then reconstructed by walking from the root and summing the widths of preceding children. Because nodes do not store absolute positions, two identical subtrees are structurally equal regardless of where they appear in the file --- the CST is `Hashable`, which lets the build system short-circuit recomputation when a file is edited in a way that does not affect a given subtree.

This matters for incrementality at the level _above_ parsing. Although the parser itself is not incremental (a full reparse on each edit is cheap), the memoised `Key.cst` query is keyed by file content, and downstream queries that depend on parsed subtrees benefit from structural equality of the CST. For example, the `Key.declarationIndex` query only depends on the kinds and names of top-level declarations; if an edit within one declaration does not change the enclosing structure, the declaration index's hash is unchanged and dependent queries are not invalidated.

=== Language server integration

Alongside the CST, parsing produces a `SourceMap` that bidirectionally maps paths in the CST to paths in the AST. A _path_ is a list of child indices from the root, so the root of either tree has path `[]`, its first child has path `[0]`, and so on. The bidirectional map is:

```lean
structure SourceMap where
  cstToAst : HashMap Path Path
  astToCst : HashMap Path Path
```

The map is populated during desugaring: as each AST node is constructed from a CST node, an entry is added to both tables. The language server uses this in both directions:

- _Hover_: given a cursor position, the CST is walked to find the path of the token under the cursor, then `cstToAst` gives the AST path. The elaborator's hover information is keyed by AST path, so the correct hover content is retrieved directly.
- _Diagnostics_: the elaborator records diagnostics at AST paths. `astToCst` maps these back to CST paths, which are then converted to source spans by summing widths.

Without the source map, a position-based language server would need to traverse the entire AST comparing source ranges at every node. The path-based lookup is $O("depth")$ on the tree rather than $O("size")$.

=== Error recovery

The parser uses lightweight error recovery: on encountering a parse error, a diagnostic is emitted and the parser attempts to continue at the next top-level declaration boundary (`def`, `inductive`, `axiom`, etc.). This ensures that a single malformed declaration does not prevent the rest of the file from being elaborated --- the language server continues reporting errors throughout the file.

A separate converter from `Lean.Syntax` to `Ast` is available via the metaprogramming framework, for writing inline test cases in Lean source files. This is not used by the main pipeline.

== Bidirectional type checking <sec:bidirectional>

Type checking is bidirectional. Instead of a single judgement $Gamma tack.r t : A$ that both produces and checks types, the algorithm is split into two mutually recursive functions:

- `inferTm ctx ast : OptionT ElabM (Tm n × VTy n)` --- given an AST, synthesise a core term and its type. Used when the expected type is not known or would be recomputed redundantly.
- `checkTm ctx expectedTy ast : ElabM (Tm n)` --- given an AST and an expected type, produce a core term of that type. Used when the expected type is already available from the surrounding context. Failure is handled internally by emitting a diagnostic and inserting a fresh axiom as a placeholder.

The split has three benefits. First, many terms can be checked without needing to synthesise their types: a lambda's parameter type is determined by the expected Pi type, so the parameter can be left unannotated. Second, the algorithm is syntax-directed --- each AST constructor dispatches to a specific case, avoiding the need for backtracking or unification. Third, errors are pinpointed: a mismatch between the expected and inferred type is reported at the exact subterm, rather than propagating upward.

The mode-switching rules are standard:

- *Lambdas* are checked. In checking mode against expected type $Pi (x : A). B$, the body is checked against $B$ in the context extended with $x : A$. If the AST's parameter has a type annotation, it must match $A$ (via conversion checking); otherwise $A$ is taken from the expected type.
- *Applications* are inferred. The function $f$ is inferred, yielding a type $T$. If $T$ is not a Pi type after weak head normalisation, the elaborator fails with a type error. Otherwise $T = Pi (x : A). B$ and the argument $a$ is checked against $A$; the result has type $B[a slash x]$.
- *Variables* are inferred by looking them up in the local context or the global environment.
- *Let-bindings* are inferred by first inferring the bound value's type, then checking the body in the extended context.
- *Universes* $sans("Type")_ell$ are inferred to have type $sans("Type")_(ell + 1)$.
- *Subsumption*: when an inferred term is used in a checking position, the inferred type is compared against the expected type by the conversion checker.

The core loop is `inferTm`/`checkTm`, mutually recursive with a helper `checkIdent` that handles variable lookup (checking the local context first, then the global environment). For example, the application case of `inferTm` is:

```lean
| .node `Term.app #[fn, arg] => do
    let (fnTm, fnTy) ← inferTm ctx fn
    let .pi _ dom ⟨env, codTm⟩ := fnTy
      | raiseError (.expectedFunctionType ctx.names (← fnTy.quote))
    let argTm ← checkTm ctx dom arg
    let argVal ← argTm.eval ctx.env
    let codVal ← codTm.eval (env.cons argVal)
    return (.app fnTm argTm, codVal)
```

The function is inferred, yielding a type `fnTy`. Because evaluation eagerly unfolds constants into glued values, and `inferTm` always returns a `VTy` produced by `Ty.eval`, `fnTy` is already in weak head normal form --- no explicit `whnf` call is needed to expose the Pi structure. The argument is then checked against the domain, and the codomain is substituted via evaluation in the closure's extended environment, rather than by explicit syntactic substitution.

When checking or inference fails --- due to a `sorry`, an unbound variable, or a type mismatch --- the elaborator emits a diagnostic and inserts a fresh axiom as a placeholder at the expected type. This keeps the rest of the file type-checkable, so the language server can continue reporting errors throughout the file rather than stopping at the first mistake.

==== Comparison with unification-based elaboration

Pure type inference (synthesising types for every subterm) is incomplete for dependent type theories: without additional structure, variables like `fun x => x` have no principal type. Systems with implicit arguments and metavariables fill this gap via unification, solving for the missing types during elaboration. This is powerful but introduces substantial complexity --- pattern unification, occurs checks, postponed constraints, meta freezing --- none of which appear in this implementation.

Bidirectional type checking @dunfield2021bidirectional sidesteps this by requiring the user to annotate just enough types that checking is deterministic. In practice the annotation burden is small: top-level definitions have types (because they are either explicit or inferred from a body), lambdas under a Pi inherit their domain, and let-bindings propagate their inferred type to the body. The cases that require annotations --- such as the binder type of a top-level lambda with no outer context --- are exactly the cases where the user would need to provide the information anyway.

The approach taken here is syntax-directed with no metavariables and no backtracking. The trade-off is that the surface language is more verbose than Lean's or Agda's, but the elaborator is significantly simpler, which was a deliberate choice given the scope of this project.

== Normalisation by evaluation <sec:nbe>

=== Semantic domain

The semantic domain separates _values_ from _syntax_. Values (`VTm`, `VTy`) represent terms in weak head normal form, using de Bruijn _levels_ rather than indices:

```lean
inductive VTm : Nat → Type
  | u'      : Universe → VTm n
  | neutral : Neutral n → VTm n
  | lam     : Name → VTy n → ClosTm n → VTm n
  | pi'     : Name → VTm n → ClosTm n → VTm n
  | glued   : Neutral n → Tm 0 → VTm n
```

A `neutral` is a head (variable or constant) applied to a spine of eliminators. A `lam` carries a closure --- an environment `Env n m` paired with a body term `Tm (m + 1)` having one free variable. Beta-reduction evaluates the body in the environment extended with the argument. A `glued` value carries both a neutral (the folded form, for quotation) and the unevaluated definition body (for reduction).

The choice of de Bruijn levels for values and indices for syntax is deliberate. Under levels, a variable's name is absolute rather than relative, so weakening (embedding a value into a larger scope) is a runtime no-op: the level remains the same when additional variables are pushed onto the environment. Under indices, every weakening requires traversing the value to shift every variable. Since NbE weakens values frequently --- closures are opened at fresh levels during quotation and conversion --- this would be a significant cost. The scope index `n` in `VTm n` enforces well-scoping at the type level; weakening then becomes a proof obligation that `omega` discharges automatically, and the underlying data is reused via `unsafeCast`.

==== Choice of closure representation

Closures in NbE can be represented in two ways:

- *Higher-order abstract syntax (HOAS)*: a lambda carries a host-language function `VTm → VTm`. Beta-reduction is a function call; the host compiler's closure optimisations apply.
- *Defunctionalised closures*: a lambda carries the body as syntax paired with its captured environment. Beta-reduction re-interprets the body by evaluating it in the extended environment.

HOAS is significantly faster in practice: smalltt @kovacs2023smalltt reports a 2--3$times$ speedup over defunctionalised closures on identical benchmarks, because GHC compiles the host function to efficient native code. However, HOAS is strictly positive only in languages that permit non-positive inductive types. Lean's kernel rejects `VTm → VTm` in the `lam` constructor, as it violates positivity and opens the door to non-termination via Curry's paradox.

We could bypass the check with `unsafe inductive`, as the normalisation benchmarks in Lean themselves do. This was considered, but rejected: marking `VTm` unsafe would prohibit proving any properties of the evaluator, which in turn would prohibit proving the correctness of conversion checking and elaboration. The defunctionalised representation keeps the evaluator within the kernel's logic.

=== Evaluation

Evaluation (`Tm.eval`) interprets syntax in an environment of values. The environment is indexed by the scope size, matching the scope index of the syntax being evaluated:

```lean
partial def Tm.eval {n c} : Tm c → SemM n c (VTm n)
  | .u' i         => return .u' i
  | .var i        => return (← read).get i
  | .const name us => do
      let some tm ← fetchDefinition name
        | return .neutral ⟨.const name us, .nil⟩
      let some info ← fetchConstantInfo name
        | return .neutral ⟨.const name us, .nil⟩
      return .glued ⟨.const name us, .nil⟩
        (tm.substLevels (info.univParams.zip us))
  | .lam x a body => return .lam x (← a.eval) ⟨← read, body⟩
  | .app fn arg   => do (← fn.eval).app (← arg.eval)
  | .pi' x a b    => return .pi' x (← a.eval) ⟨← read, b⟩
  | .proj i t     => do (← t.eval).proj i
  | .letE _ _ t b => do b.eval (.cons (← t.eval) (← read))
```

The cases are:

- *Variables* are looked up in the environment by de Bruijn index.
- *Constants* evaluate to _glued_ values when a definition is available: the result carries both the folded neutral form and the unevaluated definition body (with universe parameters substituted). If the constant has no definition (e.g. an axiom or an opaque declaration), a plain neutral is returned.
- *Lambdas* create closures capturing the current environment and the unevaluated body. No reduction happens under the binder.
- *Applications* evaluate both sides, then dispatch on the function's head in `VTm.app`: beta-reduction if it is a lambda, extending the spine if it is neutral or glued.
- *Let-bindings* evaluate the bound term and extend the environment, then evaluate the body.

Weak head normalisation (`VTm.whnf`) unfolds further on demand: for a constant-headed neutral, it delta-reduces (fetches and evaluates the definition) and re-applies the accumulated spine. For a glued value, it forces the unfolded body. It also performs iota-reduction when a fully-applied recursor has a constructor as its major premise.

=== Quotation

Quotation (`VTm.quote`) converts values back to syntax. For closures, it applies the closure to a fresh variable at the current de Bruijn level and quotes the result, converting levels to indices during the traversal. For `VTm.glued` nodes, quotation uses the folded form (the neutral), producing compact output that preserves top-level definition names rather than inlining their bodies.

== Conversion checking <sec:conv>

Conversion checking decides definitional equality of two values. The naive algorithm is: reduce both sides to normal form, then compare structurally. This is correct but slow, because it forces all reducible subterms regardless of whether comparison actually needs them.

The approximate algorithm used here, inspired by Kovacs's smalltt @kovacs2023smalltt, bounds the amount of speculative work by a three-state mode parameter:

```lean
inductive ConvState where
  | rigid
  | flex
  | full
```

The three modes are:

- *Rigid*: the default mode, used at the top level and under canonical formers (lambdas, Pi types, constructors). When two neutral or glued values have the same defined head, spines are compared speculatively in flex mode. If the flex comparison succeeds, no unfolding was needed --- the two terms are structurally equal at the folded level. If it fails, both sides are unfolded to their definitions and compared in full mode.
- *Flex*: entered only from rigid's speculative spine check. No definitions are unfolded; no fallback is attempted. If heads agree, the spines are compared elementwise, still in flex mode. Any mismatch causes immediate failure, returning control to the rigid caller, which then commits to unfolding.
- *Full*: entered from rigid after a flex failure. All definitions are unfolded immediately on encounter. Once in full mode, all recursive calls remain in full.

This ensures at most one backtrack per subterm: rigid attempts a cheap flex check, and on failure commits to the expensive full check. Because flex never unfolds, the cost of a failed speculation is bounded by the size of the matching prefix of the two spines.

To see the benefit, consider comparing `f (g (h x))` with `f (g (h x))` where `f`, `g`, `h` are top-level definitions. The naive algorithm unfolds `f`, `g`, `h` on both sides and compares the unfolded bodies --- potentially an exponentially large computation if the definitions are deeply nested. The approximate algorithm observes that the two terms have the same folded structure: same head `f`, same spine. The flex comparison descends into the argument, observes the same head `g`, and so on, bottoming out at `x` with no unfolding at all. The check runs in time proportional to the syntactic size of the folded term, not the unfolded term.

For eta-conversion, two cases are handled: function eta, where $f equiv lambda x. f thin x$ is decided by opening both sides at a fresh variable and comparing the bodies; and structure eta, where $c(r_1, dots, r_k) equiv s$ (with $c$ a constructor of a single-constructor inductive) is decided by comparing each projection $s.i$ with the corresponding field $r_i$.

==== Comparison with naive reduction

A naive conversion checker would reduce both sides to normal form and compare. This has two problems. First, normal forms can be exponentially larger than the original terms: consider a definition `def big := ...` that unfolds to a deeply nested expression; comparing `big` with itself would first materialise the huge normal form, then walk it structurally, even though the syntactic equality `big = big` is immediately decidable. Second, the comparison walks the entire normal form even when a mismatch is present near the surface, wasting work.

The rigid/flex/full algorithm addresses both problems. Flex mode exploits the observation that most conversion checks succeed on identical or structurally similar terms: a flex comparison succeeds without any unfolding, running in time proportional to the syntactic size. When flex fails, the algorithm commits to full unfolding, but only for the specific subterm where speculation failed --- not for the whole expression. The bounded backtracking ensures that the asymptotic cost is at most the minimum of the two strategies: the flex cost if speculation succeeds, or the flex cost plus the full cost if it fails.

An alternative design, used in some systems, is _on-the-fly_ reduction: weakly head normalise each side just enough to decide equality at each level, and recurse under binders. This avoids eagerly computing full normal forms, but without the rigid/flex distinction it still unfolds aggressively whenever the heads do not syntactically match. The speculative flex check avoids this unfolding in the common case where heads are the same defined constant.

== Inductive types <sec:inductive>

Inductive declarations are the means by which the user extends the theory with new data types. A declaration

```
inductive I.{u} (P : Type u) : Nat → Type u where
  | c₁ : ... → I P n₁
  | c₂ : ... → I P n₂
```

introduces the _type former_ `I`, a family of _constructors_ `c_i`, and a _recursor_ `I.rec`. Each constructor is a term that builds values of `I` at specific indices; the recursor is the unique non-dependent eliminator that computes on each constructor.

The elaboration process proceeds in several phases:

+ *Elaborate the type.* Parameters and indices are elaborated in order. The result type must be a universe $sans("Type")_u$. Note that the distinction between parameters and indices is syntactic: parameters appear before the `:`, indices after.
+ *Register the inductive as opaque.* Before elaborating constructors, the inductive is added to the global environment as an opaque declaration with just its type. This lets constructors refer to the inductive itself during their own elaboration (via the constant name), without creating a circular dependency.
+ *Elaborate each constructor.* Each constructor's fields are elaborated in a context that binds a variable `I` representing the inductive (not the actual constant, which is not yet fully registered). The constructor's result type must be `I` applied to the inductive's parameters _verbatim_ --- the same de Bruijn indices as the parameter telescope --- followed by chosen indices. This constraint (`ctorParamMismatch` on mismatch) simplifies the recursor generation, which relies on parameters being invariant across constructors.
+ *Check strict positivity.* In each field's type, the inductive may appear only in _strictly positive_ positions. Non-positive occurrences are rejected as `nonPositiveOccurrence` errors. The positivity analysis permits _nested_ recursion: a field may be a function type whose result mentions the inductive, provided the inductive does not appear in any argument type of that function.
+ *Check universe consistency.* Each field's universe level must be bounded by the inductive's result universe, rejecting `fieldUniverseTooLarge` otherwise. This ensures the inductive type lives in a universe large enough to contain all its fields.
+ *Generate the recursor type.* The recursor takes the parameters, a _motive_ $C : sans("indices") -> I thin sans("parameters") thin sans("indices") -> sans("Type")_v$, one _minor premise_ per constructor (which produces $C$ applied to the constructor), the indices, and finally the major premise of type `I`. The motive's universe $v$ becomes an additional universe parameter of the recursor (see below).
+ *Generate the recursor rules.* One rule per constructor: when `I.rec` is applied to `c_k args`, it reduces to the $k$-th minor premise applied to `args`. Recursive fields (where the inductive appears in the field's type) additionally contribute _induction hypotheses_ computed by recursive calls to `I.rec`.
+ *Replace the inductive entry.* Finally, the opaque placeholder registered in step 2 is replaced with the full inductive declaration, including the list of constructor names.

For example, the recursor for `Nat`:

$
  sans("Nat.rec").{u} : (C : sans("Nat") -> sans("Type")_u) -> C thin sans("zero") -> ((n : sans("Nat")) -> C thin n -> C thin (sans("succ") thin n)) -> (n : sans("Nat")) -> C thin n
$

with the iota-reduction rules:

$
  sans("Nat.rec") thin C thin z thin s thin sans("zero") &~> z \
  sans("Nat.rec") thin C thin z thin s thin (sans("succ") thin n) &~> s thin n thin (sans("Nat.rec") thin C thin z thin s thin n)
$

Structures (single-constructor inductives) additionally generate _projection_ functions `I.f_k`, one per field, that extract the $k$-th field from a constructor application. The conversion checker includes a structural eta-expansion rule for structures: `c (s.f_1) ... (s.f_k)` is identified with `s`.

==== Universe handling

Universe polymorphism makes recursor generation subtle: the motive's universe may differ from the inductive's universe. For example, elimination from `Nat` into `Type 0` gives ordinary recursion, while elimination into `Type (u+1)` gives large elimination.

The elaborator handles this by generating a fresh universe parameter `motiveUnivName`, distinct from all universe parameters of the inductive itself, and prepending it to the recursor's universe parameter list. So for a monomorphic inductive like `Nat` (`univParams = []`), the recursor has `recUnivParams = [motiveUnivName]`. For `List.{u}` (`univParams = [u]`), the recursor has `recUnivParams = [motiveUnivName, u]`. At each use site, `Nat.rec.{v}` instantiates the motive's universe to `v`.

The freshness is ensured by `Universe.freshName`, which picks a name not in the inductive's universe parameter list. The convention is that the motive's universe is the _first_ universe parameter of the recursor.

==== Recursors rather than pattern matching

Modern proof assistants like Lean, Agda, and Coq compile user-facing pattern matching to recursor applications internally. Pattern matching is more convenient for users, but significantly more complex to implement: case trees, catch-all patterns, dependent case analysis, and coverage checking all add machinery.

The core theory here uses recursors directly, as Coq did originally. This keeps the core simple and the trusted code base small: the elaborator need only check that constructors are well-typed and generate the recursor; no pattern-matching compiler is needed. The cost is ergonomics --- stdlib definitions are written with explicit recursor calls rather than `match` --- but the core theory is small enough that adding a pattern-matching frontend would be straightforward future work.

== Incremental elaboration <sec:incremental>

Elaboration is decomposed into queries managed by a Shake-based build system. Each query is identified by a tag and parameters, and returns a value whose type is determined by the tag. The query types are defined as a pair of indexed inductive types. The actual `Key` type has 17 cases; the principal ones are:

```lean
inductive Key where
  | cst : FilePath → Key
  | ast : FilePath → Key
  | declarationIndex : FilePath → Key
  | elabCmdAt : FilePath → Nat → Key
  | elabDecl : FilePath → Name → Key
  | constant : FilePath → Name → Key
  | lookupInfo : FilePath → Name → Key
  -- ... others omitted

def Val : Key → Type
  | .cst _              => Cst × Array ParseError
  | .ast _              => Ast
  | .declarationIndex _ => HashMap Name Nat × Array Diagnostic
  | .elabCmdAt _ _      => Global × ElabInfo
  | .elabDecl _ _       => Option (Constant × Origin) × ElabInfo
  | .constant _ _       => Option (Constant × Origin)
  | .lookupInfo _ _     => ElabInfo
  -- ... others omitted
```

The dependent typing of `Val` is essential: a single query map cannot be used to store results of different types without either existential packing or a universal result type. Using a type-level function, each query's result type is precisely determined by its key.

The principal queries are:

- `declarationIndex`: given a file path, returns a map from declaration names to their indices within the file. This query depends only on the parsed AST, so it is recomputed only when the file is edited.
- `elabDecl`: elaborates a single declaration. It fetches the AST, looks up the declaration by name, and type-checks it. It depends on `constant` queries for every constant it references.
- `constant`: looks up the elaborated form of a named constant. This is the primary cross-declaration dependency.

When the elaborator encounters a reference to a constant, it calls `fetchConstant`, which issues a `Key.constant` query through the build system. This registers a dependency: if the referenced constant changes, the current query is invalidated and recomputed on the next build.

Within a single elaboration run, an `entryCache` in `ElabState` memoises constant lookups to avoid repeated queries to the build system for the same name.

==== Granularity of queries

The choice of query granularity trades off overhead against incremental precision. Too coarse --- e.g. one query per file --- and any edit invalidates the whole file. Too fine --- e.g. one query per expression --- and the per-query overhead dominates, making the system slower than batch elaboration for typical edits.

The granularity here is per-declaration. A `Key.elabDecl` query elaborates one top-level `def`, `inductive`, or `structure`. When a declaration is edited, only that declaration's query is invalidated; dependent declarations are recomputed only if the edit changes the declaration's cached `Constant` (its elaborated type and body). This matches the granularity at which a user typically edits: they change one definition at a time, and expect the feedback loop to scale with the cost of that definition, not the whole file.

Finer granularity --- for example, caching the elaborated form of individual subterms --- would require treating each subterm as a named entity, which it is not in the source language. Implementing this would require either heuristic naming (hashing the subterm's syntax) or restructuring the core theory to make subterms addressable. Neither is compelling for the cost.

==== Dependently-typed query results

An alternative to the dependent type function `Val : Key → Type` is to use a single result type that subsumes all query results, e.g. a sum type `inductive Result | parsed : ... | elaborated : ... | ...` or an existential `Σ α, α`. Both have drawbacks:

- A sum type forces every query to return a tagged value and every consumer to pattern-match and handle an "impossible" case when the tag does not match. This is boilerplate that the dependent typing eliminates.
- An existential type erases the result type entirely, forcing `unsafeCast` or a proof-carrying wrapper at every fetch site. Neither integrates cleanly with the elaborator's other structures.

The dependent `Val` makes `fetch (Key.constant p n) : Task (Option Constant)` type-check without any tagging, and the compiler can specialise each call site to the specific result type. This is a natural use of Lean's dependent types that has no direct counterpart in Haskell's Rock or Salsa implementations, where singleton types or type families are needed to approximate the same pattern.

== Language server <sec:lsp>

The elaborator doubles as a language server. During elaboration, hover information and diagnostics are collected in `ElabState` and returned alongside the elaboration result. A VSCode extension communicates with the elaborator via the Language Server Protocol, providing:

- *Diagnostics*: type errors, unbound variables, and universe mismatches, positioned at the relevant source location via path indices into the AST.
- *Hover information*: the type of the term under the cursor, or the full signature of a referenced constant.

