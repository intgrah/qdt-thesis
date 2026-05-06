= Implementation <ch:implementation>

This chapter describes the implementation of the elaborator. We follow the pipeline from source text to elaborated output: parsing, bidirectional type checking, normalisation by evaluation, conversion checking, inductive type elaboration, and the incremental build architecture that ties them together.

The implementation is written in Lean 4. Throughout this chapter, code snippets are excerpts from the implementation. // TODO: cite the specific line count.

#include "01-architecture.typ"
#include "02-parsing.typ"
#include "03-bidirectional.typ"
#include "04-nbe.typ"
#include "05-conversion.typ"
#include "06-inductive.typ"
#include "07-incremental.typ"
#include "08-lsp.typ"
