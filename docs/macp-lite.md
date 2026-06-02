# MACP-lite: a lighter commit profile

The base MACP commit format requires nine fields (`AI-Agent`, `AI-Session-ID`,
`AI-Task-Type`, `AI-Context-Tokens`, `AI-Handoff-From`, `AI-Handoff-To`,
`AI-Thought-Trace`, `Generated-by`, `Signed-off-by`) and is ideal for
multi-agent projects with real session handoffs and thought traces. Some
projects want the **trailer discipline and MCP-agent provenance without** the
full handoff bookkeeping — for example a mostly single-assistant R&D repo where
the `AI-Session-ID` / `AI-Handoff-*` / `AI-Thought-Trace` fields would be noise.

`bin/commit-msg-hook-lite` is that lighter profile. It enforces only what such a
project actually needs:

- a **model-explicit `Generated-by`** (not the bare `Generated-by: Claude AI`)
  **immediately followed by `Signed-off-by`**;
- AI attribution lives in `Generated-by` alone; the generic
  `Co-Authored-By: Claude` and the robot-emoji auto-footer
  (`🤖 Generated with [Claude Code]`) are rejected, and a `Co-Authored-By`
  that names an AI model is **warned** as redundant (reserve `Co-Authored-By`
  for a human co-author);
- the subject line is capped at 70 characters (body lines over 70 are warnings,
  so URLs, tables, and code are not blocked);
- when an `MCP-*` block is present (a second model was consulted in-band, see
  [`mcp-agent-extension.md`](mcp-agent-extension.md)), its core fields
  (`MCP-Model`, `MCP-Usage-Receipt`, `MCP-Token-Usage`) are sanity-checked.

It does **not** require the `AI-*` fields. Merge / `WIP:` / `fixup!` / `squash!`
commits skip validation, and `git commit --no-verify` bypasses it for a one-off.

## Install

```bash
cp bin/commit-msg-hook-lite <your-project>/.git/hooks/commit-msg
chmod +x <your-project>/.git/hooks/commit-msg
```

Projects that want a versioned copy can also commit the hook into their tree
(e.g. `scripts/commit-msg-hook`) and document the one-line install in their
`CLAUDE.md`, as the knlp project does. Choose the full profile
(`bin/commit-msg-hook`) when you want enforced session/handoff tracking; choose
the lite profile when you want trailer hygiene and MCP provenance only.
