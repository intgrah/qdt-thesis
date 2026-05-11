= Implementation <ch:implementation>

This chapter describes the implementation of the elaborator. We follow the pipeline from source text to elaborated output: parsing, bidirectional type checking, normalisation by evaluation, conversion checking, inductive type elaboration, and the incremental build architecture that ties them together.

The implementation is in Lean 4. Lean's C FFI is used for the performance-critical build system implementations. Its macro system embeds qdt programs directly in Lean source files as inline test cases. Lean's dependent types make terms intrinsically scoped (`VTm n`) and allow query result types to depend on the query key (`Val : Key -> Type`).

#include "01-architecture.typ"
#include "02-parsing.typ"
#include "03-calculus.typ"
#include "04-bidirectional.typ"
#include "05-nbe.typ"
#include "06-conversion.typ"
#include "07-inductive.typ"
#include "08-incremental.typ"
#include "09-lsp.typ"
#include "10-verification.typ"
