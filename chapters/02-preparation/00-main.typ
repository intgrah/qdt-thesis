= Preparation <ch:preparation>

This chapter identifies what a per-declaration framework needs from its substrate to admit a machine-checked proof that its cache agrees with batch elaboration.

@sec:type-theory fixes the type-theoretic fragment and the conversion rule that decides cross-declaration dependencies. @sec:bidirectional-theory and @sec:nbe-theory introduce the bidirectional discipline and the normalisation-by-evaluation algorithm the elaborator uses to decide it. @sec:build-systems gives the vocabulary of polymorphic-task build systems. @sec:existing-approaches reviews what production proof assistants and adjacent settings do today. @sec:verifying-the-cache identifies what a build framework must provide for a machine-checked agreement theorem. @sec:requirements and @sec:engineering state the project requirements and engineering practices; @sec:starting-point records the starting point.

#include "01-type-theory.typ"
#include "02-bidirectional.typ"
#include "03-nbe.typ"
#include "04-build-systems.typ"
#include "05-existing-approaches.typ"
#include "06-verifying-the-cache.typ"
#include "07-requirements.typ"
#include "08-engineering.typ"
#include "09-starting-point.typ"
