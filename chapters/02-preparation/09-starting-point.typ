#import "common.typ": *

== Starting point <sec:starting-point>

Prior to starting, I had implemented type checkers, but had not built a dependently typed elaborator or a build system. Although I had experience using Lean 4 as a proof assistant, but had not used it as a general-purpose language for a project of this scale, nor used its metaprogramming features.

No implementation code was written before the project began, and no existing codebase was used as a basis. The proposal planned a Rust implementation on top of Salsa; no code from that stack was incorporated. smalltt @kovacs2023smalltt was consulted as a reference for the design of _glued conversion checking_ (@sec:conv). Our language server borrows code from Lean 4's.
