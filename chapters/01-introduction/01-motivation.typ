== Motivation

In a conventional compiler, changing a function body without changing its type cannot affect downstream type checking. In a dependently typed language, types can mention terms, so type checking may need to reduce through definition _bodies_ during conversion checking. When I edit a single definition in a file in Lean @moura2021lean, the elaborator re-checks every subsequent definition, even if most of them never unfold what I changed.

Lean @moura2021lean, Agda @norell2009agda, and Rocq @barras1999coq all treat a file as a sequence. Across files, each caches compiled results per file. Within a file, Lean saves snapshots of elaboration state at each top-level command and resumes from the last valid one; Agda caches results per declaration for the unchanged prefix; Rocq re-checks from the first modified sentence onward. An edit in the middle invalidates the entire suffix.

If a definition's body changes but its type is unaffected, definitions that depend only on its type need not be re-checked. But the dependency structure is discovered dynamically during elaboration: conversion checking may or may not unfold a given definition, depending on the specific terms being compared. Tracking which results depend on which, and recomputing only what has been invalidated, requires a build system that supports dynamic dependencies.
