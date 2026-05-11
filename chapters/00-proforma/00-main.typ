#heading(outlined: true, numbering: none, "Proforma")

#table(
  columns: 2,
  stroke: none,
  [*Candidate Number*], [TODO],
  [*Title*], [Query-based Dependent Type Elaborator],
  [*Examination*], [Computer Science Tripos --- Part II, 2026],
  [*Word Count*],
  [8,532#footnote[Computed via `pdftotext` on the main body (Introduction through Conclusion), including code blocks, tables, and captions.]],

  [*Code Line Count*], [15,774#footnote[Computed with `cloc`.]],
  [*Project Originator*], [The candidate],
  [*Project Supervisor*], [Dr Jon Sterling],
)

== Original aims of the project

Dependently typed languages --- such as Lean, Agda, and Rocq --- require type checkers that execute arbitrary programs at compile time. Most existing implementations operate in batch mode, re-checking entire files after each edit. This project set out to investigate whether a query-based, incremental approach could reduce the latency of elaboration in an interactive setting, by applying the "Build Systems à la Carte" framework to dependent type elaboration.

== Work completed

TODO: fill in once evaluation is complete.

== Special difficulties

None.
