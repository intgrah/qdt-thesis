== Correctness <sec:correctness-eval>

The agreement theorem says: for any `Tasks` value and any inhabitant of `Build`, the inhabitant returns the same `Constant` as the reference `compute`. The theorem is unconditional in the executor's internal state and effect monads. What it does not say is that the `Tasks` value implements the type theory of @sec:fragment --- that is, the proof rules out any drift between cache and compute, but it does not pin down what compute actually computes. The tests in @sec:elab-tests, @sec:lsp-tests, and @sec:trace-agreement close that gap.

=== Mechanised inhabitants <sec:mechanised-inhabitants>

@fig:build-inhabitants lists the four mechanised inhabitants of `Build` and the axioms each depends on. `LessBusy` and `Shake` share one axiom budget: `propext` (propositional extensionality) and `Quot.sound` (soundness of quotient types), two ubiquitous axioms central to Lean 4's kernel. `ShakeStandardRdeps` additionally pulls in `Classical.choice` through `Std.Data.DHashMap`'s `get?_insert` lemmas. `Busy` depends on no axioms.

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    table.header([*Inhabitant*], [*Axioms*], [*Behaviour*]),
    [`Busy`], [none], [runs `compute` directly; agreement proof is `rfl`],
    [`LessBusy`], [`propext`, `Quot.sound`], [intra-build memoisation; single-shot batch],
    [`Shake`], [`propext`, `Quot.sound`], [persistent verifying traces; default executor],
    [`ShakeStandardRdeps`], [`propext`, `Classical.choice`, `Quot.sound`], [reverse-dependency tracking on top of `Shake`'s cache; short-circuits the trace walk on clean queries],
  ),
  caption: [Mechanised inhabitants of `Build`, with axiom dependencies from `AxiomCheck.lean`. `ShakeTrace` and `ShakeCancel` are `Shake` parameterised at different effect monads; their verification is `Shake`'s.],
) <fig:build-inhabitants>

`Busy` is the reference inhabitant: its `build` field is `compute` with a single unfold, and the agreement proof is `rfl`. `LessBusy` is the first proof with content: an induction over the well-founded relation on queries, showing the memo table agrees with `compute` on every key encountered. `Shake` extends this argument across persisted stores via the cross-input invariant from @sec:free-theorem. `ShakeStandardRdeps` reuses `Shake`'s cross-input invariant per cache entry and bundles four structural invariants (`Sound`, `Complete`, `Closed`, `DownClosed`) on the rdeps-augmented `Persist` to license short-circuiting the trace walk; @ch:appendix-proofs-rdeps walks the verification.

`ShakeTrace` and `ShakeCancel` reuse `Shake`'s proof. Each is `Shake` parameterised at a different effect monad ($n =$ `TraceT` for the first; $m =$ `Except Cancelled` for the second), with the same `tasks` value, the same store, and the same cache verification. The free theorem on `Tasks` lifts `Shake`'s agreement statement through the effect layer: a `MonadAction` between the layered monad and `Id` discharges the relatedness side-conditions on `pure` and `>>=`, and the conclusion specialises to agreement under the new effect. The verification is `Shake`'s; the layers contribute their `MonadAction` instances.

=== Elaborator tests <sec:elab-tests>

`Qdt/Test/` contains 14 files driven by the `#pass` and `#fail` macros. `#pass body` succeeds when `body` elaborates with no diagnostics; `#fail body with .error ..` succeeds when elaboration emits the named diagnostic. The current suite has 48 `#pass` and 37 `#fail` assertions, covering universes (`Universes.lean`, 41 cases), structure-$eta$ (`Eta.lean`), strict positivity (`Positivity.lean`), the recursor's $iota$-rule on `Eq` (`Eq3.lean`), quotient types (`Quotient.lean`), and the proof-irrelevant `Acc` accessor (`Acc.lean`). A representative `#fail`:

```lean
#fail (
  inductive Bad where
    | mk (f : Bad → Bad) : Bad
) with .nonPositiveOccurrence ..
```

The agreement theorem rules out drift between cache and specification; the suite rules out drift between specification and intent.

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

Hover changes on the second `setText` without an explicit recomputation request. The cross-file dependency exists because `bar`'s elaborated type fetched `foo` during conversion in `A.qdt`; that fetch is the edge `Shake` invalidates.

=== Trace agreement <sec:trace-agreement>

`ShakeTrace` records, per build, a forest of `DepNode (Key, durationNs, children)` with one node per query fetch. A fetch with `durationNs` above a 1 μs threshold corresponds to a task that ran; anything below is a cache hit. Across the 17 LSP scenarios, the recomputed set in the trace coincides with the invalidation set that `Shake.verifyDeps` walks (the proof's hit-or-miss decision), and the hit set coincides with the proof's cached set. The implementation walks the same dependency graph the proof reasons about: every fetch in the trace corresponds to an edge in the proof, and every edge in the proof appears as a fetch.
