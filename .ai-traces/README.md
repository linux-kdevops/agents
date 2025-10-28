# AI Collaboration Traces

This directory contains traces of AI-assisted development for this project.

## What's Here

- **sessions.log**: Append-only log of all AI sessions
- **session-map.json**: Graph of AI collaboration (for visualization)
- **YYYY-MM-DD-HHMMSS-AI-NAME.md**: Thought traces for complex decisions
- **YYYY-MM-DD-HHMMSS-handoff.md**: AI-to-AI task handoffs

## Quick Reference

### View Recent Sessions
```bash
tail -50 sessions.log
```

### Find Thought Traces
```bash
ls *.md | grep -v README | grep -v handoff
```

### See AI Collaboration Graph
```bash
~/devel/agents/bin/ai-viz graph > collab.svg
```

## Session Log Format

```
[timestamp] [AI-Agent] [Session-ID] EVENT details
```

Example:
```
[2025-10-28T14:30:00Z] [Claude-Code] [2025-10-28-143000-Claude-Code] START task=implement
[2025-10-28T14:35:00Z] [Claude-Code] [2025-10-28-143000-Claude-Code] LOG Starting Phase 2
[2025-10-28T14:45:00Z] [Claude-Code] [2025-10-28-143000-Claude-Code] COMMIT task=implement tokens=45000
[2025-10-28T15:00:00Z] [Claude-Code] [2025-10-28-143000-Claude-Code] END
```

## Thought Trace Template

See `~/devel/agents/templates/thought-trace-template.md` for the standard format.

## Maintained By

Multi-AI Collaboration Protocol (MACP)
See: ~/devel/agents/README.md
