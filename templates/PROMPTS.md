<!-- Template: MACP prompt-ledger index. Copy to your project root as PROMPTS.md. -->
# PROMPTS.md — prompt ledger index

Append-only index of the hash-chained prompt ledger. Immutable entries live
under `.ai-prompts/`; the verbatim original prompt is in `PROMPT.md`. Verified
by `bin/prompt-ledger-verify.py` (fail closed). See
`docs/macp-prompt-ledger-extension.md`.

## Entries

| prompt_id | entry | prompt_sha256 | prev_entry_sha256 | declassification |
|-----------|-------|---------------|-------------------|------------------|
| <id>      | <file>| <hash…>       | none              | public           |

## Machine-readable ledger

Columns: prompt_id  entry_file  prompt_sha256  prev_entry_sha256  declassification  git_commit

```ledger
<prompt_id> <entry_file> <prompt_sha256> none <declassification> pending
```

`git_commit` is `pending` until the introducing commit is made; the binding is
recorded here (the mutable index), never by rewriting the immutable entries.
