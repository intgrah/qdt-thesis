#import "common.typ": *

== Incremental computation

In a conventional compiler, the type signature is the compilation boundary: changing a function body without changing its type cannot affect downstream type checking. Existing query-based systems for conventional languages — Salsa @salsa2018 in rust-analyzer, the analogous machinery in Roslyn — rely on this. Downstream queries are keyed by the unchanging signature and are invalidated only when the signature itself moves.

A dependently typed elaborator does not enjoy this boundary. The conversion rule (@sec:calculus) admits a term of type $A$ where type $B$ is expected whenever $A equiv B$, and deciding $A equiv B$ may require $delta$-reducing constants — unfolding their bodies — in the course of checking a different definition. A body edit can therefore invalidate downstream type checks even when no signature has moved. Worse, whether a given conversion check unfolds a given body is not known statically: it depends on the specific terms compared, which in turn depend on the types of other definitions. Dependencies are discovered during elaboration, not before it.

Incremental dependent type elaboration therefore needs a build system that supports _dynamic dependencies_ — recorded as the task runs — and _early cutoff_, so that a body edit whose effect on conversion checking is null does not cascade. Type checking a single definition may trigger many conversion checks, each of which may unfold arbitrarily large terms; after an edit, most need not be repeated, and the build system must determine which.

=== Build systems à la carte

Mokhov, Mitchell, and Peyton Jones @mokhov2018build observe that build systems bring outputs up to date with respect to changed inputs. They capture Make, Shake, Bazel, and others as instances of a single polymorphic type.

The central abstraction is the _task_: a recipe that requests the values of other keys through a callback, with the build system deciding how those requests are fulfilled. A task is polymorphic in an effect --- it works with any monad the build system chooses. The constraint on the monad determines what the task can do: `Applicative` means all fetches are declared upfront (static dependencies); `Monad` lets the task inspect a result and decide what to fetch next (dynamic dependencies).

The paper decomposes build systems along two axes: the _scheduler_ determines execution order, while the _rebuilder_ determines whether a key needs recomputation:

#table(
  columns: 4,
  [], [Topological], [Restarting], [Suspending],
  [Dirty bit], [Make], [Excel], [-],
  [Verifying traces], [Ninja], [-], [Shake],
  [Constructive traces], [CloudBuild], [Bazel], [-],
  [Deep constr. traces], [Buck], [-], [Nix],
)

Dependent type elaboration needs dynamic dependencies (the elaborator discovers which definitions it must unfold only as it runs) and early cutoff (skipping dependents when a recomputed result is unchanged). This places us at the Shake cell.

The polymorphism of the task type separates the elaborator from the build strategy: tasks are written once and executed by whichever build system is chosen. The formalisation of this framework in Lean 4 is presented in @sec:verification.
