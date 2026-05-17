#import "common.typ": *

== Bidirectional type-checking <sec:bidirectional-theory>

The reduction rules of @sec:type-theory equip the elaborator to compare two types. Finding the type of a term in the first place is a separate problem. In a Hindley-Milner system it is solved by first-order unification on type-level syntax; in a dependent type theory the unifier would have to invent terms (since terms appear in types), and the resulting higher-order unification is undecidable. @pierce2000local set out a different discipline: the programmer supplies enough annotations that the checker never has to invent a type. @coquand1996algorithm adapted this to dependent types.

Bidirectional checking splits the typing relation into two judgements with opposite information flow:

#align(center, table(
  columns: (auto, auto),
  align: (right + horizon, left + horizon),
  stroke: none,
  column-gutter: 2em,
  $Gamma tack.r e arrow.l.double A$, [_check_: $A$ is given, decide whether $e$ has it],
  $Gamma tack.r e arrow.r.double A$, [_synthesise_: $e$ is given, compute the unique $A$ at which it is typed],
))

Every syntactic form has exactly one applicable mode. Introduction forms ($lambda$, structure constructor) are _checkable_: the type of $lambda x. b$ is fixed by the surrounding context, since the binder's domain has to come from outside. Elimination forms (variables, applications, projections) are _synthesisable_: the head determines the type. @dunfield2019bidirectional survey the modes and rules in detail.

A checking judgement falls back to synthesis when no checking rule matches. The elaborator synthesises the term's type $B$, and the conversion checker decides whether $A equiv B$. This is _subsumption_, the single point at which conversion is invoked from checking:

#align(center, prooftree(rule(
  name: smallcaps[Sub],
  $Gamma tack.r e arrow.l.double A$,
  $Gamma tack.r e arrow.r.double B$,
  $Gamma tack.r A equiv B$,
)))

To see the modes in motion, consider checking $f thin a arrow.l.double "Bool"$, with $f : "Nat" -> "Bool"$ and $a : "Nat"$ in scope. Application is not a checking form, so subsumption fires. Synthesis on $f thin a$ goes: synthesise the head $f$, yielding $"Nat" -> "Bool"$; check the argument $a arrow.l.double "Nat"$, which descends into another synthesise-then-subsume. The application synthesises to $"Bool"$, and conversion checks $"Bool" equiv "Bool"$ trivially.

For dependent function application $f thin a$ with $f arrow.r.double Pi_(x : A) B$, the result type is $B[a slash x]$. The substitution forces the conversion checker, which compares types modulo $beta delta zeta eta iota$, to evaluate terms inside types. The next section gives the algorithm that does so.
