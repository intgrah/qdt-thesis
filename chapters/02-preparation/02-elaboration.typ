#import "common.typ": *

== Elaboration

The typing rules in @sec:calculus specify _what_ is well-typed; they do not say _how_ to check well-typedness algorithmically. Elaboration is the algorithmic counterpart. We outline its three principal components: a bidirectional discipline that controls where the elaborator gets type information, normalisation by evaluation that decides definitional equality, and a conversion-checking strategy that avoids unfolding constants when it can.

=== Bidirectional type checking

The typing judgement $Gamma tack.r e : A$ is not directly executable as a check, because it does not say which of $e$ and $A$ are inputs and which are outputs. _Bidirectional type checking_ @coquand1996algorithm splits the judgement into two modes:

$
  Gamma tack.r e <= A & quad "checking:" thin A "is given, verify that" thin e : A \
  Gamma tack.r e => A & quad "inference:" thin e "is given, compute the type" thin A
$

Information flows downward in checking mode (the expected type is pushed into subterms) and upward in inference mode (the type is synthesised from subterms). Each term form has one applicable rule per mode, so the algorithm is syntax-directed and never backtracks. Lambdas are checked: the expected type $Pi (x : A). B$ supplies the parameter type $A$, and the body is checked against $B$ in the extended context. Applications $f thin a$ are inferred: $f$ is inferred to some Pi type $Pi (x : A). B$, $a$ is then checked against $A$, and the result has type $B[a slash x]$. Variables and constants are inferred by lookup in the local context or global environment. Type annotations $e : A$ switch direction: an inferred annotation expression checks its body against $A$ and returns $A$ as the inferred type. Where an inferred term meets a checking position, _subsumption_ bridges the two by demanding that the inferred and expected types are definitionally equal — the single point where conversion checking is invoked.

Bidirectional checking does not infer implicit arguments. Lean, Agda, and Rocq fill in unsynthesisable type information through metavariables solved by pattern unification; this introduces global elaboration state that crosses declaration boundaries and complicates incrementality. The programmer writes every type explicitly, eliminating metavariables and the unification machinery they require.

=== Normalisation by evaluation

The subsumption rule has to decide definitional equality, which means reducing terms. A naive implementation rewrites syntax repeatedly: scan the term for a redex, perform the substitution one variable at a time by traversing the body, repeat until normal. The cost is quadratic in term size, and substitutions copy subterms that may be discarded by a later reduction.

_Normalisation by evaluation_ @abel2013normalization avoids this by interpreting syntax into a _semantic domain_ of values. A value is either _canonical_ — a lambda, a Pi, or a universe — or _neutral_: a variable or constant head followed by a _spine_ of pending eliminators (applications and projections) that cannot fire because the head is blocked. _Evaluation_ traverses syntax once, producing a value: variables look up their value in the environment, lambdas capture the environment to form a _closure_, applications either fire $beta$ on a lambda or extend a neutral spine. _Quotation_ converts values back to syntax by applying each closure to a fresh variable and recursing. Substitution happens implicitly when a closure is applied to its argument; the body is never traversed for substitution alone.

Closures admit two representations. _Higher-order abstract syntax_ encodes a closure as a host-language function — applying the closure is a native call. _Defunctionalised_ closures pair the body's syntax with its captured environment. HOAS is faster but requires a non-strictly-positive inductive type; this thesis uses defunctionalised closures, which fit Lean's positivity check.

Bound variables in syntax use de Bruijn _indices_ counting inward from the binder; bound variables in values use de Bruijn _levels_ counting outward from the root of the context. Opening a closure adds a binding to the context: with indices, every reference to an outer variable would have to be shifted; with levels, no existing reference changes. Evaluation maintains levels in values for this reason, and quotation converts back to indices.

Evaluation does not produce a full normal form. It reduces only to _weak head normal form_: the outermost constructor is exposed (lambda, Pi, universe, or neutral with a fixed head) but subterms are left as closures. Conversion checking descends through structure and forces only the closures it needs to compare, so terms that differ deep inside but agree at the head are decided without ever evaluating their bodies.

=== Conversion checking

With NbE in place, conversion checking compares two values by structural descent. The cost is now governed by how aggressively it unfolds defined constants. Unfolding every constant to normal form is wasteful: most conversion checks succeed long before full normalisation, and unfolding creates dependencies on every definition body the check observes.

_Glued evaluation_ @kovacs2023smalltt addresses this by representing each defined constant as a pair: the _folded form_ — the constant itself $c.{overline(ell)}$ as an opaque head — and an _unfolded form_ — its definition body, available lazily. Conversion checking compares the folded forms first; only when the folded heads disagree does it force the unfolded forms.

The checker operates in three modes. _Rigid_ is the default. When two values have the same defined head, rigid speculatively compares their spines in _flex_ mode, which performs no unfolding. If flex succeeds, the check completes without observing either definition body. If flex fails, rigid falls back to _full_ mode, which unfolds eagerly on both sides. Each mode that avoids unfolding a definition avoids creating a dependency on its body, narrowing the incremental dependency graph.
