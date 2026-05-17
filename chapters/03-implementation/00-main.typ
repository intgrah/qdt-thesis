= Implementation <ch:implementation>

Chapter 2 identified four obligations a build framework must support to admit a machine-checked agreement theorem. This chapter constructs a framework that satisfies them, instantiates it with three caching strategies, and builds the elaborator on top. @sec:design-goal lists the design choices. @sec:build-framework defines the polymorphic Task abstraction and proves the agreement theorem from it. @sec:build-inhabitants exhibits Busy, LessBusy, and Shake; Shake's agreement proof is the central result. @sec:elaborator builds the elaborator on the verified framework. @sec:lsp wraps it for editor use. @sec:repository overviews the source.

#include "01-design-goal.typ"
#include "02-build-framework.typ"
#include "03-build-inhabitants.typ"
#include "04-elaborator.typ"
#include "05-lsp.typ"
#include "07-repository.typ"
