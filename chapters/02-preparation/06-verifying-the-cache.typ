#import "common.typ": *

== Verifying the cache <sec:verifying-the-cache>

Precise per-declaration tracking extends the trusted layer to include the tracker. To keep correctness in reach, we ask the framework to support a machine-checked theorem relating cached and batch elaboration. This section identifies what the framework must provide for such a theorem to go through.

=== Obligations <sec:requires>

A task is polymorphic in the effect monad $f$: it cannot inspect $f$ or branch on its identity. By parametricity, a task instantiated at any $f$ behaves the same way as at any other $f$, given pointwise-related inputs and fetches. The _free theorem_ of the task type @wadler1989theorems is the formal statement of this property, and it is what relates the batch specification (the task at `Id`) to cached implementations.

For the free theorem to be applicable, the framework must satisfy four obligations:

1. *Dependent result types.* Different queries produce different value types (a parsed AST, a sourcemap, an elaborated constant). The framework's key-value map must be heterogeneous.
2. *Well-foundedness.* `compute` is the reference batch semantics; its recursion must terminate, so the dependency relation on queries must be well-founded.
3. *Structural parametricity.* The free theorem is required to bridge memoised and pure semantics. Lean's logic does not admit parametricity as an internal theorem; each task must carry the proof of its own parametricity as a field of its definition.
4. *Effect orthogonality.* Tracing, cancellation, and IO must be addable without revisiting the agreement proof, so the framework's correctness statement must be polymorphic in two effect layers wrapping the proof-relevant payload.

=== Where qdt's framework sits <sec:framework-sits>

qdt's build framework starts from BSALC's Task (@sec:task) and adds the four ingredients above. Dependent result types and structural parametricity become part of the framework's representation; well-foundedness lives in a separate reference semantics; effect orthogonality is achieved by stacking effect layers around a proof-relevant payload. Cross-build persistence follows the verifying-trace design of Shake @mitchell2012shake.
