#import "common.typ": *

=== Query-based elaboration <sec:query-based>

In a query-based elaborator, each phase of work is exposed as a query: parsing the source file, indexing its declarations, elaborating one declaration, fetching the elaborated form of a constant. Queries depend on other queries, with the dependency graph built at runtime. An edit invalidates the input queries that read from the edited file; the framework propagates invalidation through the graph until early cutoff stops the cascade.

The boundaries between queries fix the granularity at which cutoff can fire. Each boundary is a point at which the framework may detect that a recomputed value matches its cached predecessor; choosing the boundaries is the principal design decision.

==== Granularity

The output of elaborating a declaration is a kernel constant: a name, a type, and a body. We therefore make `constant` a query: the elaborated form of a named declaration is the unit at which the system caches and at which downstream queries fire cutoff. Smaller queries inside the elaboration of a single declaration (parsing, AST extraction, declaration indexing) are exposed as separate queries that compose into `elabDecl`. Larger granularities (per-file or per-module) would lose the ability to cut off at the boundary of an individual declaration; smaller granularities (per-expression) would add per-query overhead with no proportional reduction in recomputation, since conversion checking is the only mechanism by which one declaration influences another (@sec:fragment).

==== The query chain

Our queries form a chain in which each query depends on a smaller prefix of work, terminating at file-content input queries:

$
  "text" arrow.r.long "ast" arrow.r.long "declarationIndex" arrow.r.long "declAst" arrow.r.long "elabDecl" arrow.r.long "constant".
$

The `text` query is an input: its value is the file's contents, set externally by the editor or by a CLI run. The `ast` query parses the text into a syntax tree. The `declarationIndex` query extracts the list of top-level names. The `declAst` query extracts the AST subtree for one declaration. The `elabDecl` query runs type checking on that subtree, fetching `constant` queries for any names it mentions. The `constant` query returns the elaborated form of a named declaration.

Cross-declaration dependencies enter the graph at `elabDecl`. When conversion checking unfolds a constant `foo` during the elaboration of `bar`, the framework registers an `elabDecl bar -> constant foo` edge. The edge is recorded when the fetch happens; the framework does not predict it from source. Consider a file with three declarations:

```lean
def double (n : Nat) : Nat := Nat.mul 2 n
def quad (n : Nat) : Nat := double (double n)
theorem double_2 : double 2 = 4 := Eq.refl _
```

The body of `quad` mentions `double`, so `elabDecl quad` fetches `constant double` while elaborating the application. The theorem `double_2` forces a conversion check between `double 2` and `4` while elaborating its proof; the check unfolds `double` and $iota$-reduces `Nat.mul`, registering a dependency from `elabDecl double_2` on `constant double` that records the body, not only the type.

Changing the body of `double` from `Nat.mul 2 n` to `Nat.add n n` leaves the type unchanged: `elabDecl quad`'s cache survives because it saw only the type, while `elabDecl double_2`'s cache is invalidated because it saw the body. Changing the type of `double` invalidates both. Adding a blank line at the top of the file changes `text` and recomputes `ast` and `declarationIndex`, but `declAst double`, `declAst quad`, and `declAst double_2` all produce the same subtrees, so the cascade stops there.

==== Dynamic dependencies

Whether an edge from `elabDecl bar` to `constant foo` appears in the graph depends on whether `bar`'s elaboration performs a conversion check that unfolds `foo`. This is not a property of the source code alone: the conversion checker has speculative modes (`flex` and `rigid`) that may avoid the unfolding entirely, and the choice between them depends on the specific terms being compared. A static analysis cannot predict which dependencies will fire. The build system must observe them as the task runs, which requires a monadic task type and a scheduler that can resolve a fetch in the middle of a running task.
