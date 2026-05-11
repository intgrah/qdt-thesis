#import "common.typ": *

== Incremental computation

Type checking a single definition may trigger many conversion checks, each of which may unfold and normalise arbitrarily large terms. After an edit, most of these checks need not be repeated. A query-based system tracks which definitions each check unfolded and skips the rest.

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
