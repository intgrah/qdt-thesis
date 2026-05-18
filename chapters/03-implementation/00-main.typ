= Implementation <ch:implementation>

@sec:design-goal lays out the elaboration pipeline that the rest of the chapter populates. @sec:build-framework formalises the `Build` interface in Lean 4, with `Task`'s parametricity certificate as the device by which an executor's agreement with the reference `compute` semantics is proved inside the language. @sec:build-inhabitants exhibits four verified cached executors --- `Busy`, `LessBusy`, `Shake`, and `ShakeStandardRdeps` --- and two effect-layer extensions derived from `Shake` without revisiting the proof, alongside three unverified native implementations.

@sec:elaborator presents the elaborator as a single `Tasks` value: parsing to a green tree, query-based decomposition, bidirectional checking, normalisation by evaluation, conversion's three-mode algorithm, inductive declarations, and the per-declaration incremental wiring. @sec:lsp wraps the executor for editor interaction. @sec:repository indexes the source.

#include "01-design-goal.typ"
#include "02-build-framework.typ"
#include "03-build-inhabitants.typ"
#include "04-elaborator.typ"
#include "05-lsp.typ"
#include "07-repository.typ"
