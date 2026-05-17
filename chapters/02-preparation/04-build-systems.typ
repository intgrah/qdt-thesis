#import "common.typ": *

== Build systems <sec:build-systems>

We adopt the framework of _Build systems à la carte_ (BSALC) @mokhov2018build. This section introduces the vocabulary; @sec:existing-approaches covers existing instances and @sec:verifying-the-cache derives the obligations a verified instance must satisfy.

=== The Task abstraction <sec:task>

A build system computes the value of each _key_ from the values of other keys, bottoming out at input keys whose values are read from the outside world. The recipe for non-input keys is a _task_:

$ Task thin c thin k thin v = forall f. quad c thin f => (k -> f thin v) -> f thin v. $

A task receives a callback $sans("fetch") : k -> f thin v$ that resolves dependencies in some monad $f$, and returns a value in the same monad. The constraint $c$ ranges over `Applicative`, `Selective`, `Monad`, and others; each class corresponds to a discipline of dependency tracking (static, conditional, dynamic). Polymorphism in $f$ separates _what_ a build computes from _how_ the build system schedules and caches it.

For elaboration we fix $c := sans("Monad")$. Conversion checking discovers cross-declaration dependencies as it unfolds constants and compares terms; what a task fetches depends on the values returned by earlier fetches, and cannot be enumerated up front.

=== Scheduler and rebuilder

A build system is classified along two axes: the _scheduler_ chooses task execution order, and the _rebuilder_ decides when a key needs recomputation. Make's scheduler is topological and its rebuilder is timestamp-based. Shake's scheduler is suspending (a task is paused when it fetches an unbuilt key) and its rebuilder uses verifying traces.
