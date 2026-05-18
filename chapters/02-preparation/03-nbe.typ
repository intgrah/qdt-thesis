#import "common.typ": *

== Normalisation by evaluation <sec:nbe-theory>

Conversion calls from @sec:bidirectional-theory must reduce terms to compare them. A naive implementation would substitute syntactically on every $beta$-step, duplicating work whenever a substituted variable later reappears, and shifting de Bruijn indices across each binder. _Normalisation by evaluation_ (NbE) @abel2013normalization avoids both costs: it interprets terms into a _semantic_ domain of _values_ in which application is a meta-language operation, and substitution is replaced by environment lookup. Two functions complete the round trip:

$
   sans("eval") & : sans("Term") times sans("Env") -> sans("Value") \
  sans("quote") & : sans("Value") -> sans("Term")
$

Evaluation reduces a term to _weak head normal form_ (WHNF) under an environment $rho$ binding each free variable to a value. _Head_ means the outermost form is decided (canonical or stuck), and _weak_ means evaluation does not enter the bodies of $lambda$-binders, which stay packaged as closures, evaluated only when an argument arrives.

WHNF suffices for conversion: at matching canonical heads, the algorithm recurses into the subterms (forcing closures as needed); at neutrals, it compares head and spine. Quotation walks a value back to a term, descending into closures by applying them to a fresh variable.

A value is either _canonical_ (a function $sans("lam")$, a type code $sans("pi'")$ or $sans("u'")$, or an inductive constructor applied to its arguments) or $sans("neutral")$: a stuck head $h$ (a free variable, or a constant whose body has not been unfolded) paired with a _spine_ $sigma$, a list of arguments and projections accumulated since the last reduction of the head. The canonical value of a lambda carries a _closure_ $chevron.l rho, t chevron.r$: the body $t$ paired with the environment $rho$ of its captured variables, not yet evaluated.

Three rules give the character of evaluation:

$
                sans("eval")(x_i, rho) & = rho(i) \
  sans("eval")(lambda (x : A). t, rho) & = sans("lam")(x, sans("eval")(A, rho), chevron.l rho, t chevron.r) \
           sans("eval")(t thin u, rho) & = sans("app")(sans("eval")(t, rho), sans("eval")(u, rho))
$

with the auxiliary $sans("app")$:

$
  sans("app")(sans("lam")(x, A, chevron.l rho, t chevron.r), v) & = sans("eval")(t, rho dot.c v) \
                      sans("app")(sans("neutral")(h, sigma), v) & = sans("neutral")(h, sigma dot.c v)
$

The closure case fires $beta$ inside the meta-language; the neutral case extends the spine without reducing. Quotation at a neutral reverses the spine back to a syntactic application; at a closure, it applies to a fresh variable and recurses under the binder.

A defined constant evaluates to a _glued_ value, which carries the folded neutral (the constant applied to its universe arguments, empty spine) together with the constant's identifying information $(c, overline(ell))$ used to fetch and evaluate the body via $delta$-reduction when needed:

$ sans("eval")(c.{overline(ell)}, rho) = sans("glued")(sans("neutral")(c.{overline(ell)}, epsilon), c, overline(ell)) $

Conversion compares two glued values' folded heads and spines first; when those agree, the bodies are not fetched. When they disagree, $sans("whnf")$ forces $delta$-reduction and conversion repeats on the unfolded values. We use glued evaluation for two reasons: the cheap-comparison-first discipline is due to Kovács's smalltt @kovacs2023smalltt @kovacs2024unfolding and is the practical performance argument; and each $delta$-reduction in $sans("whnf")$ is the elaborator's act of depending on $c$'s body, which the build framework records as a cross-declaration dependency edge (@sec:build-framework).

To see evaluation on a small term, consider $(lambda x. f thin x) thin a$ at the empty environment, with $f$ a constant whose body is unavailable:

$
  sans("eval")((lambda x. f thin x) thin a, epsilon)
  &= sans("app")(sans("lam")(x, "_", chevron.l epsilon, f thin x chevron.r), sans("eval")(a, epsilon)) \
  &= sans("eval")(f thin x, epsilon dot.c a) \
  &= sans("app")(sans("neutral")(f, epsilon), a) \
  &= sans("neutral")(f, epsilon dot.c a)
$

Quotation reads this back as $f thin a$. @sec:conv describes our implementation.
