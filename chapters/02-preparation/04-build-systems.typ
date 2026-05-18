#import "common.typ": *

== Build systems <sec:build-systems>

We adopt the framework of _Build systems à la carte_ (BSALC) @mokhov2018build, which abstracts the build recipe as a polymorphic Task type. This section introduces the vocabulary; @sec:existing-approaches covers existing instances; @sec:build-framework presents the refinement we make in this thesis.

=== The Task abstraction <sec:task>

An elaborator fits the build-system shape: source files are inputs, and declarations are queries whose recipes are tasks. A build system computes the value of each _key_ from the values of other keys, bottoming out at input keys whose values are read from the outside world. The recipe for non-input keys is a _task_:

$ Task thin c thin k thin v = forall f. quad c thin f => (k -> f thin v) -> f thin v. $

A task is parametric in a callback monad $f$. It receives a callback $sans("fetch") : k -> f thin v$ that resolves any dependency in $f$, and returns a value in $f$. The constraint $c$ ranges over `Applicative`, `Selective`, `Monad`, and others; each corresponds to a discipline of dependency tracking. With `Applicative`, the set of fetched keys is fixed up front. With `Monad`, fetches may be conditional on the values returned by earlier fetches: this is the discipline elaboration needs, because conversion checking discovers cross-declaration dependencies only as it unfolds constants and compares terms.

Polymorphism in $f$ separates _what_ a build computes from _how_ a particular runtime schedules and caches it. The same Task can be executed pure (in `Id`, recomputing everything), or in a stateful monad that memoises, or under additional effect layers that trace or cancel.

=== Towards a verified build framework <sec:requires>

The published Task, embedded into Lean 4 for a machine-checked agreement theorem against a batch reference, is missing four things:

- *Dependent result types.* Different queries return different value types: querying the `ast` of a file expects an `Ast` type, and querying the `type` of a constant expects a `Ty`. Whilst the original meaning of a _build system_ is usually not concerned with more than associating filenames and their contents, it is not sufficient for our use case.
- *Well-foundedness.* The batch reference recurses through whatever dependencies a task fetches. For this recursion to define a total function in Lean, the framework must carry a well-founded relation on queries.
- *Structural parametricity.* BSALC's Task is polymorphic in $f$ so that different build systems may instantiate it with different effect monads. Wadler's metatheorem @wadler1989theorems says any polymorphic term's two instantiations agree on related handlers. Whilst Haskellians appeal to this informally, treating it as a property of the type, Lean's logic does not derive such metatheorems internally.
- *Effect orthogonality.* Tracing and cancellation, added as outer effect layers, must compose with the agreement proof without re-running it. The correctness statement must be polymorphic in those layers.

We refine BSALC's polymorphic Task into a verified build framework that supplies all four. @sec:build-framework presents the framework; @sec:build-inhabitants exhibits three cached executors that inhabit it.
