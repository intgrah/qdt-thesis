#import "common.typ": *

== Bidirectional type-checking <sec:bidirectional-theory>

The reduction rules of @sec:type-theory equip the elaborator to compare two types. Finding the type of a term in the first place is a separate problem. In a dependent type theory the unifier would have to invent terms (since terms appear in types), and the resulting problem, _higher-order unification_, is undecidable @goldfarb1981undecidability. @pierce2000local set out a different discipline: the programmer supplies enough annotations that the checker never has to invent a type. @coquand1996algorithm adapted this to dependent types.

Bidirectional checking splits the typing relation into two judgements with opposite directions of information flow:

#align(center, table(
  columns: (auto, auto),
  align: (right + horizon, left + horizon),
  stroke: none,
  column-gutter: 2em,
  $Gamma tack.r e arrow.l.double A$, [_check_ if the term $e$ has type $A$],
  $Gamma tack.r e arrow.r.double A$, [_synthesise_ the unique $A$ that types the term $e$],
))

Every syntactic form has exactly one applicable mode. Introduction forms ($lambda$, structure constructor) are _checkable_: the type of $lambda x. b$ is fixed by the surrounding context, since the binder's domain has to come from outside. Elimination forms (variables, applications, projections) are _synthesisable_: the head determines the type. @dunfield2019bidirectional survey the modes and rules in detail.

A checking judgement falls back to synthesis when no checking rule matches. The elaborator synthesises the term's type $B$, and the conversion checker decides whether $A equiv B$. This is _subsumption_, the single point at which conversion is invoked from checking:

#align(center, prooftree(rule(
  name: smallcaps[Sub],
  $Gamma tack.r e arrow.l.double A$,
  $Gamma tack.r e arrow.r.double B$,
  $Gamma tack.r A equiv B$,
)))

To see the modes in motion, consider checking

$ f : "Nat" -> "Bool", a : "Nat" tack f thin a arrow.l.double "Bool". $

Application is not a checking form, so subsumption fires. Synthesis on $f thin a$ synthesises the head

$ f : "Nat" -> "Bool", a : "Nat" tack f arrow.r.double "Nat" -> "Bool", $

then checks the argument

$ f : "Nat" -> "Bool", a : "Nat" tack a arrow.l.double "Nat", $

which descends into another synthesis and subsumption. The application as a whole synthesises

$ f : "Nat" -> "Bool", a : "Nat" tack f thin a arrow.r.double "Bool", $

and conversion checks $"Bool" equiv "Bool"$ trivially.

For dependent function application $f thin a$ with $f arrow.r.double Pi_(x : A) B$, the result type is $B[a slash x]$. The substitution forces the conversion checker, which compares types modulo $(beta, delta, zeta, eta, iota)$, to evaluate terms inside types. The next section gives the algorithm that does so.
