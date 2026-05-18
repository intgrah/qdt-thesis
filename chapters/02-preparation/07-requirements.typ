#import "common.typ": *

== Requirements analysis <sec:requirements>

The elaborator and its build substrate must deliver five things. The proposal asked for two: correctness and incremental responsiveness. The other three follow from wanting the framework's agreement with batch elaboration to be a machine-checked theorem rather than an external appeal (@sec:requires).

=== Desiderata

/ Correctness <rq:correctness>:
  The elaborated form of every declaration is the same whether the elaborator runs from cold or from a cached build. (@sec:correctness-eval)

/ Incremental responsiveness <rq:responsiveness>:
  Re-elaboration time scales with the affected fragment, not with the size of the corpus. (@sec:incremental-eval.)

/ Verifiability <rq:verify>:
  The build substrate admits a machine-checked agreement theorem relating cached and batch elaboration. (@sec:mechanised-inhabitants.)

/ Executor polymorphism <rq:polymorphism>:
  Modern incremental frameworks allow execution strategies to be swapped at deployment time; the elaborator is therefore presented as a single value, independent of the cache strategy that executes it. Switching strategies requires no source change and no rerun of the agreement proof. (@sec:build-inhabitants.)

/ Effect orthogonality <rq:effects>:
  Modern tooling expects effect layers around the verified core; the framework therefore admits them without revisiting the agreement proof. (@sec:effect-layers.)
