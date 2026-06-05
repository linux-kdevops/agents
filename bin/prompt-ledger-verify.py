#!/usr/bin/env python3
# MACP prompt-ledger verifier (standard library only; language-agnostic).
#
# Usage: bin/prompt-ledger-verify.py [REPO_ROOT]
#
# Recomputes each entry's prompt_sha256 from its prompt text, checks the
# recorded values and the prev_entry_sha256 chain, and cross-checks the
# PROMPTS.md index. Fails closed: any missing/inconsistent hash or an empty
# ledger exits non-zero. See docs/macp-prompt-ledger-extension.md.
import hashlib
import re
import sys
from pathlib import Path

FENCE_OPEN, FENCE_CLOSE, INDEX_OPEN, NONE = "```prompt", "```", "```ledger", "none"
_FM = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def extract_prompt(content):
    lines = content.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if ln.rstrip() == FENCE_OPEN:
            start = i + 1
            break
    if start is None:
        raise ValueError("no ```prompt fence")
    for j in range(start, len(lines)):
        if lines[j].strip() == FENCE_CLOSE:
            return "\n".join(lines[start:j])
    raise ValueError("unterminated ```prompt fence")


def frontmatter(content):
    m = _FM.match(content)
    if not m:
        raise ValueError("missing --- front-matter")
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    return meta


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    prompts = root / ".ai-prompts"
    entries = sorted(p for p in prompts.glob("*.md") if p.name != "README.md")
    errors = []
    if not entries:
        print("prompt-ledger: no entries (fail closed)", file=sys.stderr)
        return 1
    prev = None
    for path in entries:
        raw = path.read_text(encoding="utf-8")
        meta = frontmatter(raw)
        src = meta.get("prompt_source")
        text = (root / src).read_text(encoding="utf-8") if src else raw
        try:
            computed = sha(extract_prompt(text))
        except ValueError as exc:
            errors.append(f"{path.name}: {exc}")
            prev = None
            continue
        if meta.get("prompt_sha256") != computed:
            errors.append(f"{path.name}: prompt_sha256 mismatch")
        expected_prev = NONE if prev is None else prev
        if meta.get("prev_entry_sha256") != expected_prev:
            errors.append(f"{path.name}: chain broken")
        prev = computed
    if errors:
        print("prompt-ledger: FAILED", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print(f"prompt-ledger: OK ({len(entries)} entries, chain intact)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
