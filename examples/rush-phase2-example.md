# Example: Rush Phase 2 - How It SHOULD Have Been Done

This example shows how the Rush Phase 2 implementation (GlobalMemoryBudget) should have used MACP to reduce token costs by 65%.

## Actual (What Happened)

**Single AI Session**: Claude Code did everything
- Design architecture (30K tokens)
- Implement GlobalMemoryBudget (50K tokens)
- Integrate with BzlLoader (30K tokens)
- Wire through BuildOrchestrator (40K tokens)
- Debug borrow checker errors (25K tokens)
- Format and commit (5K tokens)

**Total Tokens**: ~180K
**Cost**: High (all on expensive Sonnet 4.5)
**Time**: 2-3 hours

## Better (With MACP)

### Session 1: Claude Code - Design (30K tokens)

```bash
eval "$(ai-session start --agent Claude-Code --task design)"

# Work on design...
# Create .ai-traces/2025-10-28-140000-Claude-Code.md

git commit -m "$(cat <<EOF
foobar: design Phase 2 GlobalMemoryBudget architecture

Designed atomic memory reservation system to prevent race conditions.
Key insight: Use compare-and-swap for lock-free reservations.

AI-Agent: Claude-Code
AI-Session-ID: 2025-10-28-140000-Claude-Code
AI-Task-Type: design
AI-Context-Tokens: ~30000
AI-Handoff-From: none
AI-Handoff-To: 2025-10-28-143000-ChatGPT-Codex
AI-Thought-Trace: .ai-traces/2025-10-28-140000-Claude-Code.md

Generated-by: Claude AI
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
EOF
)"

ai-session end
```

### Session 2: ChatGPT Codex - Implementation (15K tokens)

```bash
eval "$(ai-session start --agent ChatGPT-Codex --task implement)"

# Read handoff from Claude
# Implement GlobalMemoryBudget from spec
# Much cheaper AI for straightforward implementation

git commit -m "$(cat <<EOF
foobar: implement GlobalMemoryBudget with CAS

Implemented atomic memory reservation system per Claude's design.
Used compare-and-swap for lock-free thread-safe reservations.

AI-Agent: ChatGPT-Codex
AI-Session-ID: 2025-10-28-143000-ChatGPT-Codex
AI-Task-Type: implement
AI-Context-Tokens: ~15000
AI-Handoff-From: 2025-10-28-140000-Claude-Code
AI-Handoff-To: 2025-10-28-145000-Gemini-CLI
AI-Thought-Trace: none

Generated-by: ChatGPT
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
EOF
)"

ai-session end
```

### Session 3: Gemini CLI - Integration Scripts (5K tokens)

```bash
eval "$(ai-session start --agent Gemini-CLI --task implement)"

# Wire GlobalMemoryBudget through all BzlLoader creation points
# Simple find-and-replace work, perfect for Gemini

git commit -m "$(cat <<EOF
foobar: wire GlobalMemoryBudget through all loader instances

Updated all 5 locations where BzlLoader is created to pass memory budget.

AI-Agent: Gemini-CLI
AI-Session-ID: 2025-10-28-145000-Gemini-CLI
AI-Task-Type: implement
AI-Context-Tokens: ~5000
AI-Handoff-From: 2025-10-28-143000-ChatGPT-Codex
AI-Handoff-To: 2025-10-28-150000-Claude-Code
AI-Thought-Trace: none

Generated-by: Gemini
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
EOF
)"

ai-session end
```

### Session 4: Claude Code - Debug & Review (20K tokens)

```bash
eval "$(ai-session start --agent Claude-Code --task debug)"

# Fix borrow checker issues (needs Claude's reasoning)
# Review overall integration
# Ensure everything works together

git commit -m "$(cat <<EOF
foobar: fix borrow checker errors in memory guard integration

Fixed lifetime issues by cloning Arc instead of borrowing.
Added MemGuard enum to wrap both guard types for RAII cleanup.

AI-Agent: Claude-Code
AI-Session-ID: 2025-10-28-150000-Claude-Code
AI-Task-Type: debug
AI-Context-Tokens: ~20000
AI-Handoff-From: 2025-10-28-145000-Gemini-CLI
AI-Handoff-To: none
AI-Thought-Trace: .ai-traces/2025-10-28-150000-Claude-Code.md

Generated-by: Claude AI
Signed-off-by: Luis Chamberlain <mcgrof@kernel.org>
EOF
)"

ai-session end
```

## Comparison

| Approach | Tokens Used | Relative Cost | Time |
|----------|-------------|---------------|------|
| **Actual** (Claude only) | 180K | 100% | 2-3 hours |
| **MACP** (Multi-AI) | 70K | 39% | 2-3 hours |

**Savings**: 110K tokens (~61% reduction)
**Cost Reduction**: ~61% ($$$)
**Quality**: Same or better (multiple AI review)

## Key Insights

1. **Design needs Claude** - Complex reasoning, architectural decisions
2. **Implementation works with Codex** - Clear spec → straightforward code
3. **Integration uses Gemini** - Simple find-and-replace, wiring
4. **Debugging needs Claude** - Borrow checker requires reasoning

## Traceability Gained

With MACP, you get:
- 4 separate commits (atomic changes)
- 2 thought traces (complex decisions documented)
- Full collaboration graph (who did what)
- Token accounting (cost visibility)
- Handoff docs (context preserved)

Without MACP (what happened):
- 1 large commit (Phase 2 blob)
- No thought traces (reasoning lost)
- Single AI (no peer review)
- Unknown tokens (can't optimize)
- No handoffs (monolithic work)

## Lesson Learned

**Use the right tool for each job.** Claude for thinking, Codex for coding, Gemini for scripting.

Don't use a Ferrari (Claude) for grocery runs (simple coding tasks).
