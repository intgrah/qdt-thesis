#import "template.typ": *

#show: project.with(
  title: "Query-based Dependent Type Elaborator",
  author: "Jeremy Chen",
  anonymous: true,
  abstract: [
    This project implements an incremental, query-based elaborator for a dependently typed language supporting dependent function types, universe polymorphism, and inductive types with recursors. Elaboration is decomposed into per-declaration queries executed by a Shake-based build system formalised in Lean 4. Three build systems are proved to produce the same results as batch evaluation. We evaluate the system on synthetic benchmarks and a standard library, comparing incremental re-elaboration against batch re-elaboration and against Lean 4.
  ],
  acknowledgements: [
    TODO
  ],
  proforma: include "chapters/00-proforma/00-main.typ",
  date: "May 2026",
  college: "Trinity College",
  logo: "images/cst_logo.svg",
)

#include "chapters/01-introduction/00-main.typ"
#include "chapters/02-preparation/00-main.typ"
#include "chapters/03-implementation/00-main.typ"
#include "chapters/04-evaluation/00-main.typ"
#include "chapters/05-conclusion/00-main.typ"

#bibliography("refs.bib")

#heading(outlined: true, numbering: none)[Appendices]

#set heading(numbering: "A.1", outlined: false)
#counter(heading).update(0)
#show heading.where(level: 1): set heading(outlined: true)

#include "chapters/06-appendix/proposal.typ"
