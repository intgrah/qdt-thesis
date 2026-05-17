#import "@preview/zero:0.6.1": num, set-num

#let metrics = json("metrics.json")

#let project(
  title: "My Dissertation",
  author: "<Insert name>",
  candidate_number: none,
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
  set page(
    numbering: (n, ..) => if n > 1 { numbering("i", n) },
    number-align: center,
  )
  set text(font: "Libertinus Serif", lang: "en")
  show cite: set text(fill: rgb("#1a5e7a"))
  show link: set text(fill: rgb("#1a5e7a"))
  show ref: set text(fill: rgb("#1a5e7a"))
  show math.equation: set text(font: "Libertinus Math", weight: 400)
  show math.equation.where(block: true): set block(above: 1.2em, below: 1.2em)
  set raw(theme: "theme.tmTheme", syntaxes: ("lean4.sublime-syntax",))
  show raw: set text(font: "FiraCode Nerd Font", size: 9pt)
  show raw.where(block: true): set block(fill: luma(248), inset: 8pt, radius: 3pt, width: 100%)
  set table(stroke: none)
  show table: set table(stroke: (x, y) => if y == 0 { (bottom: 0.5pt) })
  set heading(numbering: "1.1")
  set-num(group: (separator: ",", threshold: 4))

  let slate = rgb("#525a63")
  let sec-number = it => context {
    if it.numbering != none {
      text(fill: slate, counter(heading).display(it.numbering))
      h(0.5em)
    }
  }

  show heading: it => {
    if it.level == 1 {
      pagebreak()
      v(4.5em)
      block(below: 2em, {
        if it.numbering == "1.1" {
          text(size: 60pt, weight: 400, fill: slate, context {
            str(query(heading.where(level: 1, numbering: "1.1").before(here())).len())
          })
          h(1em)
          text(size: 25pt, weight: 400, smallcaps(it.body))
        } else if it.numbering == "A.1" {
          text(size: 60pt, weight: 400, fill: slate, context {
            numbering("A", counter(heading).get().first())
          })
          h(1em)
          text(size: 25pt, weight: 400, smallcaps(it.body))
        } else {
          text(size: 25pt, weight: 400, smallcaps(it.body))
        }
      })
    } else if it.level == 2 {
      block(above: 2em, below: 1.2em, text(size: 18pt, weight: 500, sec-number(it) + smallcaps(it.body)))
    } else if it.level == 3 {
      block(above: 1.6em, below: 1em, text(size: 14pt, weight: 500, sec-number(it) + smallcaps(it.body)))
    } else {
      block(above: 1.3em, below: 0.9em, text(size: 12pt, weight: 500, sec-number(it) + smallcaps(it.body)))
    }
  }

  show outline.entry: it => {
    let el = it.element
    let is_chapter = el.func() == heading and el.level == 1 and el.numbering == "1.1"
    let is_appendix = el.func() == heading and el.level == 1 and el.numbering == "A.1"
    let is_unnum_h1 = el.func() == heading and el.level == 1 and el.numbering == none
    let is_bib = el.func() == std.bibliography
    if is_chapter or is_appendix or is_unnum_h1 or is_bib {
      let prefix = if is_chapter {
        str(counter(heading).at(el.location()).first())
      } else if is_appendix {
        numbering("A", counter(heading).at(el.location()).first())
      } else {
        none
      }
      block(above: 1em, below: 0.5em, link(el.location(), {
        if prefix != none { box(width: 1.5em, prefix) }
        smallcaps(el.body)
        h(1fr)
        str(counter(page).at(el.location()).first())
      }))
    } else {
      it
    }
  }

  show figure.caption: it => {
    smallcaps([#it.supplement #context it.counter.display(it.numbering):])
    [ ]
    it.body
  }
  show figure: set block(above: 1.4em, below: 1.4em)

  set page(header: context {
    let numbered = query(
      heading
        .where(level: 1)
        .and(
          heading.where(numbering: "1.1").or(heading.where(numbering: "A.1")),
        ),
    )
    let prior = numbered.filter(h => h.location().page() < here().page())
    let here_on_page = numbered.filter(h => h.location().page() == here().page())
    if prior.len() > 0 and here_on_page.len() == 0 {
      let head = prior.last()
      set text(size: 9pt, style: "italic")
      if head.numbering == "1.1" {
        str(counter(heading).at(head.location()).first())
      } else {
        numbering("A", counter(heading).at(head.location()).first())
      }
      h(1em)
      head.body
    }
  })

  place(top + right, dx: 4em, dy: -4em, text(size: 10pt, candidate_number))

  set align(center)
  if logo != none {
    align(left, image(logo, width: 30%))
  }

  v(0.5fr)
  text(1.1em, date)
  v(1.2em, weak: true)
  text(2.8em, smallcaps(title))

  if not anonymous {
    pad(top: 0.7em, strong(author))
    college
  }

  v(1fr)
  par()[
    #emph[Submitted in partial fulfilment of the requirements for the\
      #course]
  ]
  set align(left)

  heading(
    outlined: false,
    numbering: none,
    depth: 1,
  )[
    Declaration of originality
  ]

  par()[
    I, the candidate for Part II of the Computer Science Tripos with Blind Grading Number #candidate_number, hereby declare that this report and the work described in it are my own work, unaided except as may be specified below, and that the report does not contain material that has already been used to any substantial extent for a comparable purpose. In preparation of this report, I adhered to the Department of Computer Science and Technology AI Policy. I am content for my report to be made available to the students and staff of the University.
  ]
  v(1em)
  par[Date: #emph(date)]

  proforma

  if acknowledgements != [] {
    heading(
      outlined: false,
      numbering: none,
    )
    [Acknowledgements]
    acknowledgements
  }

  set outline.entry(fill: box(width: 1fr, repeat[#h(0.2em).#h(0.2em)]))
  outline(depth: 3, target: heading)

  set par(justify: true, first-line-indent: (amount: 1.2em, all: false), spacing: 0.8em, leading: 0.8em)
  set list(indent: 1.2em, body-indent: 0.6em, spacing: 1em)
  set enum(indent: 1.2em, body-indent: 0.6em, spacing: 1em)
  set terms(indent: 1.2em, spacing: 1em)
  set page(numbering: "1")
  counter(page).update(1)

  body
}
