#import "template.typ": *

#show: project.with(
  title: "Query-based Dependent Type Elaborator",
  author: "Jeremy Chen",
  anonymous: true,
  abstract: [
    Dependently typed languages require expensive type checking, yet most elaborators operate in batch mode, re-checking entire files after each edit. This project implements an incremental, query-based elaborator for a dependently typed language supporting dependent function types, universe polymorphism, and inductive types with recursors. The elaborator is built on a formalisation of the "Build Systems à la Carte" framework in Lean 4, using a Shake-based incremental build system to memoise elaboration queries across edits. We evaluate the system on a standard library and conversion checking benchmarks, comparing incremental re-elaboration against batch re-elaboration.
  ],
  acknowledgements: [
    TODO
  ],
  proforma: include "chapters/00-proforma.typ",
  date: "May 2026",
  college: "Trinity College",
  logo: "cst_logo.svg",
)

#include "chapters/01-introduction/00-main.typ"
#include "chapters/02-preparation/00-main.typ"
#include "chapters/03-implementation/00-main.typ"
#include "chapters/04-evaluation.typ"
#include "chapters/05-conclusion.typ"

#bibliography("refs.bib")

#heading(outlined: true, numbering: none)[Appendices]

#set heading(numbering: "A.1", outlined: false)
#counter(heading).update(0)
#show heading.where(level: 1): set heading(outlined: true)

#include "chapters/06-proposal.typ"
