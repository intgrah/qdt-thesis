== Correctness <sec:correctness-eval>

The agreement theorem says: for any `Tasks` value and any inhabitant of `Build`, the inhabitant returns the same `Constant` as the reference `compute`. The theorem is unconditional in the executor's internal state and effect monads. It is silent on whether the elaborator's `Tasks` value implements the type theory of @sec:fragment. The tests in @sec:elab-tests, @sec:lsp-tests, and @sec:trace-agreement close that gap.

=== Mechanised inhabitants <sec:mechanised-inhabitants>

@fig:build-inhabitants lists the five mechanised inhabitants and the axioms each depends on. The four cached inhabitants (`LessBusy`, `Shake`, `ShakeTrace`, `ShakeCancel`) share one axiom budget: `propext` (propositional extensionality) and `Quot.sound` (soundness of quotient types), two ubiquitous axioms central to Lean 4's kernel. `Busy` depends on no axioms at all. No new axioms are declared in the verified core; no `sorry` survives in the build framework module.

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    table.header([*Inhabitant*], [*Axioms*], [*Behaviour*]),
    [`Busy`], [none], [runs `compute` directly; agreement proof is `rfl`],
    [`LessBusy`], [`propext`, `Quot.sound`], [intra-build memoisation; single-shot batch],
    [`Shake`], [`propext`, `Quot.sound`], [persistent verifying traces; default executor],
    [`ShakeTrace`], [`propext`, `Quot.sound`], [`Shake` with a dependency forest in `TraceT`],
    [`ShakeCancel`], [`propext`, `Quot.sound`], [`Shake` with cancellation tokens through `MonadCancel`],
  ),
  caption: [Mechanised inhabitants of `Build`, with axiom dependencies from `AxiomCheck.lean`.],
) <fig:build-inhabitants>

`Busy` is the reference: its `build` field is `compute` with one unfold, and its agreement proof is `rfl`. `LessBusy` is the first proof with work in it: an inductive argument over the well-founded relation on queries, showing that the memo table matches `compute` on every key encountered. `Shake` extends this argument across persisted stores via the cross-input invariant in @sec:free-theorem.

`ShakeTrace` and `ShakeCancel` reuse `Shake`'s proof. They are `Shake` parameterised at different effect monads ($n =$ `TraceT` for the first; $m =$ `Except Cancelled` for the second), with the same `tasks` value, the same store, and the same cache verification. The free theorem on `Tasks` lifts `Shake`'s agreement statement through the effect layer: supplying a `MonadAction` between the layered monad and `Id` discharges the relatedness side-conditions on `pure` and `>>=`, and the conclusion specialises to agreement under the new effect. The verification codebase is `Shake`'s; the layers contribute their `MonadAction` instances.

=== Elaborator tests <sec:elab-tests>

`Qdt/Test/` contains 14 files driven by the `#pass` and `#fail` macros. `#pass body` succeeds when `body` elaborates with no diagnostics; `#fail body with .error ..` succeeds when elaboration emits the named diagnostic. The current suite has 48 `#pass` and 37 `#fail` assertions, covering universes (`Universes.lean`, 41 cases), structure-$eta$ (`Eta.lean`), strict positivity (`Positivity.lean`), the recursor's $iota$-rule on `Eq` (`Eq3.lean`), quotient types (`Quotient.lean`), and the proof-irrelevant `Acc` accessor (`Acc.lean`). A representative `#fail`:

```lean
#fail (
  inductive Bad where
    | mk (f : Bad → Bad) : Bad
) with .nonPositiveOccurrence ..
```

The agreement theorem says the cache cannot drift from the elaborator's specification; the test suite says the specification is the one we intend.

=== Language-server scenarios <sec:lsp-tests>

`Qdt/Lsp/Test/` contains 17 scenarios driven by `Qdt/Lsp/Test.lean`. Each scenario sequences `setText` calls against an in-memory file system, fires a rebuild through the query layer, and asserts on diagnostics or hover responses produced by the language server. Categories: whitespace edits, body edits, type edits, cross-file propagation, import cycles, atomic moves, parser-error recovery, syntax recovery, and rename.

The `CrossFile.lean` scenario, where editing `foo` in `A.qdt` changes the hover for `bar` in `B.qdt`, runs:

```lean
setText (filepath := "A.qdt") qdt!( def foo := Type )
setText (filepath := "B.qdt") qdt!( import A
                                    def bar := foo )
hover (filepath := "B.qdt") ⟨2, 4⟩ "bar : Type 1" ⟨2, 4⟩ ⟨2, 7⟩

setText (filepath := "A.qdt") qdt!( def foo := Type 1 )
hover (filepath := "B.qdt") ⟨2, 4⟩ "bar : Type 2" ⟨2, 4⟩ ⟨2, 7⟩
```

The hover changes on the second `setText` without any explicit recomputation request. The cross-file dependency exists because `bar`'s elaborated type fetched `foo` during conversion in `A.qdt`; that fetch is the edge `Shake` invalidates.

=== Trace agreement <sec:trace-agreement>

`ShakeTrace` records, per build, a forest of `DepNode (Key, durationNs, children)` with one node per query fetch. A fetch with `durationNs` above a 1 μs threshold corresponds to a task that ran; a fetch below the threshold is a cache hit. Across the 17 LSP scenarios, the recomputed set in the trace coincides with the invalidation set that `Shake.verifyDeps` walks (the proof's hit-or-miss decision), and the hit set coincides with the proof's cached set. The implementation walks the same dependency graph the proof reasons about: every fetch in the trace corresponds to an edge in the proof, and every edge in the proof appears as a fetch.
