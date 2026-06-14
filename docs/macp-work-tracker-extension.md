# MACP work-tracker extension

**Protocol version**: 1.3
**Status**: draft
**Extends**: the base MACP commit format without replacing any
required field.

MACP records the durable collaboration trail in git: commits,
`.ai-traces/`, prompt ledgers, handoff fields, and MCP usage
receipts. A work tracker such as Linear adds a coordination layer
around that trail, but it must not become the source of truth for what
changed or why.

This extension records the link between a MACP commit and an external
work item. Linear is the first intended tracker, but the trailers are
generic enough for GitHub Issues, GitLab, Jira, or a future local
tracker.

## Two notebooks: private lab notebook vs public-interfacing tracker

A research program typically keeps **two** notebooks, with different
audiences, and the tracker is only one of them:

- A **private lab notebook** — for example a git-tracked artifact
  archive of dated result directories, plans, and handoff writeups
  (the reasoning that produced each conclusion, recoverable later).
  This is the full, private record.
- A **public-interfacing notebook** — a *selectively shared* view used
  to coordinate with outside collaborators (upstream maintainers,
  reviewers). Linear in this role is not a private backlog; it is the
  curated public face of the work. Only what the team chooses to share
  appears here.

The rule is unchanged: **git is truth.** The private notebook holds the
full reasoning; the public-interfacing tracker holds the curated,
shareable subset plus links back to git. An agent must know which
notebook a given fact belongs in (see *Declassification workflow*).

## Principle: git is truth, tracker is queue and public face

Use the work tracker for:

- private maintainer backlog items that are not ready for public issue
  trackers;
- **public-interfacing coordination** with named outside collaborators
  (the `public-collab` visibility below);
- agent task queues such as design, implementation, testing, review,
  release, and follow-up work;
- private security, benchmark, legal, or maintainer notes that should
  guide agents but not appear in a public GitHub issue;
- long-running roadmap and triage state;
- linking multiple agent sessions to the same maintenance objective.

Do not use the work tracker as the only durable record. A public commit
or pull request must stand on its own without tracker access. Private
context may guide the agent, but the git commit, trace, and public PR
text must contain enough public rationale for future maintainers.

## Commit trailers

When a commit is driven by or resolves a work item, add this optional
block above the `Generated-by` / `Signed-off-by` pair:

```text
Work-Tracker: linear
Work-Item: RUSH-123
Work-Role: source
Work-Visibility: private-context
Work-Resolution: fixed
Work-Project: Asymmetric Quantization
Work-Milestone: Develop initial MP Mode support
```

The fields are:

- `Work-Tracker`: tracker name. Supported values are `linear`,
  `github`, `gitlab`, `jira`, and `other`.
- `Work-Item`: tracker-native item ID or stable URL. For Linear,
  prefer the issue key such as `RUSH-123` or `LMC-2`.
- `Work-Role`: how the work item relates to the commit. Supported
  values are `source`, `handoff`, `followup`, `blocked-by`,
  `security`, `release`, `review`, and `triage`.
- `Work-Visibility`: whether the tracker item contains only public
  information, private context, or is a shared collaboration surface.
  Supported values are `public`, `public-collab`, `private`,
  `private-context`, and `redacted`. Use `public-collab` when the item
  is an externally-visible coordination surface shared with named
  outside collaborators (distinct from `private-context`, which is a
  private item whose details guide the agent but do not appear in the
  public PR).
- `Work-Resolution`: optional outcome for this commit. Supported
  values are `fixed`, `partial`, `deferred`, `wontfix`, `research`,
  and `none`.
- `Work-Project`: optional. The tracker project (program line) the
  item belongs to. Free-form name or ID.
- `Work-Milestone`: optional. The tracker milestone (phase or gate)
  the item belongs to. Free-form name or ID.

The base MACP hook and MACP-lite hook validate these fields only when
any `Work-*` trailer is present. Projects that do not use a work
tracker are unaffected.

## Mapping a research program onto Linear

When Linear is the public-interfacing notebook for a program, use this
canonical mapping so standing up a collaboration is repeatable instead
of ad hoc:

| Linear object | Maps to | Example |
|---|---|---|
| Team | A collaboration boundary / repo community | `LMCache` |
| Project | A program line | `Asymmetric Quantization` |
| Milestone | A phase or gate | `Develop initial MP Mode support` |
| Issue | A work-package | `MP-mode split-tier storage wiring` |
| Issue links | The git branch + private-notebook dir | branch URL + result-dir path |
| `Work-Item` trailer | The issue, in the commit | `Work-Item: LMC-2` |

Keep the curated public summary in the issue body; keep the full
reasoning, raw data, and large artifacts in the private notebook and
out of the tracker.

## Declassification workflow

Moving a result from the private notebook to the public-interfacing
tracker is a deliberate step, not a copy-paste:

1. The full result lives in the private notebook (dated dir, plan,
   writeup, metrics).
2. Curate a **public summary**: what was done, the headline outcome,
   and the framing — omitting raw data, private benchmarks, and
   not-yet-earned claims.
3. Create or update the Linear issue with that summary, and link the
   git branch and (optionally) the private-notebook dir.
4. In the commit, set `Work-Visibility: public-collab` and reference
   the issue with `Work-Item`.
5. Leave private details in the private notebook. The public PR must
   still stand alone without tracker access.

This mirrors the issue template's `Declassification:` field: it names
the source (private notebook) and the target (public tracker) of each
shared fact.

## Linear labels and states

For Linear, keep the label set small:

```text
macp
agent-ok
human-required
human-only
visibility:public-safe
visibility:public-collab
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
Declassification: public | public-collab | private | redacted
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

Human-maintained upstream-facing projects such as KNLP keep a **private
lab notebook** as the source of reasoning and use Linear as the
**public-interfacing notebook** for collaboration with upstream
maintainers. Use `public-collab` for issues shared with a named
maintainer (for example coordinating an LMCache asymmetric-quantization
PR with its reviewer): the Linear project is the program line, its
milestones are the phases, and its issues carry the curated public
summary plus links to the git branch. Upstream patches must not require
tracker access to understand the change.

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

### Public-collab coordination with an upstream maintainer

```text
lmcache: wire split-tier K/V placement for MP mode

Route exact K to the host tier and compressed V to L2 on top of the
existing write-behind drainer. Coordinated with the upstream reviewer
on the shared Linear board; the curated public summary and branch link
live in the issue, the full eval reasoning stays in the private lab
notebook.

AI-Agent: Claude-Code
AI-Session-ID: 2026-06-14-234258-Claude-Code
AI-Task-Type: implement
AI-Context-Tokens: ~40000
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: none
Work-Tracker: linear
Work-Item: LMC-2
Work-Role: source
Work-Visibility: public-collab
Work-Resolution: partial
Work-Project: Asymmetric Quantization
Work-Milestone: Develop initial MP Mode support

Generated-by: Claude Opus 4.8
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
