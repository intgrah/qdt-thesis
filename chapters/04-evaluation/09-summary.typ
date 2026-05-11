== Summary

The elaborator processes the handwritten qdt corpus and the Lean 2 HoTT port without error. Conversion-checker throughput is within a constant factor of `smalltt`, and batch elaboration of synthetic programs is faster than Lean 4 across the four dependency shapes tested. Incremental re-elaboration after a targeted edit takes 12--17% of a cold build, with early cutoff preventing cascades through importing files when types are unchanged. The build system's correctness proofs reduce to the parametricity axiom and the injectivity of the hash functions.
