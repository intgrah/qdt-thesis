#let project(
  title: "My Dissertation",
  author: "<Insert name>",
  abstract: [],
  acknowledgements: [],
  proforma: [],
  date: none,
  logo: none,
  college: "<Insert college>",
  course: "Computer Science Tripos, Part II",
  anonymous: false,
  body,
) = {
  set document(author: if anonymous { "" } else { author }, title: title)
  set page(numbering: "1", number-align: center)
  set text(font: "New Computer Modern", lang: "en")
  show math.equation: set text(weight: 400)
  set raw(theme: "theme.tmTheme")
  show raw: set text(font: "FiraCode Nerd Font", size: 9pt)
  show raw.where(block: true): set block(fill: luma(248), inset: 8pt, radius: 3pt, width: 100%)
  set table(stroke: none)
  show table: set table(stroke: (x, y) => if y == 0 { (bottom: 0.5pt) })
  set heading(numbering: "1.1")

  show heading: it => {
    if it.level == 1 {
      pagebreak()
      v(4.5em)
      set text(size: 25pt)
      if it.numbering == "1.1" {
        "Chapter "
        context {
          str(query(heading.where(level: 1, numbering: "1.1").before(here())).len())
        }
        v(0.5em)
        it.body
      } else if it.numbering == "A.1" {
        "Appendix "
        context {
          str(numbering("A", counter(heading).get().first()))
        }
        v(0.5em)
        it.body
      } else {
        it
      }
      v(2em)
    } else if it.level < 4 {
      v(1em)
      it
      v(0.5em)
    } else {
      it
    }
  }

  set align(center)
  if logo != none {
    align(left, image(logo, width: 30%))
  }

  v(0.5fr)
  text(1.1em, date)
  v(1.2em, weak: true)
  text(2em, weight: 700, title)

  if not anonymous {
    pad(
      top: 0.7em,
      strong(author),
    )

    college
  }

  v(1fr)
  par()[
    Submitted in partial fulfilment of the requirements for the\
    #course
  ]
  set align(left)

  heading(
    outlined: false,
    numbering: none,
    "Declaration",
  )

  par()[
    I, #if anonymous { [_Author_ of _College_] } else [#author of #college], being a candidate for the #course, hereby declare
    that this dissertation and the work described in it are my own work, unaided
    except as may be specified below, and that the dissertation does not contain
    material that has already been used to any substantial extent for a comparable
    purpose.
  ]
  v(1em)
  par()[
    *Signed*: \
    *Date*: #date
  ]

  proforma

  heading(
    outlined: false,
    numbering: none,
    "Abstract",
  )
  abstract

  heading(
    outlined: false,
    numbering: none,
    "Acknowledgements",
  )
  acknowledgements

  outline(depth: 3, target: heading)

  set par(justify: true)

  body
}
