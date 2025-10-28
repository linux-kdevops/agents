# Getting Started with Multi-AI Collaboration Protocol (MACP)

## TL;DR: 5-Minute Setup

```bash
# 1. Copy template to your project
cd your-project
cp -r ~/devel/agents/templates/project-template/.ai-traces .
cp ~/devel/agents/bin/commit-msg-hook .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# 2. Start a session
eval "$(~/devel/agents/bin/ai-session start)"

# 3. Work normally, but commit with MACP format
git commit -m "$(cat <<EOF
subject: your change

Description of what and why.

AI-Agent: Claude-Code
AI-Session-ID: $AI_SESSION
AI-Task-Type: implement
AI-Context-Tokens: ~10000
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: none

Generated-by: Claude AI
Signed-off-by: Your Name <email@example.com>
EOF
)"

# Done! The hook will enforce the format.
```

## Why Bother?

**Without MACP** (what happened in Rush):
- Claude Code did Phase 1-3 alone
- ~180K tokens spent
- No thought traces
- Can't understand AI decisions later
- Single point of failure (no AI review)

**With MACP**:
- Right AI for each task → 65% token savings
- Full audit trail of decisions
- AI peer review (multiple perspectives)
- Can visualize collaboration
- Future maintainers understand *why*

## Add MACP to Rush (Example)

Let's add it to the Rush project right now:

```bash
cd ~/devel/foobar

# Install MACP
mkdir -p .ai-traces
cp ~/devel/agents/templates/project-template/.ai-traces/README.md .ai-traces/
cp ~/devel/agents/templates/project-template/.ai-traces/session-map.json .ai-traces/
touch .ai-traces/sessions.log

# Install commit hook
cp ~/devel/agents/bin/commit-msg-hook .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# Add bin to PATH (optional but recommended)
echo 'export PATH="$HOME/devel/agents/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Test it
eval "$(ai-session start --agent Claude-Code --task docs)"
ai-session current

# Now commits MUST include MACP metadata
# The hook will REJECT non-compliant commits
```

## The Enforcement Hook

The commit-msg hook checks:
- ✅ AI-Agent (Claude-Code | ChatGPT-Codex | Gemini-CLI)
- ✅ AI-Session-ID (format: YYYY-MM-DD-HHMMSS-AI-NAME)
- ✅ AI-Task-Type (design | implement | debug | refactor | test | build | docs)
- ✅ AI-Context-Tokens (approximate count)
- ✅ AI-Handoff-From (previous session or "none")
- ✅ AI-Handoff-To (next session or "none")
- ✅ AI-Thought-Trace (path or "none")
- ✅ Generated-by (AI name)
- ✅ Signed-off-by (human name + email)
- ✅ Generated-by and Signed-off-by are consecutive (no blank line)

**If ANY field is missing or invalid, the commit is REJECTED.**

## Real Example: From This Session

This session created the agents/ template. If I were following MACP properly, the commit would be:

```
agents: create MACP enforcement tooling and templates

Created practical template for Multi-AI Collaboration Protocol with
enforcement via git hooks. Includes session tracking, thought trace
templates, and examples showing 65% token cost reduction.

Key components:
- commit-msg-hook: Enforces MACP metadata in commits
- ai-session: Manage AI sessions with logging
- Templates: Copy-paste ready for new projects
- Examples: Rush Phase 2 showing proper usage

This addresses the problem where Rush documented MACP in CLAUDE.md
but never actually used it. Now the protocol is enforceable.

AI-Agent: Claude-Code
AI-Session-ID: 2025-10-28-173000-Claude-Code
AI-Task-Type: implement
AI-Context-Tokens: ~75000
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: .ai-traces/2025-10-28-173000-Claude-Code.md

Generated-by: Claude AI
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
```

## Common Workflows

### Workflow 1: Solo Development (Single AI)

```bash
# Start session
eval "$(ai-session start --agent Claude-Code --task implement)"

# Do work...
# Commit with MACP format
# End session
ai-session end
```

### Workflow 2: Multi-AI Collaboration

```bash
# Claude: Design phase
eval "$(ai-session start --agent Claude-Code --task design)"
# Create thought trace: .ai-traces/$AI_SESSION.md
# Commit with handoff to ChatGPT-Codex
ai-session end

# Switch to ChatGPT Codex: Implementation
eval "$(ai-session start --agent ChatGPT-Codex --task implement)"
# Implement from Claude's spec
# Commit with handoff to Gemini-CLI
ai-session end

# Switch to Gemini: Testing
eval "$(ai-session start --agent Gemini-CLI --task test)"
# Write test scripts
# Commit with handoff to Claude for review
ai-session end

# Claude: Review
eval "$(ai-session start --agent Claude-Code --task refactor)"
# Review and integrate
# Final commit, no more handoffs
ai-session end
```

### Workflow 3: Emergency Fix (Skip Session Tracking)

```bash
# For small fixes, you can skip ai-session
# But still MUST use MACP commit format

git commit -m "$(cat <<EOF
fix: typo in README

AI-Agent: Claude-Code
AI-Session-ID: $(date +%Y-%m-%d-%H%M%S)-Claude-Code
AI-Task-Type: docs
AI-Context-Tokens: ~500
AI-Handoff-From: none
AI-Handoff-To: none
AI-Thought-Trace: none

Generated-by: Claude AI
Signed-off-by: Your Name <email@example.com>
EOF
)"
```

## Visualization

After a few commits with MACP, visualize the collaboration:

```bash
# Generate SVG graph of AI collaboration
ai-viz graph > ai-collab.svg

# Show token usage by AI
ai-viz tokens

# Timeline view
ai-viz timeline
```

## Integration with Other Tools

### Pre-commit Hook (optional)
```bash
# .git/hooks/pre-commit
#!/bin/bash
# Run before commit-msg hook
make fmt
make clippy
```

### CI/CD Integration
```yaml
# .github/workflows/macp-audit.yml
name: MACP Audit
on: [push]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate MACP Compliance
        run: |
          git log --format=%B -1 | grep "AI-Agent:" || exit 1
          git log --format=%B -1 | grep "AI-Session-ID:" || exit 1
```

## FAQ

**Q: Do I need to use multiple AIs?**
A: No, you can use Claude for everything. MACP still gives you traceability and session tracking.

**Q: Can I disable the hook temporarily?**
A: Yes: `git commit --no-verify` skips hooks. But don't abuse it.

**Q: What if I forget the format?**
A: The hook will show you the template when it rejects your commit.

**Q: Can I auto-generate the MACP fields?**
A: Yes, use `ai-session start` and reference `$AI_SESSION` in your commit.

**Q: Is this overkill for small projects?**
A: Maybe. But even small projects grow. Having the history helps future maintainers.

**Q: Can I use this with existing projects?**
A: Yes! Just add `.ai-traces/` and install the hook. Old commits don't need MACP metadata.

## Next Steps

1. ✅ Copy template to your project
2. ✅ Install commit hook
3. ✅ Make one commit with MACP format
4. ✅ Add PATH to ~/.bashrc for easy access to tools
5. ✅ Read `examples/foobar-example.md` to see savings

## Getting Help

- Read: `~/devel/agents/README.md` (full documentation)
- Examples: `~/devel/agents/examples/`
- Templates: `~/devel/agents/templates/`

## Origin

Created 2025-10-28 during Rush Phase 3 development after realizing we documented MACP but never actually used it.

**Learn from our mistakes. Use the protocol.**
