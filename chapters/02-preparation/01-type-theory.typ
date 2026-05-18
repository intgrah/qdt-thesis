#import "common.typ": *

== Our dependent type theory <sec:type-theory>

The elaborator's internal language is a version of dependent type theory in the tradition of @martinlof1984.
The distinguishing form is the _dependent function type_ $Pi_(x:A) B$, whose introduction and elimination rules are:

#align(center, grid(
  columns: 2,
  column-gutter: 2em,
  prooftree(rule(
    name: smallcaps[$Pi$-intro],
    $Gamma tack lambda x. b : Pi_(x:A) B$,
    $Gamma, x : A tack b : B$,
  )),
  prooftree(rule(
    name: smallcaps[$Pi$-elim],
    $Gamma tack f thin a : B[a slash x]$,
    $Gamma tack f : Pi_(x:A) B$,
    $Gamma tack a : A$,
  )),
))

The elimination rule $B[a slash x]$ is what distinguishes a dependent type theory from a simple one, as the resulting type is allowed to _depend_ on the argument, $a : A$.

=== Grammar <sec:fragment>

The calculus uses universes _à la Tarski_ @martinlof1984#footnote[The popular _Russell_-style alternative collapses terms and types into one. The Tarski formulation has cleaner categorical semantics, discussion of which is out-of-scope.], which separates the grammar into _mutually_ defined terms and types:

#let nosyntax = [_(no syntax)_]
#align(center, table(
  columns: (auto, auto, auto, auto),
  align: (right + horizon, left + horizon, left + horizon, right + horizon),
  stroke: none,
  column-gutter: (0.4em, 2em, 2em),
  inset: (y: 4pt),
  table.header(
    table.cell(colspan: 2, align: center)[Grammar],
    [Surface syntax #footnote[We borrow the surface syntax of Lean 4.]],
    align(right)[Description],
  ),
  table.hline(stroke: 0.4pt),
  $ell ::=$,
  $cal(u) | 0 | sans("succ")(ell) | max(ell, ell)$,
  lean("0, u + 1, max u v"),
  [universe levels],

  $A, B ::=$, $sans("Type")_ell$, lean("Type u"), [universe],
  $|$, $Pi_(x : A) B$, lean("(x : A) → B"), [dependent function type],
  $|$, $sans("El")(t)$, nosyntax, [decoding a type code],
  $t, s ::=$, $x_i$, lean("x"), [variable],
  $|$, $c.{overline(ell)}$, lean("c.{u, v}"), [constant],
  $|$, $lambda x : A. t$, lean("fun x : A => t"), [function abstraction],
  $|$, $t thin s$, lean("t s"), [application],
  $|$, $t_i$, nosyntax, [field projection],
  $|$, $sans("let") thin x : A := t thin sans("in") thin s$, lean("let x : A := t; s"), [let-binding],
  $|$, $sans("Type'")_ell$, nosyntax, [universe code],
  $|$, $Pi'_(x : t) s$, nosyntax, [function type code],
))

Variables $x_i$ are _de Bruijn indices_ @debruijn1972lambda, where $i$ refers to the $i$-th enclosing binder counted from the use site.#footnote[However, we still retain binder names at the _binding_ site, for the purposes of pretty-printing.] Global constants $c.{overline(ell)}$ carry a list of universe arguments, and $t.k$ projects the $k$-th field. The primed term formers $sans("Type'")_ell$ and $Pi'_(x : t) s$ are term-level _codes_ for the corresponding type formers; the type-level constructor $sans("El")(t)$ decodes a code into a type. Inductive declarations introduce a new type former, its constructors, and a recursor.

=== Universes

Types are stratified into a hierarchy

$ sans("Type")_0 thin : thin sans("Type")_1 thin : thin sans("Type")_2 thin : thin dots $

with $sans("Type")_u : sans("Type")_(u+1)$ for each $u$. The hierarchy is _non-cumulative_: each $sans("Type")_u$ inhabits exactly one universe, $sans("Type")_(u+1)$.

A definition can be parameterised by universe levels:

```lean
def id.{u} (α : Type u) (x : α) : α := x
```

Levels are a separate sort of variable from term-level binders and must be instantiated explicitly at each use site, e.g. `id.{1}`. There is no universe-level inference: the programmer writes every level argument.#footnote[Inference is also possible, which would require a constraint solver over this particular join-semilattice.]

=== Inductive types

An inductive type @dybjer1994inductive is introduced by its constructors. Consider the following declaration of natural numbers:

```lean
inductive Nat : Type where
  | zero : Nat
  | succ (n : Nat) : Nat
```

This generates the constants `Nat : Type`, `Nat.zero : Nat`, and `Nat.succ : Nat → Nat`. In addition, a recursor, which encodes the _dependent elimination principle_#footnote[Eliminators are sufficient to define all structurally recursive functions on the type. We avoid implementing _pattern matching_ for its complexity.], is generated:

```lean
axiom Nat.rec.{u} :
  (motive : Nat → Type u) →
  (motive Nat.zero) →
  ((n : Nat) → motive n → motive (Nat.succ n)) →
  (n : Nat) → motive n
```

This eliminator is _dependent_: the result type may vary with the scrutinee, so the recursor takes a _motive_ --- a function from the inductive type to a type --- that picks out the result type at each value. It then takes one _branch_ per constructor. The branch's parameters are the constructor's own arguments together with one _inductive hypothesis_ per recursive argument, the motive evaluated at that sub-term.

```lean
def Nat.add (m n : Nat) : Nat :=
  Nat.rec
    (fun n => Nat)            -- Regardless of n, our result type is Nat
    m                         -- n = Nat.zero; return m
    (fun n ih => Nat.succ ih) -- n = Nat.succ k; assume ih = Nat.add m k
    n
```

This encodes the two defining equations:

```lean
Nat.add m Nat.zero     = m
Nat.add m (Nat.succ n) = Nat.succ (Nat.add m n)
```

=== Reduction and conversion

To equate terms that compute to the same value, three notions are distinguished. _Reduction_ is a directed rewrite $t ~> s$, generated by five rules each named by a Greek letter. _Definitional equality_ ($t equiv s$) is the smallest congruence containing reduction in either direction. The _conversion rule_

#align(center, prooftree(rule(
  name: smallcaps[Conv],
  $Gamma tack t : B$,
  $Gamma tack t : A$,
  $A equiv B$,
)))

lets a term cross a definitional equality without an explicit coercion; this is what distinguishes dependent type checking from simple type checking. _Conversion checking_ is the algorithm that decides definitional equality, which we specify in @sec:nbe-theory.

The five rules are:

- $beta$: $(lambda x. b) thin a ~> b[a slash x]$, substitution.
- $delta$: $c ~> t$, assuming the global environment binds the constant $c$ to body $t$, definition unfolding.
- $zeta$: $sans("let") thin x := a thin sans("in") thin b ~> b[a slash x]$, let inlining.
- $eta$:
  + at function types, $f equiv lambda x. f thin x$
  + at single-constructor inductives (structures), $s equiv c(s.1, dots, s.k)$.
- $iota$: a recursor applied to a constructor reduces to the corresponding branch. For $sans("Nat")$,
  + $sans("Nat.rec") thin C thin z thin s thin sans("zero") ~> z$
  + $sans("Nat.rec") thin C thin z thin s thin (sans("succ") thin n) ~> s thin n thin (sans("Nat.rec") thin C thin z thin s thin n)$.

As a worked example, the elaborator checks `Eq.refl.{0} Nat 6 : Nat.add 2 4 = 6` by reducing the left-hand side. $delta$ unfolds `Nat.add` to the recursor. Then $iota$ fires as the recursion's principal argument is unwound from `4` through `succ`s down to `0`, and the term reduces to `succ (succ (succ (succ 2)))`, which is `6`.

Of the five rules, only $delta$ crosses declaration boundaries: applying it looks up another constant in the global environment. The other four operate on a term's own structure. A conversion check that fires $delta$ on `foo` depends on `foo`'s body; one that does not is independent of any change to `foo`. The build system tracks these dynamic cross-declaration dependencies (@sec:build-framework).
