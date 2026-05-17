== Language server <sec:lsp>

The elaborator doubles as a language server, in the tradition of incremental attribute-grammar evaluation in syntax-directed editors @demers1981incremental and the asynchronous-document model of Isabelle/PIDE @wenzel2014pide. Hover information and diagnostics are collected in `ElabState` during elaboration and served to a VSCode extension via LSP:

- *Diagnostics*: type errors, unbound variables, universe mismatches, positioned via path indices into the AST.
- *Hover*: the type under the cursor, or the full signature of a referenced constant.
