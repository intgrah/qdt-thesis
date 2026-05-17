#import "common.typ": *

== Requirements analysis <sec:requirements>

// TODO

Here we lay out the desired properties of our elaborator.

/ Core language.: A dependently typed calculus with Pi types, a universe hierarchy, inductive types, and universe polymorphism.
/ Serial performance.: We use state-of-the-art techniques in the domain of dependent type checking, in order for our elaborator to have a competitive baseline, independent of incrementalisation.
/ Verifiability.: As a consequence of the domain we are working in, which is strongly tied to proof assistants, we want our incremental framework to be amenable to verification.
/ Interchangeability.: Interactive proof assistants routinely host both production implementations, and high-assurance alternatives. We follow this pattern in order to offer this flexibility.
/ Extensibility.: As modern programming languages are no longer black boxes that merely emit errors, instead offering features like Language servers, profiling, tracing. Therefore we would like our incremental framework to admit _effectful_ extensions.

We deviate from the proposal in two ways. The build framework was changed from Salsa to a polymorphic-Task framework in the style of @mokhov2018build, with concrete build implementations (Busy, LessBusy, Shake) written from scratch; the reasons are given in #ref(<sec:language-choice>, supplement: none). Pattern matching was dropped from the surface syntax; all case analysis is written through recursors directly.
