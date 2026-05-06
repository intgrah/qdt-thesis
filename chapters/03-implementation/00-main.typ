= Implementation <ch:implementation>

This chapter describes the implementation of the elaborator. We follow the pipeline from source text to elaborated output: parsing, bidirectional type checking, normalisation by evaluation, conversion checking, inductive type elaboration, and the incremental build architecture that ties them together.

The implementation is written in Lean 4. Lean is designed as a general-purpose programming language with a native C backend and C FFI, which we use for the performance-critical build system implementations. Its macro system lets us embed qdt programs directly in Lean source files: since qdt's syntax is a subset of Lean's, inline test cases are Lean macros that produce qdt source strings. Lean's dependent types make terms intrinsically scoped (the `n` in `VTm n`) and allow query result types to depend on the query key (`Val : Key -> Type`). The build system's correctness proofs live in the same language as the implementation --- the `Build` type carries its proof, and the elaborator's tasks are the same object the proofs reason about.

#include "01-architecture.typ"
#include "02-parsing.typ"
#include "03-bidirectional.typ"
#include "04-nbe.typ"
#include "05-conversion.typ"
#include "06-inductive.typ"
#include "07-incremental.typ"
#include "08-lsp.typ"
