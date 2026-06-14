# MACP cognitive-memory (cmm) extension

**Protocol version**: 1.3
**Status**: draft (prep — integration not yet wired)
**Extends**: the base MACP commit format and the work-tracker
extension; does not replace any required field.

The base MACP protocol records the collaboration trail in git and hands
work between sessions. A **cognitive-memory** layer adds the missing
piece: persistent *reasoning* memory that survives across sessions, so
an agent does not re-derive the same investigations, pitfalls, and
dead-ends each time.

The first intended provider is **cmm** (Cognitive Memory Manager,
`github.com/sazandkhalid/cmm`, Apache-2.0): it parses session JSONL
transcripts into a reasoning DAG, deduplicates and consolidates them
into a cognitive profile stored in a vector DB, and serves the result
over MCP. The trailers and conventions here are written so MACP traces
are **ingest-ready** the day the integration lands — no retrofit.

This document is preparatory. It defines the bridge; it does not depend
on cmm being installed.

## How cmm consumes and serves

Pipeline (provider side): session JSONL -> parse -> reasoning DAG ->
dedup -> vector store -> cluster -> cognitive profile -> served via MCP
/ CLI. Reasoning is typed: `HYPOTHESIS`, `INVESTIGATION`, `DISCOVERY`,
`PIVOT`, `DEAD_END`, `SOLUTION`, with causal edges (`led_to`,
`refined`, `caused_pivot_to`). Memories are classified
`PROJECT`-specific or `TEAM`-general. It exposes MCP entry points such
as a cognitive profile, semantic memory search, a ranked pitfall list,
and proven diagnostic strategies.

## Bridge 1: traces are DAG-shaped

MACP already standardizes `.ai-traces/` and a thought-trace template.
Align the trace vocabulary with cmm's DAG node types so existing traces
ingest cleanly:

| Thought-trace section | cmm DAG node |
|---|---|
| The question / goal | `HYPOTHESIS` |
| What was tried / explored | `INVESTIGATION` |
| What was found | `DISCOVERY` |
| Why the approach changed | `PIVOT` (`caused_pivot_to`) |
| What did not work | `DEAD_END` |
| The decision / result | `SOLUTION` |

Writing traces in these terms is the only change needed on our side; it
is good practice independent of cmm.

## Bridge 2: memory-provenance trailer

When a commit was guided by a retrieved memory, record it — mirroring
the MCP-agent extension's receipt trailers — with an optional trailer
above the `Generated-by` / `Signed-off-by` pair:

```text
Memory-Source: cmm:<profile-or-memory-id>
```

`Memory-Source` names the cognitive-memory provider and the specific
profile or memory id that informed the change, so a future maintainer
can audit *why* the agent took an approach. Multiple lines are allowed.
The value is free-form (`cmm:` prefix recommended). Hooks validate it
only when present, the same way `Work-*` and `MCP-*` blocks are.

## Bridge 3: visibility maps to the two-notebook boundary

cmm's `TEAM`-general vs `PROJECT`-specific classification must respect
the same boundary the work-tracker extension defines between the private
lab notebook and the public-interfacing tracker:

- A memory derived from **private** reasoning (private benchmarks,
  not-yet-earned claims, restricted data) stays `PROJECT`-specific and
  must not auto-propagate into a shared / team cmm store.
- Only **declassified** reasoning (see the work-tracker extension's
  declassification workflow) may become `TEAM`-general or land in a
  shared cmm cloud.
- In short: `public-collab`/`public` reasoning may be shared; private
  reasoning is local-only until declassified.

This prevents the cognitive-memory layer from leaking private context
that the tracker and PR rules are designed to keep out.

## Status and adoption order

Per the program's publish order, protocol support lands in this repo
first; adoption (wiring cmm to a project's `.ai-traces/` and MCP) is a
separate, downstream step. Until the integration is wired, this
document is the contract that keeps our traces and commits ready for it.
