#import "template.typ": *
#import "@preview/wordometer:0.1.5": total-words, word-count

#show: project.with(
  title: "Query-based\nDependent Type Elaborator",
  author: "Jeremy Chen",
  candidate_number: "7268C",
  anonymous: true,
  proforma: include "chapters/00-proforma/00-main.typ",
  date: "May 2026",
  college: "Trinity College",
)

#show: word-count.with(exclude: (
  "bibliography",
  "cite",
  "display",
  "equation",
  "h",
  "hide",
  "image",
  "line",
  "linebreak",
  "locate",
  "metadata",
  "pagebreak",
  "parbreak",
  "path",
  "polygon",
  "ref",
  "repeat",
  "smartquote",
  "space",
  "style",
  "update",
  "v",
  "figure",
  "caption",
  "raw",
  <appendix>,
))

#include "chapters/01-introduction/00-main.typ"
#include "chapters/02-preparation/00-main.typ"
#include "chapters/03-implementation/00-main.typ"
#include "chapters/04-evaluation/00-main.typ"
#include "chapters/05-conclusion/00-main.typ"

#bibliography("refs.bib", style: "citation-style.csl")

#[
  #set heading(numbering: "A.1")
  #counter(heading).update(0)

  #include "chapters/06-appendix/proofs.typ"
  #include "chapters/06-appendix/proofs-rdeps.typ"
  #include "chapters/06-appendix/proposal.typ"
]<appendix>
