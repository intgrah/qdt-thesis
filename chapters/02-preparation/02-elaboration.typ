#import "common.typ": *

== Elaboration

The typing rules above are declarative: they specify _what_ is well-typed, not _how_ to check it. Elaboration is the algorithmic counterpart.

=== Bidirectional type checking

_Bidirectional type checking_ (Dunfield and Krishnaswami @dunfield2021bidirectional) splits the typing judgement into two modes: _checking_, where the expected type is known and pushed into the term, and _inference_, where the type is synthesised bottom-up. The algorithm is syntax-directed and eliminates backtracking. A subsumption rule bridges the two modes via conversion checking.

I omit metavariables and unification, as their complexity is orthogonal to incrementality. The programmer must provide all type information explicitly.

=== Normalisation by evaluation

Type checking requires deciding definitional equality, which requires reducing terms. _Normalisation by evaluation_ (NbE; Abel @abel2013normalization) evaluates syntax into a semantic domain of values, where equality is checked by structural comparison rather than repeated rewriting. NbE performs substitution in bulk through environments rather than one variable at a time, and stops at weak head normal form. The implementation is described in @sec:nbe.

=== Conversion checking

_Glued evaluation_ (@kovacs2023smalltt) pairs each defined constant with a folded form (the constant itself) and an unfolded form (its definition body, available lazily), so that conversion checking can compare folded forms first and only unfold when heads differ. Combined with a three-mode approximate algorithm (rigid, flex, full), this avoids unnecessary reduction and, for incrementality, avoids creating unnecessary dependencies. The full algorithm is described in @sec:conv.
