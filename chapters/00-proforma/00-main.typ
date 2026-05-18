#import "@preview/wordometer:0.1.5": total-words, word-count-of
#import "../../template.typ": metrics, num

#let limited(limit: 100, body) = {
  let n = word-count-of(body).words
  assert(n <= limit, message: str(n) + " > " + str(limit))
  body
}

#heading(outlined: false, numbering: none, "Proforma")

#table(
  columns: 2,
  stroke: none,
  [Candidate Number], [7268C],
  [Title], [Query-based Dependent Type Elaborator],
  [Examination], [Computer Science Tripos Part II, 2026],
  [Word Count], [#total-words#footnote[Via the `wordometer` Typst package.]],
  [Code Line Count], [#num(metrics.total)#footnote[Via `cloc`, computed by a handwritten script.]],
  [Project Originator], [The candidate],
  [Project Supervisor], [Dr Jon Sterling],
  [Ethics Approval], [Not required],
)

#heading(outlined: false, numbering: none, level: 2)[#smallcaps[Original aims]]

#limited[
  Dependently typed languages such as Lean, Agda, and Rocq let types depend on terms, so type checking must execute _arbitrary programs_ to compare them. A change to a function's body can therefore affect downstream type checks even when its type is unchanged. Existing type checkers re-elaborate the suffix of the file from the changed name, plus every file that imports it, even when no use actually depends on the change.

  This project set out to implement an elaborator for a dependently typed language, and to investigate whether per-declaration queries could re-elaborate only the definitions actually affected by each edit.
]

#heading(outlined: false, numbering: none, level: 2)[#smallcaps[Work completed]]

#limited[
  All success criteria were met and substantially exceeded. The elaborator type-checks an expressive dependent type theory, capable of elaborating code from the Lean 2 HoTT library. Incremental re-elaboration takes time proportional to the edit, independent of project size. Beyond the proposal, a machine-checked correctness proof for the build system underlying the elaborator was established in Lean 4 against a reference batch semantics, extending without modification to effectful variants.
]

#heading(outlined: false, numbering: none, level: 2)[#smallcaps[Special difficulties]]

#limited[
  None.
]
