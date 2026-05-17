== The elaborator <sec:elaborator>

The elaborator is a single `Tasks` value (@sec:build-framework) whose queries decompose the work from source text down to elaborated kernel constants. Independence from the executor is structural: the same `Tasks` runs under `Busy`, `LessBusy`, `Shake`, and the effect-layer variants. This section walks through each query in the chain, ending with the unfolding-recording mechanism that lets `Shake`'s fingerprints invalidate exactly the declarations whose elaboration depended on the edited symbol.

#include "04a-parsing.typ"
#include "04b-query-based.typ"
#include "04c-bidirectional.typ"
#include "04d-nbe.typ"
#include "04e-conversion.typ"
#include "04f-inductive.typ"
#include "04g-incremental.typ"
