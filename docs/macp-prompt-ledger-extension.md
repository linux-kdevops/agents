# MACP prompt-ledger extension

MACP currently tracks AI *sessions*, *thought traces*, *token accounting*, and
*handoffs* via `.ai-traces/` and the commit-msg trailers. It does **not** track
the *prompts* that drive those sessions. This extension adds a prompt ledger:
the prompts become first-class, hash-chained project history.

It is backward compatible. Projects that do not adopt it are unaffected; the
extra commit trailers are optional and only validated when present.

## Why

For domains where provenance matters (e.g. standards maintenance, regulated
code), "which exact prompt produced this change?" must be answerable later.
Thought traces capture *reasoning*; the prompt ledger captures the verbatim
*input* and binds it into a tamper-evident chain.

## Artifacts

- `PROMPT.md` — verbatim snapshot of the original prompt.
- `PROMPTS.md` — append-only ledger **index** (human table plus a
  machine-readable ` ```ledger ` block). See `templates/PROMPTS.md`.
- `.ai-prompts/NNNN-slug.md` — immutable entries. Front-matter fields:
  `prompt_id`, `title`, `timestamp` (UTC), `author`/`origin`,
  `macp_session_id`, `parent_prompt_id`, `parent_prompt_sha256`,
  `prompt_sha256`, `prev_entry_sha256`, `git_commit`, `declassification`
  (`public` | `private` | `redacted`), `purpose`, optional `prompt_source`.
  The verbatim prompt is in a fenced ` ```prompt ` block (inline or in the
  referenced `prompt_source` file).

## Canonical hashing

The hashed bytes are the *prompt text*: the lines strictly between the
` ```prompt ` and ` ``` ` fences, joined with `\n`, no trailing newline.

For ordered entries `e[0..n]`:

- `prompt_sha256(e[i]) = sha256(prompt text of e[i])`
- `prev_entry_sha256(e[0]) = none`
- `prev_entry_sha256(e[i]) = prompt_sha256(e[i-1])` for `i > 0`

`git_commit` is **not** hashed (entries are immutable; the commit binding lives
in the mutable `PROMPTS.md` index), so the chain is stable before an entry's
own commit exists.

## Commit trailers (additive)

When a commit changes prompt-ledger entries, it adds, above the existing
`Generated-by`/`Signed-off-by` pair (whose adjacency rule is unchanged):

```
Prompt-Ledger: PROMPTS.md
Prompt-Entry: .ai-prompts/<entry>.md
Prompt-SHA256: <64-hex>
Prompt-Parent-SHA256: <64-hex-or-none>
```

`bin/commit-msg-hook-prompt-ledger` validates these when present (see below).

## Verification (fail closed)

`bin/prompt-ledger-verify.py <repo>` recomputes each `prompt_sha256` from the
prompt text, checks the recorded values, checks each `prev_entry_sha256`
against the previous entry's recomputed hash, and cross-checks the `PROMPTS.md`
index. A missing, malformed, or inconsistent hash — or an empty ledger — is an
error and exits non-zero. The verifier is self-contained (standard library
only) so any project can adopt it regardless of language.

## Adoption

Reference implementation and a worked example live in the KPAX project, which
carries this ledger locally and does not block on upstream adoption. Projects
opt in by adding the artifacts above and wiring
`bin/commit-msg-hook-prompt-ledger` after the base MACP hook.
