== Bidirectional type checking <sec:bidirectional>

The elaborator implements the bidirectional discipline of @coquand1996algorithm as two mutually recursive functions over the AST produced by the parser:

```lean
inferTm : Ctx n → Ast → OptionT ElabM (Tm n × VTy n)
checkTm : Ctx n → VTy n → Ast → ElabM (Tm n)
```

`inferTm` synthesises a core term and its type from an AST node when no expected type is available. `checkTm` consumes an expected type as input and returns a core term at that type. Both are indexed by `Ctx n`, the local context after $n$ bindings, so the returned core term `Tm n` is intrinsically scoped: it can mention only the $n$ in-scope de Bruijn indices, and the type system enforces this at elaboration time.

The two modes correspond to the two pieces of information the elaborator has on hand. When the expected type is known — from a definition's signature, a let annotation, or a Pi codomain — checking pushes the type into subterms. When no expected type is known — at the head of an application, the bound expression of a let — the elaborator must synthesise a type from the term's syntactic form. The split is exhaustive: every AST constructor has exactly one applicable case in one mode.

=== Cases of inference

`inferTm` covers the AST constructors whose type is determined by the term alone.

*Variables and constants.* A local identifier is looked up in the context; the type is read out of the binding. A global identifier triggers `fetchConstant`, which issues a `Key.constant` query into the build system and records a dependency. The returned `Constant` carries its type, which is instantiated at the supplied universe arguments.

*Universes.* $sans("Type")_ell$ infers to $sans("Type")_(ell + 1)$. The level $ell$ is parsed from the AST as a universe-level expression, not a term.

*Applications.* The head is inferred to a type, which must be a Pi after weak head normalisation. Because `inferTm` returns a `VTy` produced by `Ty.eval`, the type is already in WHNF; no extra `whnf` call is needed. The argument is checked against the domain, then the codomain is substituted by evaluating its closure in the extended environment.

*Let-bindings* with an annotation. The annotation provides the expected type; the bound value is checked, the body is inferred in the extended context.

*Annotated terms* $(e : A)$. The annotation switches direction: $A$ is elaborated as a type, $e$ is checked against $A$, and $A$ is the inferred type.

The application case is the only one where a non-trivial value is constructed by hand:

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

The substitution $B[a slash x]$ from the declarative Pi-elimination rule is implemented as `codTm.eval (env.cons argVal)`: evaluating the codomain's defunctionalised closure body in its captured environment extended by the argument's value. No explicit syntactic substitution is performed.

=== Cases of checking

`checkTm` covers the AST constructors whose elaboration depends on the expected type.

*Lambdas* without an annotation. The expected type must be a Pi; the parameter type $A$ is read from it, and the body is checked against $B$ in the context extended with $x : A$. If the lambda has a parameter annotation, the annotation is elaborated and compared against $A$ by conversion; a mismatch is a type error.

*Let-bindings* without an annotation. The bound value is inferred; the body is checked at the expected type in the extended context.

*Subsumption.* When none of the checking cases applies — typically a variable, application, or annotated term in a checking position — `checkTm` falls back to inference and invokes the conversion checker to compare the inferred type against the expected type. This is the only point where conversion is invoked from `checkTm` itself; deeper conversion is done by the rules that drive it.

=== Error recovery

A bidirectional elaborator's failures must not abort the whole file: the language server is expected to keep reporting types and diagnostics in the rest of the file even after a malformed declaration. Three failure modes are handled.

A literal `sorry` is parsed as an unspecified term; the elaborator emits a `Diagnostic.sorry` and returns a fresh axiom of the expected type. An unbound variable emits `Diagnostic.unbound` and returns a fresh axiom. A conversion failure during subsumption emits `Diagnostic.typeMismatch` carrying the inferred and expected types, and returns a fresh axiom at the expected type.

The fresh axiom is a `Constant.axiom` with a generated unique name and the appropriate type. Subsequent elaboration sees an inhabitant of the expected type and continues; downstream queries unfolding the axiom find no body and treat it as opaque. The `OptionT` layer on `inferTm` separates "no type could be inferred" (the option is `none`, the caller decides what to do) from "a hard error occurred" (raised through `ElabM`); only `checkTm`'s fallback path uses the option return.

`inferTm` and `checkTm` are mutually recursive with `checkIdent`, which looks up an identifier first in the local context and then in the global environment. `checkIdent` is where the cross-declaration dependency is registered: a global lookup that succeeds records a `Key.constant` dependency in the query graph, and the resolved `Constant` is cached in `ElabState.entryCache` to avoid repeated fetches within the same declaration's elaboration.
