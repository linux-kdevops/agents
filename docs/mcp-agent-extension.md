# MACP extension: in-band agent consultation with verifiable receipts

**Protocol version**: 1.1
**Status**: active
**Extends**: the base MACP commit format (does not replace any required field)

The base MACP protocol records *that* AI assistants collaborated and hands
work off between sessions. This extension covers the case where the primary
assistant consults a **second model in-band** — for example Claude Code
calling Codex (GPT-5.x) over the `codex` MCP server — and records that
consultation, including its real token cost, directly in the git history. It
replaces the manual relay loop (assistant → human → second model → human →
assistant) with an auditable, in-band channel.

It was first developed and exercised in the Rush build-system project; this
document generalizes it for any project that adopts the MACP template.

## 1. Principle: receipt over self-report

A consulted model's prose may misstate its own identity ("GPT-5" when it is
`gpt-5.5`) and its own token count (a mid-turn snapshot rather than the final
cumulative total). Do not trust what the model says about itself. MCP servers
that expose a session **rollout / usage file** (e.g. Codex writes one per
thread under `${CODEX_HOME:-$HOME/.codex}/sessions/YYYY/MM/DD/rollout-*.jsonl`
with `session_meta` and `token_count` events) give ground truth. Always read
the model name and token usage from that receipt file, never from the reply.

## 2. Commit-trailer credit scheme

When a second model was consulted, add this block **above** the
`Generated-by` / `Signed-off-by` pair (which must remain consecutive, as the
base hook requires):

```
MCP-Server: <server name, e.g. codex>
MCP-Model: <model + cli version, e.g. gpt-5.5 (codex-cli 0.134.0)>
MCP-Session-ID: <thread/session id>
MCP-Usage-Receipt: <server>-rollout:<relative path to the receipt file>
MCP-Token-Usage: input=<N> cached_input=<N> output=<N> reasoning_output=<N> total=<N>
Collab-Method: dual-plan-grade | single-consult | review-only
Collab-Plan-ID: <YYYY-MM-DD-task-slug>
Collab-Plan-Scores: primary=<x.x> consulted=<x.x> merged=<x.x>
Collab-Plan-Winner: primary | consulted | merged
```

The `MCP-*` lines are produced mechanically (section 3), never by hand. The
last four `Collab-*` lines are present only for the full `dual-plan-grade`
method; the lightweight modes carry just the `MCP-*` receipt lines and
`Collab-Method`. `total` in `MCP-Token-Usage` is the credit unit; break out
`cached_input` and `reasoning_output` because they bill differently from
fresh input/output.

## 3. Mechanical capture, fail-closed (NO-STUBS)

A helper script locates the one rollout/usage file for a session and emits the
model, version, receipt path, and final cumulative token usage — ready to
paste as trailers. It must **fail closed**: exit non-zero with no output if
the receipt is missing, ambiguous, or lacks usage data, so a commit preflight
refuses rather than records a fiction. This is the NO-STUBS guarantee: token
values are never invented. (Reference implementation in the adopting project,
e.g. `scripts/macp-codex-usage.sh <session-id> --trailers`.)

## 4. Dual-plan generate → grade → merge → re-grade

For any non-trivial decision:

1. Pick `plan_id = YYYY-MM-DD-task-slug`; write the brief to
   `.ai-traces/dual-plan/<plan_id>/brief.md`.
2. The primary assistant writes `primary-plan.md`.
3. Send the **same** brief to the consulted model in a fresh session; save its
   reply verbatim to `consulted-plan.md`, and its usage to `usage.json`.
4. Grade both plans on the rubric (section 5) → `grades-initial.json`, one line
   of rationale per dimension so each score is contestable.
5. Write `merged-plan.md`, resolving disagreements explicitly; grade the merge
   → `grades-final.json`.
6. Winner = highest weighted score; ties go to `merged`. Implement the winner
   and commit with the section-2 trailer block.

**Lightweight modes** (recorded in `Collab-Method`): `single-consult` (one
question, no independent plan) and `review-only` (the consulted model
critiques the primary's plan, no independent plan). Both still record the
`MCP-*` receipt trailers.

## 5. Fixed grading rubric

Scored 0–10 per dimension; weighted total = Σ(score·weight)/10.

| Dimension | Weight | Measures |
|-----------|-------:|----------|
| Completeness | 2.0 | covers the full ask |
| Correctness/Compatibility | 2.0 | works with the toolchain and constraints; real sources |
| Simplicity | 1.5 | fewest moving parts; readable per-commit |
| Auditability | 1.5 | reconstruct who-did-what and cost from git alone |
| Anti-toil | 2.0 | actually removes manual relay; low friction |
| Extensibility | 1.0 | future agents, cross-grading, evolves |

**Self-grading bias.** The primary assistant grades both plans, including its
own. Mitigations: the consulted plan is saved verbatim for spot-checks; every
score carries rationale; the git-derived ledger surfaces systematic bias over
time; and `review-only` cross-grading (the consulted model grades both) can be
added for high-stakes decisions.

## 6. Ledger derived from git, not maintained

The git log is the source of truth — trailers travel with history and cannot
drift. A ledger script parses the `Collab-*` / `MCP-*` trailers out of
`git log --format=%B`; there is no hand-maintained ledger file. Each row:
plan_id, commit, scores, winner, model, consulted-model total tokens. Use it
to answer "which planner wins?" and "do merges beat single plans?" as the
dataset grows.

## 7. Inverted roles

When the primary assistant's context or budget runs low, flip the roles: the
consulted model becomes the primary implementer and the original assistant
becomes the reviewer, conserving its scarce context for judgment (specs + diff
review). A handoff capsule is required before flipping: current goal,
dirty-tree status, acceptance gate, forbidden changes, known-failing tests,
required pilots that must not regress, and whether external caches/tools are
provisioned. Without the capsule, do not flip.
