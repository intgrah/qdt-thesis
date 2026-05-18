= Preparation <ch:preparation>

Given that our core aims are to produce a novel, incremental elaborator, it is appropriate for us to first study the state-of-the-art algorithms in this area.
Hence, we first explain the type theory used by our language in @sec:type-theory, and also introduce the _conversion rule_.
In @sec:bidirectional-theory and @sec:nbe-theory, we introduce the _bidirectional type-checking_ discipline and analyse the algorithm of _normalisation by evaluation_.

In @sec:build-systems, we present the vocabulary of _build systems_.
@sec:existing-approaches reviews the norms of proof assistants and incrementalisation in adjacent settings.
Finally, we analyse the project's requirements in @sec:requirements and outline the software engineering practices in @sec:engineering.
// Deliberately omit: starting point from roadmap.

#include "01-type-theory.typ"
#include "02-bidirectional.typ"
#include "03-nbe.typ"
#include "04-build-systems.typ"
#include "05-existing-approaches.typ"
#include "07-requirements.typ"
#include "08-engineering.typ"
#include "09-starting-point.typ"
