# CLAUDE.md

This file provides guidance to AI assistants (Claude, ChatGPT, Gemini, Cursor, etc.)
when working with the Multi-AI Collaboration Protocol (MACP) template project.

## Project Overview

This is the **MACP Template & Tooling** project - a framework for enabling multiple
AI assistants to collaborate efficiently on software projects while minimizing token
costs and maintaining full traceability.

**Purpose**: Provide copy-paste ready templates and enforcement tools for projects
that want AI collaboration with proper accounting and handoffs.

**Not a library**: This is a template repository. Users copy files to their projects.

## Commit Format

All commits to this project MUST follow MACP format (we practice what we preach):

```
subject: brief description (max 50 chars)

Detailed description in plain English explaining what changed and why.

AI-Agent: Claude-Code
AI-Session-ID: YYYY-MM-DD-HHMMSS-AI-NAME
AI-Task-Type: design|implement|debug|refactor|test|build|docs
AI-Context-Tokens: ~XXXXX
AI-Handoff-From: previous-session-id or "none"
AI-Handoff-To: next-session-id or "none"
AI-Thought-Trace: path/to/trace.md or "none"

Generated-by: Claude AI | ChatGPT | Gemini | etc.
Signed-off-by: Human Name <email@example.com>
```

**Enforcement**: The commit-msg hook validates all 9 required fields.

**AI attribution = `Generated-by`, once.** Record the AI that generated the
change in `Generated-by` (name the model explicitly, e.g. `Claude Opus 4.8
(1M context)`, not the bare `Claude AI`). Do **not** also add a
`Co-Authored-By` that names the same AI model — it is redundant with
`Generated-by` and semantically wrong (the AI generated the change; it is not
a human co-author). Reserve `Co-Authored-By` for an additional *human*
co-author. The `🤖 Generated with [Claude Code]` auto-footer is never used.

## Protocol Extensions

When the primary assistant consults a second model in-band (e.g. Claude Code
calling Codex over an MCP server), record the consultation — including its real
token cost, read from the model's usage receipt rather than its self-report —
with `MCP-*` and `Collab-*` trailers above the `Generated-by`/`Signed-off-by`
pair. This MCP-agent extension (dual-plan generate→grade→merge loop, fixed
grading rubric, git-derived ledger) is documented in
[`docs/mcp-agent-extension.md`](docs/mcp-agent-extension.md). The base
commit-msg hook is unchanged; the extension's trailers are produced
mechanically and validated by the usage script (fail-closed, NO-STUBS), not by
the hook.

When work is coordinated through Linear or another tracker, record the external
work item with optional `Work-*` trailers above the
`Generated-by`/`Signed-off-by` pair. Git remains the source of truth; the tracker
is a queue, a private coordination layer, and — with the `public-collab`
visibility — a public-interfacing notebook for collaborating with outside
maintainers, distinct from the private lab notebook that holds the full
reasoning. The work-tracker extension (v1.3), including the `public-collab`
visibility, the `Work-Project`/`Work-Milestone` trailers, the program→Linear
mapping, the declassification workflow, labels, states, and issue templates, is
documented in
[`docs/macp-work-tracker-extension.md`](docs/macp-work-tracker-extension.md).

## File Structure

```
agents/
├── README.md                    # User-facing documentation
├── CLAUDE.md                    # This file (AI guidance)
├── GEMENI.md -> CLAUDE.md       # Symlink for Gemini
├── CURSOR.md -> CLAUDE.md       # Symlink for Cursor
├── AGENTS.md -> CLAUDE.md       # Symlink for generic AI tools
├── GETTING-STARTED.md           # 5-minute quick start guide
├── bin/
│   ├── commit-msg-hook          # Git hook enforcing MACP format
│   └── ai-session               # Session management tool
├── templates/
│   ├── project-template/        # Copy to new projects
│   │   └── .ai-traces/          # AI collaboration tracking
│   └── thought-trace-template.md # Decision documentation format
└── examples/
    └── foobar-example.md   # Real-world cost savings example
```

## Contributing Guidelines

### When Modifying Templates

**CRITICAL**: Changes to `templates/project-template/` affect all future adopters.

1. **Test First**: Apply changes to a test project
2. **Validate Hook**: Ensure commit-msg-hook still works
3. **Document Changes**: Update README.md if user-facing
4. **Example Impact**: Update examples/ if template format changes

### When Adding Examples

New examples should:
- Show real projects (not synthetic examples)
- Include actual token counts (approximate is fine)
- Demonstrate cost savings with multi-AI routing
- Explain which AI did which tasks and why

### When Updating bin/ Scripts

1. **Backward Compatibility**: Don't break existing users
2. **Error Messages**: Clear, actionable (tell user what to fix)
3. **POSIX Shell**: Use `/bin/bash`, avoid bashisms where possible
4. **Test**: Run on clean project before committing

## AI Task Routing (Meta)

Even this project should use multi-AI collaboration:

**Claude Code**: Architecture decisions, protocol design, complex validation logic
**ChatGPT Codex**: Script implementation, template creation, boilerplate
**Gemini CLI**: Testing, documentation, simple script updates

## File Editing Rules

- **README.md**: Primary user documentation, keep concise
- **GETTING-STARTED.md**: Quick setup only, link to README for details
- **CLAUDE.md**: AI-specific guidance (this file)
- **bin/commit-msg-hook**: Validation logic, must be POSIX-compliant bash
- **templates/**: Reference implementation, users copy these

## Testing Changes

Before committing changes to enforcement tools:

```bash
# Test commit-msg-hook on sample commit
cd /tmp
git init test-macp
cd test-macp
cp ~/devel/agents/bin/commit-msg-hook .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# Try valid commit (should pass)
git commit --allow-empty -m "$(cat <<'EOF'
test: valid MACP commit

AI-Agent: Claude-Code
AI-Session-ID: 2025-10-28-120000-Claude-Code
AI-Task-Type: test
AI-Context-Tokens: ~1000
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: none

Generated-by: Claude AI
Signed-off-by: Test User <test@example.com>
EOF
)"

# Try invalid commit (should fail)
git commit --allow-empty -m "test: invalid commit without metadata"
```

## Documentation Philosophy

**For Users** (README.md, GETTING-STARTED.md):
- Practical examples that work immediately
- Clear benefits (token savings, traceability)
- Minimal theory, maximum practice

**For AIs** (CLAUDE.md - this file):
- Internal structure and design rationale
- Testing procedures before commits
- Task routing recommendations

**For Future Maintainers** (commit messages with thought traces):
- Why decisions were made
- What alternatives were considered
- Real-world usage data

## Common Tasks

### Adding Support for New AI Tool

1. Add to AI capability matrix in README.md
2. Update commit-msg-hook validation (if new AI-Agent value needed)
3. Add example showing that AI's strengths
4. Create symlink: `ln -s CLAUDE.md NEWTOOL.md`

### Updating Session Format

1. Change templates/project-template/.ai-traces/session-map.json
2. Update bin/ai-session script
3. Document in README.md
4. Add migration notes for existing users

### Fixing Hook Validation Bug

1. Edit bin/commit-msg-hook
2. Test with both valid and invalid commits
3. Update tests in this file's "Testing Changes" section
4. Commit with AI-Task-Type: debug

## Questions to Ask When Making Changes

1. **Will this break existing users?** If yes, provide migration path
2. **Is the benefit worth the complexity?** Keep it simple
3. **Can this be tested?** Add test procedure to this file
4. **Is it documented?** Update README.md if user-facing
5. **Does it follow the protocol?** Use MACP commit format

## Origin Context

This template was created on 2025-10-28 after observing that projects document
AI collaboration protocols but never actually enforce them. The goal: make it
impossible to forget by using git hooks and structured tooling.

**Inspired by**: The Rush build system's CLAUDE.md which documented MACP extensively
but didn't use it until enforcement was added.

**Lesson**: Documentation without enforcement is aspirational. Enforcement without
documentation is mysterious. You need both.

---

**Protocol Version**: 1.1
**Last Updated**: 2026-06-02
**Maintainer**: Multi-AI collaboration (practice what we preach)
