#import "common.typ": *

== Verifying the cache <sec:verifying-the-cache>

Precise per-declaration tracking extends the trusted layer to include the tracker. To keep correctness in reach, we ask the framework to support a machine-checked theorem relating cached and batch elaboration. This section identifies what the framework must provide for such a theorem to go through.

=== Obligations <sec:requires>

A task is polymorphic in the effect monad $f$: it cannot inspect $f$ or branch on its identity. Any inhabitant of `Task` should therefore behave the same way at any two choices of $f$, given pointwise-related inputs and fetches. That property is what relates a cached implementation (in a stateful monad) to a reference implementation that recomputes pure values. Making the relation a Lean theorem rather than an external appeal imposes four obligations on the framework:

1. *Dependent result types.* Different queries produce different value types: the `ast` query returns an `Ast`, `constant` returns a `Constant`, and `type` returns a `ConstantInfo`. The framework's key-value map must be heterogeneous.
2. *Well-foundedness.* `compute` is the reference batch semantics: elaborating declaration $N$ recurses into each constant that $N$'s conversion check $delta$-unfolds. For this recursion to define a total function in Lean, the dependency relation on queries must be well-founded; qdt supplies the witness as a rank function `Key.rank : Key → Nat` together with inverse-image well-foundedness on $bb(N)$.
3. *Structural parametricity.* The bridge between memoised and pure semantics relates two runs of the same task: one in a stateful monad (the cached executor) and one with no effects (the reference). Lean's logic does not derive such a relation for free, so each task must carry, as a field of its definition, a proof that any two effect choices agree on related handlers.
4. *Effect orthogonality.* Tracing (a `TraceT` layer recording a forest of dependency nodes) and cancellation (an `ExceptT Cancelled` layer) must be addable without revisiting the agreement proof, so the framework's correctness statement must be polymorphic in two effect layers wrapping the proof-relevant payload.

=== Where qdt's framework sits <sec:framework-sits>

qdt's build framework starts from BSALC's Task (@sec:task) and adds the four ingredients above. Dependent result types and structural parametricity become part of the framework's representation; well-foundedness lives in a separate reference semantics; effect orthogonality is achieved by stacking effect layers around a proof-relevant payload. Cross-build persistence follows the verifying-trace design of Shake @mitchell2012shake.
