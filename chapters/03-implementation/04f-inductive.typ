=== Inductive types <sec:inductive>

An inductive declaration (Dybjer @dybjer1994inductive) introduces a type former, its constructors, and a recursor whose type and $iota$-reduction rules are fixed by the constructor signatures (@sec:type-theory).

Elaboration proceeds in phases: elaborate the type and parameters; register the inductive as opaque so constructors can refer to it; elaborate each constructor; check strict positivity and universe consistency; generate the recursor type and its $iota$-reduction rules.

The motive's universe $u$ is a fresh universe parameter, distinct from the inductive's own universe parameters. This allows elimination into any universe: `Nat.rec.{0}` recurses into `Type 0`, while `Nat.rec.{1}` is large elimination into `Type 1`.

Structures (single-constructor inductives) additionally generate projection functions, and the conversion checker applies the structure $eta$ rule of @sec:type-theory to them.
