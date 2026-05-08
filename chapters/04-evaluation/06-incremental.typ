== Incremental re-elaboration <sec:incremental-eval>

We measure re-elaboration time after targeted edits on the standard library, using a retained Shake store. The Shake build system is instrumented to count cache hits (queries whose fingerprints match and are reused) and recomputed queries. After a cold build populates the store, each edit modifies one input and triggers a rebuild against the existing cache.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    table.header([*Edit*], [*Time (ms)*], [*Speedup*]),
    [Cold build (no cache)], [1,027], [$1 times$],
    [No-op (retained store, no changes)], [129], [$8.0 times$],
    [Whitespace (append newline to entry file)], [127], [$8.1 times$],
    [Leaf (append definition to Ackermann.qdt)], [172], [$6.0 times$],
    [Hub (append definition to Nat.qdt)], [170], [$6.0 times$],
  ),
  caption: [Incremental re-elaboration of the standard library after targeted edits. Speedup is relative to cold build.],
)

The no-op rebuild verifies every fingerprint in the store but recomputes nothing --- the 129ms is the cost of traversing the dependency graph and checking hashes. The whitespace edit has the same cost: the green tree representation absorbs the whitespace change, the AST hashes the same, and no downstream query is invalidated.

The leaf edit appends a new definition to `Ackermann.qdt`, a file that no other file imports. The `declarationIndex` query for that file is invalidated (a new name appears), and the new definition is elaborated, but no other file's queries are affected. The hub edit appends a definition to `Nat.qdt`, which is imported by five other files. Despite the wider dependency fan-out, the rebuild takes the same time: the new definition does not change any existing constant's type or body, so the `constant` queries for existing Nat definitions hash the same, and early cutoff prevents the cascade from propagating to dependent files.
