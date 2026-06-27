<!-- Template: MACP skill-evolution ledger. Copy to your project root as SKILLS.md. -->
# SKILLS.md -- skill-evolution ledger

Append-only index of task-to-skill decisions, skill eval results, and
skill-evolution costs. Optional commit trailers (`Skill-*`) point back to this
ledger. Metrics are computed by `bin/skill-ledger-metrics.py`.

See `docs/macp-skill-evolution-extension.md`.

## Human index

| task_id | skill_id | event | eval_type | eval_score | baseline_score | verifier_coverage | evidence | git_commit |
|---------|----------|-------|-----------|------------|----------------|-------------------|----------|------------|
| TASK-123 | example-skill | created | virtual | 0.80 | 0.50 | - | .ai-skill-evals/TASK-123/example.json | pending |

## Machine-readable ledger

Columns are tab-separated:

`task_id skill_id event eval_type eval_score baseline_score verifier_coverage cost_tokens cost_minutes evidence git_commit`

```skill-ledger
# TASK-123	example-skill	created	virtual	0.80	0.50	-	12000	15	.ai-skill-evals/TASK-123/example.json	pending
```
