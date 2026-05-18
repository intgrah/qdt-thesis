= Introduction

Interactive proof assistants are live programming environments for mathematics. The user edits a definition, and the elaborator type-checks and reports diagnostics. In a library at the scale of mathlib, a single edit forces re-elaboration of every file that imports the changed one, and the cost is paid on every save. /* TODO Every save only? What about upon every character entered, such as in an LSP? */ Reducing that cost without trusting an unverified cache is the question this thesis addresses.

#include "01-motivation.typ"
#include "03-aims.typ"
