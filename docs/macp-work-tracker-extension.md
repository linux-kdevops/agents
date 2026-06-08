# MACP work-tracker extension

**Protocol version**: 1.2
**Status**: draft
**Extends**: the base MACP commit format without replacing any
required field.

MACP records the durable collaboration trail in git: commits,
`.ai-traces/`, prompt ledgers, handoff fields, and MCP usage
receipts. A work tracker such as Linear can add a private queue and
coordination layer around that trail, but it must not become the
source of truth for what changed or why.

This extension records the link between a MACP commit and an external
work item. Linear is the first intended tracker, but the trailers are
generic enough for GitHub Issues, GitLab, Jira, or a future local
tracker.

## Principle: git is truth, tracker is queue

Use the work tracker for:

- private maintainer backlog items that are not ready for public issue
  trackers;
- agent task queues such as design, implementation, testing, review,
  release, and follow-up work;
- private security, benchmark, legal, or maintainer notes that should
  guide agents but not appear in a public GitHub issue;
- long-running roadmap and triage state;
- linking multiple agent sessions to the same maintenance objective.

Do not use the work tracker as the only durable record. A public commit
or pull request must stand on its own without private tracker access.
Private context may guide the agent, but the git commit, trace, and
public PR text must contain enough public rationale for future
maintainers.

## Commit trailers

When a commit is driven by or resolves a work item, add this optional
block above the `Generated-by` / `Signed-off-by` pair:

```text
Work-Tracker: linear
Work-Item: RUSH-123
Work-Role: source
Work-Visibility: private-context
Work-Resolution: fixed
```

The fields are:

- `Work-Tracker`: tracker name. Supported values are `linear`,
  `github`, `gitlab`, `jira`, and `other`.
- `Work-Item`: tracker-native item ID or stable URL. For Linear,
  prefer the issue key such as `RUSH-123` or `KNLP-42`.
- `Work-Role`: how the work item relates to the commit. Supported
  values are `source`, `handoff`, `followup`, `blocked-by`,
  `security`, `release`, `review`, and `triage`.
- `Work-Visibility`: whether the tracker item contains only public
  information or private context. Supported values are `public`,
  `private`, `private-context`, and `redacted`.
- `Work-Resolution`: optional outcome for this commit. Supported
  values are `fixed`, `partial`, `deferred`, `wontfix`, `research`,
  and `none`.

The base MACP hook and MACP-lite hook validate these fields only when
any `Work-*` trailer is present. Projects that do not use a work
tracker are unaffected.

## Linear labels and states

For Linear, keep the label set small:

```text
macp
agent-ok
human-required
human-only
visibility:public-safe
visibility:private-context
visibility:redacted
risk:low
risk:medium
risk:high
task:design
task:implement
task:debug
task:test
task:docs
task:triage
task:release
task:security
```

Use Linear workflow state for lifecycle instead of labels:

```text
Triage -> Ready for Agent -> In Progress -> Needs Review -> Done
Blocked
```

Use assignee for ownership when the integration supports it, for
example `Codex`, `Claude`, `Gemini`, or a human maintainer. Avoid
duplicating the assignee as a label.

## Linear issue template

Use this template for MACP-driven Linear issues:

```markdown
Goal:
Public context:
Private context:
Agent mode: autonomous | assist | human-required
Allowed agents:
Acceptance criteria:
Required checks:
Forbidden changes:
MACP trace path:
Related commits:
Declassification: public | private | redacted
```

The `Private context` section is for information that agents may use
but public contributors should not need. If the task produces a public
commit or pull request, summarize the public parts in git and leave
private details in Linear.

## Project profiles

Self-maintaining projects such as Rush can use Linear as an
agent-maintainer queue. Agents can triage public GitHub issues, create
private Linear follow-ups, implement patches, run checks, open PRs, and
record the MACP trail in git. Humans remain the release, security, and
governance boundary.

Standards or legally sensitive projects such as KPAX should use Linear
for permission gates, review status, and private planning. Do not put
proprietary source text or restricted standards text into Linear unless
the project has explicit permission for that service and agent access
model.

Human-maintained upstream-facing projects such as KNLP should use
Linear conservatively: experiment queues, benchmark failures, review
reminders, and patch-prep state. Upstream patches must not require
private Linear access to understand the change.

## Examples

### Linear-driven implementation

```text
rush: fix repository memory budget leak

Fix the leak described in RUSH-123 by releasing the reservation on
all loader error paths. The public rationale is included here; the
private Linear item only carried reproducer logs and triage notes.

AI-Agent: ChatGPT-Codex
AI-Session-ID: 2026-06-06-142000-ChatGPT-Codex
AI-Task-Type: implement
AI-Context-Tokens: ~18000
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: .ai-traces/2026-06-06-142000-ChatGPT-Codex.md
Work-Tracker: linear
Work-Item: RUSH-123
Work-Role: source
Work-Visibility: private-context
Work-Resolution: fixed

Generated-by: ChatGPT Codex
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
```

### Private follow-up from public work

```text
Work-Tracker: linear
Work-Item: KNLP-42
Work-Role: followup
Work-Visibility: private-context
Work-Resolution: deferred
```

Use this when a public commit leaves a private benchmark,
coordination, or release follow-up that should not become public issue
tracker noise.
