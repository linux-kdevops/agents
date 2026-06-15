# MACP agentic-maintenance extension

**Protocol version**: 1.0
**Status**: draft
**Extends**: the base MACP commit format without replacing any required
field.

The base MACP protocol records *that* AI assistants collaborated and
hands work between sessions. The in-band consultation extension records
*who else was consulted* and its real cost. This extension adds the
piece that makes LLM-driven *maintenance* safe to merge: it treats the
LLM as **untrusted** and builds a cage of machine checks around it — a
formally verified core, independent functional oracles, an anti-vacuity
mutation gate, and a human review gate that fires specifically on
*spec-weakening* changes.

The thesis is the differentiator for self-maintaining projects such as
Rush: **Rust source-of-truth + Creusot proofs on a small verified
core + independent oracles + CI gates that treat spec-weakening as a
high-risk change.** The verifier, the tests, and the review gates are
the cage; the model is the thing in the cage.

## Principle: the model is untrusted, the cage is trusted

An LLM may write a correct implementation, or it may "fix" a failing
check by weakening the check. Both produce a green build. The cage
distinguishes them:

- A **verified core** crate (pure, deterministic, no I/O / clock /
  randomness / `unsafe` / FFI) carries machine-checked contracts. The
  small, side-effect-free surface is what makes proof tractable and the
  trusted computing base (TCB) auditable.
- Independent **oracles** (property, golden, fuzz tests — the "uDebug
  gate") witness behaviour the proof asserts, and catch what isn't yet
  proved.
- A **mutation gate** kills vacuous specs: a surviving mutant means the
  contracts and oracles are too weak.
- A **spec-review gate** routes any *spec-sensitive* change to a human.

The hook does **not** try to prove that a diff weakens a specification —
that is undecidable in general and not the hook's job. It conservatively
detects a *spec-sensitive diff* and **routes** it to review. False
positives cost a trailer; false negatives are caught again in CI over
the whole PR range, because local hooks are bypassable.

## Commit trailers

When a commit touches the verified core, an oracle, the TCB, or the
build config of a verified scope, add this block **above** the
`Generated-by` / `Signed-off-by` pair (which the base hook requires to
stay consecutive):

```text
Verify-Scope: cc-obj-name-v1
Verify-Proof: required
Verify-Oracle: required
Verify-Mutation: required
Spec-Change: none
Spec-Review: not-required
```

The fields are:

- `Verify-Scope`: the verified-scope id this commit affects, e.g.
  `cc-obj-name-v1`. **Required** on any commit that changes a
  verified-core or oracle file. Multiple scopes are comma-separated.
- `Verify-Proof`: `required` | `n/a` — whether `cargo creusot prove`
  must pass for this scope (gated on the toolchain being provisioned,
  see the TCB section).
- `Verify-Oracle`: `required` | `n/a` — whether the scope's property /
  golden / fuzz oracle must pass.
- `Verify-Mutation`: `required` | `n/a` — whether the mutation gate must
  show no surviving mutants for the touched code.
- `Spec-Change`: `none` | `impl-only` | `contract` | `oracle` |
  `trusted` | `toolchain` | `cfg` — the *kind* of spec-sensitivity.
  `none`/`impl-only` are self-service; the rest require review.
- `Spec-Review`: `not-required` |
  `human:<handle>:<YYYY-MM-DD>:<ticket-or-pr>` — the human sign-off when
  `Spec-Change` is not `none`/`impl-only`.

## Rules

1. Any change to a verified-core or oracle file (per the manifest below)
   **must** carry `Verify-Scope`.
2. Any change classified as `contract`, `oracle` (weakening),
   `trusted`, `toolchain`, or `cfg` **must** set `Spec-Change` to that
   value **and** carry `Spec-Review: human:<handle>:<date>:<ticket>`.
   `Spec-Change: none` with such a diff is a gate failure.
3. The hook/CI gate does **not** prove semantic weakening. It
   conservatively detects a *spec-sensitive diff* (heuristics below) and
   routes review. Over-flagging is acceptable; under-flagging is caught
   in CI over the PR commit range.
4. Local hooks are bypassable (`--no-verify`), so the **same** gate must
   run in CI over the PR commit range. The CI run is authoritative.

## The spec-owned manifest

The set of spec-owned paths lives in `ci/spec-owned.tsv` in the target
project (e.g. Rush). It is tab-separated, one row per owned path:

```text
<scope>	<kind>	<path>
```

`kind ∈ {contract, oracle, tcb, cfg}`:

- `contract` — verified-core source carrying proof obligations.
- `oracle` — a functional property / golden / fuzz test (the uDebug
  gate) for the scope.
- `tcb` — trusted computing base / toolchain pins.
- `cfg` — build configuration that can widen the verified base.

Example (Rush, `cc-obj-name-v1`):

```text
cc-obj-name-v1	contract	crates/rush-verified-core/src/cc_obj_name.rs
cc-obj-name-v1	oracle	crates/rush-verified-core/tests/cc_obj_name_prop.rs
cc-obj-name-v1	tcb	ci/creusot-toolchain.lock
cc-obj-name-v1	cfg	crates/rush-verified-core/Cargo.toml
```

## The hook detection heuristic

For each changed file, the gate looks up its `kind` in
`ci/spec-owned.tsv`. It inspects `git diff --cached -U0` (pre-commit) or
`git diff -U0 <range>` (CI) and applies these regexes verbatim:

```sh
contract_re='^[+-].*(#\[(requires|ensures|invariant|variant|trusted|erasure|logic|predicate|extern_spec)\b|logic[[:space:]]+fn|predicate[[:space:]]+fn|assume!\(|trusted|proof_assert!\()'
oracle_re='(^-.*(assert(_eq|_ne)?!|prop_assert|proptest!|#\[test\]|golden|fixture))|(^\+.*(#\[ignore\]|prop_assume!|todo!\(|unimplemented!\(|return;))'
tcb_re='^(rust-toolchain(\.toml)?|why3find\.json|ci/creusot-toolchain\.lock|Cargo\.lock|\.cargo/config\.toml)$'
```

Mechanically:

- A `contract` file whose `-U0` diff matches `contract_re` ⇒
  spec-sensitive (`Spec-Change: contract`).
- An `oracle` file whose `-U0` diff matches `oracle_re` ⇒ a *weakening*
  of the oracle (removed assertion/test, or added `#[ignore]` / `todo!`
  / `unimplemented!` / early `return;`) ⇒ spec-sensitive
  (`Spec-Change: oracle`).
- A `tcb` or `cfg` file changing at all (or any path matching `tcb_re`)
  ⇒ spec-sensitive (`Spec-Change: toolchain` or `cfg`).

When any of these fire, the commit must carry `Spec-Change != none` and
`Spec-Review: human:...`. The reference implementation is
`scripts/verify/spec-gate.sh --cached` (pre-commit, warn) and
`scripts/verify/spec-gate.sh --range <A>..<B> --require-trailers` (CI,
enforce).

## The 7-state agent loop

A maintenance task moves through seven states. Each state declares what
the agent **may** and **may not** edit, so a self-healing loop cannot
"fix" a check by gutting it.

1. **Plan.** Read the scope, the manifest, the failing signal. Produce a
   plan and the intended `Verify-*` / `Spec-Change` classification. No
   source edits.

2. **Implement.** Write the implementation and any *new* (stricter)
   contracts/tests. MAY edit implementation, add tests, tighten
   contracts. MAY NOT delete or loosen existing oracles/contracts.

3. **OracleGate.** Run the property / golden / fuzz oracles.
   - MAY: fix the implementation, or ADD stricter tests.
   - MAY NOT: delete, `#[ignore]`, or shrink tests to make them pass.

4. **ProofGate.** Run `cargo creusot prove` for the scope.
   - MAY: edit the implementation, invariants, lemmas, ghost code, and
     private helpers.
   - MAY NOT: weaken a public `ensures`, strengthen a public `requires`,
     add `assume!`, add `#[trusted]`, or alter a public `logic`/model
     function — without entering SpecReview.

5. **MutationGate.** Run mutation testing over the scope.
   - A surviving mutant ⇒ the spec is too weak ⇒ strengthen the
     tests/contracts (back through Implement/Oracle/Proof) **or** enter
     SpecReview if the gap is genuinely a spec decision.
   - MAY NOT: suppress mutants by deleting the assertions that would
     have killed them.

6. **SpecReview.** Required when any prior state flagged a spec-sensitive
   change. The agent **prepares evidence only** — the diff, the
   heuristic hits, proof/oracle/mutation results, and a rationale. A
   **human** approves and supplies
   `Spec-Review: human:<handle>:<date>:<ticket>`. The agent may not
   self-approve.

7. **Finalize.** Emit the commit with the full `Verify-*` /
   `Spec-Change` / `Spec-Review` trailer block (above
   `Generated-by`/`Signed-off-by`), and the in-band MCP receipt trailers
   if a second model was consulted.

## Anti-vacuity and TCB / artifact correspondence

A proof is only as trustworthy as what it is proved *about* and *with*.
This section closes the gaps an untrusted author would otherwise exploit.

**Lock the toolchain (TCB).** Pin and review-gate
`rust-toolchain.toml`, `Cargo.lock`, `why3find.json`, and
`ci/creusot-toolchain.lock` (the latter pinning `cargo-creusot`,
`creusot-rustc`, `why3`, `why3find`, and the SMT solvers `z3` / `cvc5` /
`alt-ergo`). A change to any pin can silently change what "proved"
means, so it is `Spec-Change: toolchain` and routes through review.

**Forbid escape hatches in the verified core.** Unless explicitly
manifest-owned, the verified-core crate must not contain `#[trusted]`,
`assume!`, `extern "C"`, `unsafe`, or any filesystem / process / clock /
randomness use. `unsafe` is a hard compile error there
(`#![forbid(unsafe_code)]`). Each of these would move logic out of the
proof's reach while leaving the proof green.

**No unverified cfg twin.** Reject non-test `#[cfg(...)]` in the verified
core except `#[cfg(creusot)]` (and the project's contract-feature gate).
A "verified fn has no unverified cfg twin" check (e.g.
`scripts/verify/no-unverified-twin.sh`) asserts that the *production*
path actually calls the verified function rather than a hand-rolled copy
that drifts from the proof.

**Anti-vacuity is demonstrable, not assumed.** Each oracle must
demonstrate it can FAIL: e.g. the Rush `cc-obj-name-v1` oracle includes a
witness that the *old* `/`→`_` encoding collides under the very property
the oracle enforces, proving the property is non-trivial. The mutation
gate generalizes this: surviving mutants reveal vacuous specs.

**Kani as a later bounded cross-check.** Once the Creusot proof is in
place, add Kani (bounded model checking) as an *independent* verifier
over the same contracts. Diversity of verifier reduces the chance that a
single tool's soundness bug passes a false proof; a disagreement between
Creusot and Kani is itself a high-signal finding.

## Example: Rush `cc-obj-name-v1`

A contract change to the injective object-name encoding, reviewed:

```text
verified-core: prove cc object-name encoding is injective

Replace the non-injective `/`->`_` object-name encoding with a
length-prefixed, injectively-escaped model proven collision-free.

Verify-Scope: cc-obj-name-v1
Verify-Proof: required
Verify-Oracle: required
Verify-Mutation: required
Spec-Change: contract
Spec-Review: human:mcgrof:2026-06-14:RUSH-PR-1

Generated-by: Claude Opus 4.8
Signed-off-by: Luis Chamberlain <mcgrof@gmail.com>
```

An implementation-only change in the same scope needs no human gate:

```text
Verify-Scope: cc-obj-name-v1
Verify-Proof: required
Verify-Oracle: required
Verify-Mutation: required
Spec-Change: impl-only
Spec-Review: not-required
```

## The Dafny addendum layer (`model:`)

Creusot verifies the Rust. **Dafny is the spec laboratory and golden model**,
not a Creusot replacement. It earns its keep on a project bound for
*entirely* generative-AI maintenance for two reasons a human team needs less:
the verified/not-verified signal is crisp for an agent loop, and a second
verifier stack (Dafny's Boogie/Z3 vs Creusot's Why3/SMT) gives **verifier
diversity** — if both an abstract Dafny model and the Creusot Rust impl agree
on the core property, that is far stronger than betting one stack was sober.

**Decision rule.** Creusot-alone to verify real Rust; Dafny-FIRST when still
discovering the algorithm/invariant; **Dafny + Creusot only for components
critical enough to want both an abstract verified model and a verified Rust
impl.** Do not Dafny-model everything — a model that does not constrain the
Rust is just a second spec pile to rot.

**The hard rule (the whole game).** A Dafny model may NOT merge unless it is
bound to the Rust by an *executable differential gate*. The model is compiled
to a runnable golden oracle (`dafny build -t:py`, since the Rust backend is
still partial) and the Rust output is diffed against it over bounded
generated cases. Without that gate the Dafny proof is decorative — "write
Rust, write unrelated Dafny, both pass something, ship bug, blame math."

**Refinement architecture:**

```text
Dafny model/spec  (verified abstract properties)
      ↓ dafny verify
LLM proposes / maintains Rust impl
      ↓ Creusot contracts MIRROR the model's properties
cargo creusot verifies the Rust-level obligations
      ↓ dafny build -t:py  →  executable golden oracle
property/differential test diffs Rust behaviour vs the golden oracle
      ↓
CI rejects patches that break the proof OR model↔Rust agreement
```

**New trailers** (present only on a Dafny-addendum scope):

```text
Verify-Model:  n/a | dafny:<scope>
Model-Refines: n/a | creusot:<scope>
Model-Oracle:  n/a | executable:python:<scope>
```

and `Spec-Change` gains a `model` value:

```text
Spec-Change: none | impl-only | contract | oracle | model | trusted | toolchain | cfg
```

**The loop gains a `ModelGate`** — it becomes 8-state, but only when
`Verify-Model` is present:

```text
Plan → ModelGate → Implement → OracleGate → ProofGate → MutationGate → SpecReview → Finalize
```

`ModelGate` rules (the Dafny model is spec-sensitive, like a public contract):

- The agent MAY edit the `.dfy` model/proof while CREATING or STRENGTHENING it
  (add predicates, lemmas, tighten postconditions).
- The agent MAY NOT weaken a model predicate/postcondition, add `assume`,
  `{:axiom}`, `{:verify false}`, `{:extern}`/`{:compile false}` trusted specs,
  or change the model↔contract binding without `Spec-Review`.
- ANY change to an existing model file is `Spec-Change: model`.

**Manifest + hook.** The `spec-owned.tsv` `model` kind binds the `.dfy` to its
contract + oracle + the `ci/dafny-toolchain.lock` TCB. The gate flags ANY
`.dfy` change as spec-sensitive and records the model regex hit as evidence:

```bash
model_re='^[+-].*((requires|ensures|invariant|decreases|predicate|function|lemma|method|datatype|ghost|forall|exists|assume)|\{:(axiom|verify false|extern|compile false)\})'
```

**TCB.** Dafny adds a second locked toolchain (`ci/dafny-toolchain.lock`:
dafny CLI + bundled Boogie/Z3 + the Python oracle backend). The diversity is
the point — but it is a second trusted base, so it is pinned and any change
routes through `Spec-Review` the same as the Creusot lock.

### Example: Rush `topo-roots-v1` (first Dafny addendum)

`topological_sort_from_roots` is the build-order core (a real serial-build
bug lived there) and an abstract seq/set model is exactly Dafny's sweet spot,
so it is the first scope to carry a Dafny addendum. The model
(`verification/dafny/topo_roots/TopSort.dfy`) defines `ValidTopo`: the order
has no duplicates, its node set is EXACTLY the reachable set (rejecting the
"drops a reachable node / returns empty" bug class), and every dependency
precedes the node needing it. A model-strengthening commit:

```text
verified-core: topo-roots Dafny model + Creusot contract + differential gate

Verify-Scope: topo-roots-v1
Verify-Model: dafny:topo-roots-v1
Model-Refines: creusot:topo-roots-v1
Model-Oracle: executable:python:topo-roots-v1
Verify-Proof: required
Verify-Oracle: required
Verify-Mutation: required
Spec-Change: model
Spec-Review: human:mcgrof:2026-06-15:RUSH-PR-2

Generated-by: Claude Opus 4.8
Signed-off-by: Luis Chamberlain <mcgrof@gmail.com>
```
