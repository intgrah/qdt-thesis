== Bidirectional type checking <sec:bidirectional>

Type checking is bidirectional @dunfield2021bidirectional. Rather than a single judgement $Gamma tack.r t : A$, the algorithm splits into two mutually recursive functions:

- `inferTm ctx ast : OptionT ElabM (Tm n × VTy n)`: synthesise a core term and its type. Used when the expected type is unknown.
- `checkTm ctx expectedTy ast : ElabM (Tm n)`: produce a core term at a known expected type. On failure, a diagnostic is emitted and a fresh axiom inserted as placeholder.

The split means a lambda's parameter type comes from the expected Pi type (so it can be left unannotated), the algorithm is syntax-directed (one case per AST constructor), and mismatches are reported at the exact subterm.

The mode-switching rules:

- *Lambdas* are checked against $Pi (x : A). B$: the body is checked against $B$ with $x : A$ in context. If the parameter has a type annotation, it must match $A$; otherwise $A$ is taken from the expected type.
- *Applications* are inferred. The function $f$ is inferred to type $T$. If $T$ is not Pi after whnf, the elaborator fails. Otherwise $T = Pi (x : A). B$, the argument $a$ is checked against $A$, and the result has type $B[a slash x]$.
- *Variables* are inferred by context or environment lookup.
- *Let-bindings*: infer the bound value's type, check the body in the extended context.
- *Universes* $sans("Type")_ell$ are inferred to have type $sans("Type")_(ell + 1)$.
- *Subsumption*: when inference meets a checking position, the inferred type is compared against the expected type by the conversion checker.

`inferTm` and `checkTm` are mutually recursive with `checkIdent` for variable lookup (local context first, then global environment). The application case of `inferTm`:

```lean
| .node `Term.app #[fn, arg] => do
    let (fnTm, fnTy) ← inferTm ctx fn
    let .pi _ dom ⟨env, codTm⟩ := fnTy
      | raiseError (.expectedFunctionType ctx.names (← fnTy.quote))
    let argTm ← checkTm ctx dom arg
    let argVal ← argTm.eval ctx.env
    let codVal ← codTm.eval (env.cons argVal)
    return (.app fnTm argTm, codVal)
```

`inferTm` always returns a `VTy` produced by `Ty.eval`, so `fnTy` is already in weak head normal form; no `whnf` call is needed to expose the Pi. The codomain is substituted via evaluation in the closure's extended environment, not explicit syntactic substitution.

On failure (`sorry`, unbound variable, type mismatch) the elaborator emits a diagnostic and inserts a fresh axiom as placeholder. The rest of the file remains type-checkable, so the language server can report errors throughout.
