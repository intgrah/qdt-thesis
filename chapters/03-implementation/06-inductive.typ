== Inductive types <sec:inductive>

An inductive declaration @dybjer1994inductive introduces a type former, its constructors, and a recursor. The elaboration proceeds in phases: elaborate the type and parameters, register the inductive as opaque (so constructors can refer to it), elaborate each constructor, check strict positivity and universe consistency, then generate the recursor type and its iota-reduction rules.

For `Nat`, the generated recursor is:

$
  sans("Nat.rec").{u} : (C : sans("Nat") -> sans("Type")_u) -> C thin sans("zero") -> ((n : sans("Nat")) -> C thin n -> C thin (sans("succ") thin n)) -> (n : sans("Nat")) -> C thin n
$

with reduction rules:

$
  sans("Nat.rec") thin C thin z thin s thin sans("zero") &~> z \
  sans("Nat.rec") thin C thin z thin s thin (sans("succ") thin n) &~> s thin n thin (sans("Nat.rec") thin C thin z thin s thin n)
$

There is no primitive pattern matching --- all computation on inductives proceeds through the recursor. Structures (single-constructor inductives) additionally generate projection functions and an eta rule: `c (s.f_1) ... (s.f_k)` is identified with `s`.

The motive's universe $u$ is a fresh universe parameter, distinct from the inductive's own universe parameters. This allows elimination into any universe: `Nat.rec.{0}` gives recursion into `Type 0`, while `Nat.rec.{1}` gives large elimination into `Type 1`.
