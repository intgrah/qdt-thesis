#import "common.typ": *

== Elaboration

The typing rules above are declarative: they specify _what_ is well-typed, not _how_ to check it. Elaboration is the algorithmic counterpart. We outline the key ideas; implementation details are deferred to @ch:implementation.

=== Bidirectional type checking

_Bidirectional type checking_ @dunfield2021bidirectional splits the typing judgement into two modes: _checking_, where the expected type is known and pushed into the term, and _inference_, where the type is synthesised bottom-up. The algorithm is syntax-directed --- each term form has one applicable rule per mode --- and eliminates backtracking. A subsumption rule bridges the two modes via conversion checking.

I omit metavariables and unification; their complexity is orthogonal to incrementality.

=== Normalisation by evaluation

The conversion rule requires deciding definitional equality, which requires reducing terms. _Normalisation by evaluation_ (NbE) @abel2013normalization evaluates syntax into a semantic domain of values, where equality is checked by structural comparison rather than repeated rewriting. The two operations are _evaluation_ (syntax to values) and _quotation_ (values back to syntax). NbE performs substitution in bulk through environments rather than one variable at a time, and stops at weak head normal form --- reducing only as far as needed.

=== Glued evaluation

Unfolding every defined constant to its normal form is wasteful: most conversion checks succeed or fail long before full normalisation. _Glued evaluation_ @kovacs2023smalltt pairs each defined constant with a folded form (the constant itself) and an unfolded form (its definition body, available lazily). Conversion checking first compares folded forms; only when heads differ does it force the unfolded forms. For incrementality, this reduces the number of definition bodies the elaborator depends on.

=== Conversion checking

With NbE and glued evaluation, conversion checking compares two values by structural descent. Following @kovacs2023smalltt, the checker operates in three modes --- _rigid_, _flex_, and _full_ --- controlling how eagerly definitions are unfolded. When two neutrals share a defined head, rigid mode speculatively compares their spines in flex mode, which performs no unfolding at all; if the speculative check fails, rigid falls back to delta-reducing both sides and comparing in full mode, which unfolds eagerly. Each mode that avoids unfolding a definition body avoids creating a dependency on it in the build system --- approximate conversion checking directly narrows the dependency graph.
