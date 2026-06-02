# Multi-AI Collaboration Protocol (MACP) - Template & Tooling

**Version**: 1.0
**Date**: 2025-10-28
**Origin**: Goal to get different AIs to collaborate

This project was created to evaluate if different generative AI shell
coding agents could be used to collaborate on a meaningful impactful
open source project, and defining a protocol for that goal.

## What This Is

A practical framework for multiple AI assistants (Claude, ChatGPT, Gemini) to
collaborate efficiently on software projects while minimizing token costs and
maintaining full traceability.

## Why You Need This

You can use this if you want to leverage different AI console tools
to collaborate on an open source project.

### What This Template Provides

1. **Enforceable Protocol**: Pre-commit hooks that REJECT commits without AI metadata
2. **Session Tracking**: Automatic AI session logging
3. **Thought Traces**: Structured decision documentation
4. **Token Accounting**: Track costs per AI, per task
5. **Handoff System**: Explicit AI-to-AI task delegation
6. **Visualization**: See the AI collaboration graph

## Quick Start

### 1. Copy Template to Your Project

```bash
# From your project root
cp -r ~/devel/agents/templates/project-template/.ai-traces .
cp ~/devel/agents/bin/commit-msg-hook .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# Add to .gitignore (optional - sessions.log can get large)
echo ".ai-traces/sessions.log" >> .gitignore
```

**Recommended**: Create AI guidance symlinks (all tools see same instructions):

```bash
# Create CLAUDE.md with your project's AI guidance
# Then create symlinks for other AI tools
ln -s CLAUDE.md GEMENI.md
ln -s CLAUDE.md CURSOR.md
ln -s CLAUDE.md AGENTS.md

# Now all AI tools (Claude, Gemini, Cursor, etc.) read the same guidance
# This ensures consistent behavior regardless of which AI you use
```

### 2. Initialize AI Session

```bash
# Start working session (generates session ID)
export AI_SESSION=$(date +%Y-%m-%d-%H%M%S)-Claude-Code
export AI_AGENT="Claude-Code"
export AI_TASK_TYPE="implement"  # design|implement|debug|refactor|test|build|docs

# Log session start
~/devel/agents/bin/ai-session start
```

### 3. Work Normally, But...

**CRITICAL**: When committing, use the MACP commit format:

```bash
git commit -m "$(cat <<EOF
your: commit subject line (max 50 chars)

Detailed description of what changed and why.

AI-Agent: Claude-Code
AI-Session-ID: $AI_SESSION
AI-Task-Type: implement
AI-Context-Tokens: ~45000
AI-Handoff-To: none
AI-Thought-Trace: .ai-traces/$AI_SESSION.md

Generated-by: Claude AI
Signed-off-by: Your Name <email@example.com>
EOF
)"
```

**The commit hook will REJECT your commit if it's missing AI metadata.**

### 4. Create Thought Traces for Complex Decisions

```bash
# Create trace file
~/devel/agents/bin/ai-trace create "Implement memory guards"

# Edit .ai-traces/$AI_SESSION.md with your reasoning
```

### 5. Hand Off to Another AI

```bash
# Create handoff document
~/devel/agents/bin/ai-handoff create Gemini-CLI "Implement build script"

# This creates .ai-traces/$AI_SESSION-handoff.md
# Include AI-Handoff-To: <next-session-id> in your commit
```

### 6. Visualize Collaboration

```bash
# Generate collaboration graph
~/devel/agents/bin/ai-viz graph > ai-collab.svg
~/devel/agents/bin/ai-viz tokens  # Show token usage by AI
~/devel/agents/bin/ai-viz timeline  # Timeline view
```

## Directory Structure

```
your-project/
├── .ai-traces/
│   ├── README.md                      # Index of all traces
│   ├── session-map.json               # AI collaboration graph
│   ├── sessions.log                   # Append-only session log
│   ├── 2025-10-28-143000-Claude.md   # Thought trace
│   ├── 2025-10-28-143000-handoff.md  # Handoff doc
│   └── ...
└── .git/hooks/
    └── commit-msg                     # Enforces MACP format
```

## Disk Space Impact

**TL;DR: Negligible (~400KB for 59 AI-assisted commits)**

Real-world data from an active project using MACP:

| Metric | Value |
|--------|-------|
| Total commits | 533 |
| AI-assisted commits (with MACP) | 59 (11%) |
| Thought trace files | 38 markdown files |
| Total `.ai-traces/` size | **400 KB** |
| Source code size | 2.7 MB |
| Percentage of source code | 14.8% |
| Percentage of total repo | 0.002% |

**Breakdown**:
- Largest single trace: 43 KB (complex async parallelism research)
- Average trace file: ~10 KB
- Sessions log: <1 KB
- Session map JSON: <5 KB

**Verdict**: AI collaboration tracking adds virtually zero disk overhead. Even after hundreds
of commits and dozens of thought traces, the entire `.ai-traces/` directory is smaller than
many individual source files.

The sessions.log is append-only but remains tiny (<1 KB) even after multiple collaboration
sessions. This is sustainable for years of development without cleanup.

## AI Capability Matrix

**Use the RIGHT tool for the job to minimize token costs.**

| AI | Strengths | Token Cost | Best For |
|----|-----------|------------|----------|
| **Claude Code (Sonnet 4.5)** | Complex reasoning, architecture, debugging | High | <20% of tasks (complex only) |
| **ChatGPT Codex** | Code generation, boilerplate, patterns | Medium | ~50% of tasks (implementation) |
| **Gemini CLI** | Fast iteration, CLI scripts, automation | Low | ~30% of tasks (scripts, simple) |

**Task Routing**:
- Architectural Decisions → Claude Code
- Spec Implementation → ChatGPT Codex (if clear) / Claude (if complex)
- Build/CI Scripts → Gemini CLI
- Debugging Complex Issues → Claude Code
- Boilerplate Code → ChatGPT Codex or Gemini CLI
- Documentation → Any AI (prefer Gemini for speed)

## Commit Metadata Format

**MANDATORY** fields (enforced by hook):

```
Subject: one line summary (max 50 chars)

Body: detailed explanation in plain English (NOT shopping lists)

AI-Agent: <Claude-Code|ChatGPT-Codex|Gemini-CLI>
AI-Session-ID: <YYYY-MM-DD-HHMMSS-AI-NAME>
AI-Task-Type: <design|implement|debug|refactor|test|build|docs>
AI-Context-Tokens: <approximate tokens used>
AI-Handoff-From: <previous session ID or "none">
AI-Handoff-To: <next session ID or "none">
AI-Thought-Trace: <path to trace file or "none">

Generated-by: <AI Name>
Signed-off-by: <Human Name> <email>
```

**The hook will FAIL the commit if any required field is missing.**

### Extension: in-band MCP-agent consultation (v1.1)

When the primary assistant consults a second model in-band (e.g. Claude Code
calling Codex over an MCP server), record it with `MCP-*` and `Collab-*`
trailers — with the model and token cost read from the model's usage receipt,
not its self-report. The full scheme (dual-plan generate→grade→merge loop,
fixed rubric, git-derived ledger, fail-closed token capture) is in
[`docs/mcp-agent-extension.md`](docs/mcp-agent-extension.md).

## Thought Trace Format

For complex decisions, create `.ai-traces/<session-id>.md`:

```markdown
# AI Thought Trace: 2025-10-28-143000-Claude-Code

**AI Agent**: Claude Code (Sonnet 4.5)
**Date**: 2025-10-28 14:30:00
**Task**: Implement hermetic build sandbox
**Handoff From**: ChatGPT-Codex (2025-10-28-140815)

## Problem Analysis
<Your reasoning about the problem>

## Considered Approaches
1. **Approach A**: <description> - ❌ Rejected because <reason>
2. **Approach B**: <description> - ✅ **SELECTED** because <reason>
3. **Approach C**: <description> - ❌ Rejected because <reason>

## Implementation Decisions
- **Decision 1**: <what> - **Why**: <reason>
- **Decision 2**: <what> - **Why**: <reason>

## Files Modified
- path/to/file.rs:123-456 - <what changed>
- path/to/other.rs:789 - <what changed>

## Handoff Context
<Information for next AI, if applicable>

## Tokens Used
~45,000 tokens
- Reading: 15K
- Reasoning: 20K
- Generation: 10K
```

## Handoff Protocol

When passing work to another AI:

1. **Create handoff doc**: `.ai-traces/<session-id>-handoff.md`
2. **Include in commit**: Set `AI-Handoff-To: <next-session-id>`
3. **Minimal context**: Only essential state, not full history
4. **Clear task**: Next AI should know exactly what to do

Example handoff doc:

```markdown
# AI Handoff: Claude-Code → Gemini-CLI

**From**: 2025-10-28-143000-Claude-Code
**To**: 2025-10-28-150000-Gemini-CLI
**Task**: Implement build script for sandbox module

## Context
- Sandbox implementation complete in src/sandbox/mod.rs
- Needs build.rs integration for platform-specific compilation
- Dependencies: libc, nix crates

## Required Actions
1. Add build.rs with platform detection
2. Configure conditional compilation flags
3. Add integration test script

## Files to Review
- src/sandbox/mod.rs (lines 1-245)
- Cargo.toml (lines 15-30)

## Estimated Tokens
~5,000 (mostly code generation - good fit for Gemini)
```

## Tooling Reference

### `ai-session` - Session Management

```bash
# Start session
ai-session start [--agent Claude-Code] [--task implement]

# Log event
ai-session log "Starting Phase 2 implementation"

# End session
ai-session end

# Show current session
ai-session current
```

### `ai-trace` - Thought Traces

```bash
# Create new trace
ai-trace create "Implement feature X"

# Validate trace format
ai-trace validate .ai-traces/2025-10-28-143000.md

# List all traces
ai-trace list
```

### `ai-handoff` - Task Delegation

```bash
# Create handoff document
ai-handoff create <next-ai> "<task description>"

# Example
ai-handoff create Gemini-CLI "Write build script for module X"
```

### `ai-viz` - Visualization

```bash
# Generate collaboration graph (SVG)
ai-viz graph > collab.svg

# Show token usage by AI
ai-viz tokens

# Timeline view
ai-viz timeline

# Update session map
ai-viz update-session <session-id>
```

## Integration with Projects

### For New Projects

```bash
# Copy template
cp -r ~/devel/agents/templates/project-template/.ai-traces your-project/
cp ~/devel/agents/templates/project-template/.gitignore your-project/.ai-traces/

# Install commit hook
cp ~/devel/agents/bin/commit-msg-hook your-project/.git/hooks/commit-msg
chmod +x your-project/.git/hooks/commit-msg

# Initialize
cd your-project
~/devel/agents/bin/ai-session start
```

### For Existing Projects

```bash
cd ~/devel/foobar

# Add .ai-traces/ directory
mkdir -p .ai-traces
cp ~/devel/agents/templates/ai-traces-README.md .ai-traces/README.md
touch .ai-traces/session-map.json
echo '{"sessions": [], "total_tokens": 0, "total_commits": 0}' > .ai-traces/session-map.json

# Install hook
cp ~/devel/agents/bin/commit-msg-hook .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# Update CLAUDE.md to reference agents/
echo "See ~/devel/agents/ for MACP tooling and enforcement" >> CLAUDE.md
```

## Enforcement: Why It Matters

### Before (Rush Development)
- ❌ Protocol documented in CLAUDE.md
- ❌ Never actually used
- ❌ No enforcement
- ❌ Single AI did everything
- ❌ High token costs
- ❌ No traceability

### After (With This Template)
- ✅ Pre-commit hook **REJECTS** non-compliant commits
- ✅ AI sessions **logged automatically**
- ✅ Token usage **tracked**
- ✅ Handoffs **documented**
- ✅ Thought traces **required for complex work**
- ✅ Collaboration **visualized**

## Example: Rush Memory Management (How It Should Have Been)

### Session 1: Claude Code (Design)
```bash
AI_SESSION=2025-10-28-140000-Claude-Code
Task: Design memory guard architecture
Tokens: ~30K (research & design)
Result: .ai-traces/2025-10-28-140000-Claude-Code.md (thought trace)
Handoff: ChatGPT-Codex for implementation
```

### Session 2: ChatGPT Codex (Implementation)
```bash
AI_SESSION=2025-10-28-143000-ChatGPT-Codex
Task: Implement GlobalMemoryBudget from spec
Tokens: ~15K (code generation)
Result: crates/foobar-resource/src/memory_budget.rs
Handoff: Gemini-CLI for test scripts
```

### Session 3: Gemini CLI (Testing)
```bash
AI_SESSION=2025-10-28-145000-Gemini-CLI
Task: Write integration tests for memory guards
Tokens: ~5K (simple scripting)
Result: tests/memory_guard_test.sh
Handoff: Claude-Code for review
```

### Session 4: Claude Code (Review & Integration)
```bash
AI_SESSION=2025-10-28-150000-Claude-Code
Task: Review implementation, integrate with BuildOrchestrator
Tokens: ~20K (complex integration)
Result: Phase 2 complete, commit with full metadata
```

**Total Tokens**: 70K (vs 200K if Claude did everything)
**Cost Savings**: 65% reduction
**Traceability**: Full audit trail in `.ai-traces/`

## Contributing

This template is designed to evolve. Improvements welcome:

1. Better visualization tools
2. Automatic token counting integration
3. AI selection suggestions based on task type
4. Cost reporting ($ per AI per project)

## License

MIT - Use freely in your projects

## Origin Story

Created after Rush build system crashed desktop during TensorFlow build. The fix required 3 phases of memory management work (Phase 1-3), all done by Claude Code alone. This was inefficient and expensive. This template ensures future projects use AI collaboration properly.

**Learn from our mistakes. Use the right AI for each task.**
