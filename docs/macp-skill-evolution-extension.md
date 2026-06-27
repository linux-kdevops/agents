# MACP skill-evolution extension

**Protocol version**: 1.4
**Status**: draft -- `Skill-*` trailer validation WIRED in
`bin/commit-msg-hook` and `bin/commit-msg-hook-lite`; ledger metrics are
implemented by `bin/skill-ledger-metrics.py`.
**Extends**: the base MACP commit format, the work-tracker extension, and
the cognitive-memory extension without replacing any required field.

This extension turns AI skills into tracked project artifacts. A MACP task
should not merely say which agent worked on it; it should also say whether
the task had the skill it needed, reused an existing skill, created a new
one, or evolved a stale one.

The design is informed by OpenSkill, "Open-World Self-Evolution for LLM
Agents" (arXiv:2606.06741): keep skills explicit and transferable, acquire
skill content from open-world evidence, build verification from independent
anchors, and reserve target-task supervision for final evaluation.

## Principle: every task gets a skill decision

A task entering an agent queue has one of four skill outcomes:

- `missing`: no suitable skill exists yet; the gap is now visible.
- `reused`: an existing skill was sufficient.
- `created`: a new skill was written for this task or task family.
- `evolved`: an existing skill was improved because this task exposed a
  bug, missing rule, outdated API, weak example, or weak verification.

`none` is allowed only when the task genuinely requires no reusable
knowledge artifact. Avoid silent absence: if a task is important enough
to track, it is important enough to record why no skill was needed.

## Artifacts

- `SKILLS.md` -- append-only skill ledger index. Copy
  `templates/SKILLS.md` into adopting projects.
- `skills/<skill-id>/SKILL.md` -- the project's native skill artifact.
  The exact skill format is tool-specific; the ledger only needs a stable
  id.
- `.ai-skill-evals/<task-id>/<timestamp>.json` -- optional per-task
  evidence bundle containing virtual-test output, final-test output,
  costs, and links to cited open-world sources.
- `Skill-*` commit trailers -- optional commit-level links between code,
  tasks, and skill events.

## Skill lifecycle

1. **Triage.** Map the task to an existing skill, or record `missing`.
2. **Acquire.** Retrieve grounded evidence from documentation, source
   repositories, standards, papers, issue threads, or project history.
3. **Plan.** Decide whether to reuse, create, split, merge, or evolve a
   skill. Record the skill id before editing it.
4. **VirtualEval.** Build checks from public or independently verifiable
   anchors: API contracts, sample data, documented invariants, known
   output formats, project fixtures, or synthetic inputs derived from
   public rules.
5. **Evolve.** Update the skill and rerun the virtual checks. If the
   failure is a knowledge gap, retrieve more evidence rather than making
   the skill guess.
6. **FinalEval.** Run product CI, acceptance tests, benchmark holdouts, or
   human review. Do not feed hidden final-test details back into skill
   construction.
7. **Record.** Append a `SKILLS.md` row and, when committing related
   code/docs, add the `Skill-*` trailers.

## Do projects need tests for skill evals?

Yes, if they want to measure skill progress rather than merely inventory
skills. They do **not** need a benchmark-grade hidden test suite before
adopting this extension.

Use three levels:

| Level | Purpose | Examples | Can guide skill edits? |
|---|---|---|---|
| Smoke checks | Catch broken skill packaging | markdown exists, referenced files exist, examples run | yes |
| Virtual checks | Provide supervision-free practice | deterministic tests from public docs, fixtures, invariants, API examples | yes |
| Final/holdout checks | Measure real task impact | project CI, acceptance tests, hidden benchmark tests, maintainer review | no, report only |

If no executable checks exist, record `eval_type=none` and
`eval_score=-`. The next useful follow-up is to create virtual checks
from public anchors. Without at least virtual checks, the project can
measure skill coverage and reuse, but not skill quality.

## Metrics

Track these over time from `SKILLS.md`:

- **Skill coverage**: tasks whose latest skill event is `created`,
  `reused`, `evolved`, or `evaluated`, divided by all ledgered tasks.
- **Open skill gaps**: tasks whose latest event is `missing`, `needed`,
  `none`, or `retired`.
- **Virtual pass rate**: average `eval_score` for `eval_type=virtual`.
- **Final pass rate**: average `eval_score` for `eval_type=final` or
  `holdout`.
- **Lift**: `eval_score - baseline_score`, where the baseline is usually
  no-skill, prior-skill, or previous-release performance.
- **Verifier coverage**: fraction of known final-test intents covered by
  virtual checks when that mapping is available.
- **Verifier alignment**: agreement between virtual pass/fail and final
  pass/fail once enough paired runs exist.
- **Reuse / transfer**: count of distinct tasks using the same skill, and
  whether the same skill works across agents or models.
- **Cost**: tokens and wall-clock minutes spent creating or evolving the
  skill.
- **Decay**: negative deltas in final or virtual score after dependency,
  API, or project changes.

Run:

```bash
bin/skill-ledger-metrics.py SKILLS.md
bin/skill-ledger-metrics.py --json SKILLS.md
```

## `SKILLS.md` ledger schema

The machine-readable block is tab-separated and append-only:

```text
task_id	skill_id	event	eval_type	eval_score	baseline_score	verifier_coverage	cost_tokens	cost_minutes	evidence	git_commit
```

Values:

- `task_id`: work item id, issue id, or stable local task slug.
- `skill_id`: stable skill id, or `none` when `event` is `missing`,
  `needed`, or `none`.
- `event`: `needed`, `missing`, `created`, `reused`, `evolved`,
  `evaluated`, `retired`, or `none`.
- `eval_type`: `none`, `smoke`, `virtual`, `final`, `holdout`, or
  `manual`.
- `eval_score`: decimal `0..1`, percent such as `87.5%`, or `-`.
- `baseline_score`: same format as `eval_score`; use `-` if unknown.
- `verifier_coverage`: decimal/percent for covered final-test intents,
  or `-` if unknown.
- `cost_tokens`: integer token count, or `-`.
- `cost_minutes`: integer or decimal minutes, or `-`.
- `evidence`: path/URL to the evidence bundle, or `-`.
- `git_commit`: introducing commit hash, or `pending` before commit.

## Commit trailers

When a commit creates, reuses, evaluates, or changes a skill, add this
optional block above `Generated-by` / `Signed-off-by`:

```text
Skill-Ledger: SKILLS.md
Skill-Task: RUSH-123
Skill-ID: rust-async-backpressure
Skill-Event: evolved
Skill-Eval: virtual-pass
Skill-Trace: .ai-skill-evals/RUSH-123/2026-06-27.json
```

Fields:

- `Skill-Ledger`: path to the ledger, normally `SKILLS.md`.
- `Skill-Task`: task id or work item id.
- `Skill-ID`: stable skill id, or `none` for `missing`, `needed`, or
  `none`.
- `Skill-Event`: `needed`, `missing`, `created`, `reused`, `evolved`,
  `evaluated`, `retired`, or `none`.
- `Skill-Eval`: optional summary: `virtual-pass`, `virtual-fail`,
  `final-pass`, `final-fail`, `partial`, `not-run`, or `n/a`.
- `Skill-Trace`: optional path/URL to the eval evidence.

The base hook and MACP-lite hook validate these fields only when a
`Skill-*` trailer is present.

## Leakage barrier

Skills may be built from task instructions, environment files, public
docs, public repositories, papers, standards text the project is allowed
to use, and project-owned traces. Skills must not be built from hidden
final-test answers, private benchmark solutions, verifier outputs that
are meant to be held out, or leaked maintainer expectations.

The clean rule is: virtual checks can guide skill edits; final checks can
only measure and create follow-up tasks. A final failure can justify a
new task, but the hidden assertion itself must not be copied into the
skill.
