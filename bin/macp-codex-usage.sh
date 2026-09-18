#!/usr/bin/env bash
# Extract and verify immutable Codex rollout usage receipts for MACP.
# Raw token_count values are cumulative for a thread. New receipts record the
# exact delta from a pinned preceding token_count event plus the raw total.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: macp-codex-usage.sh <thread-id> [--human|--trailers|--commit-trailers|--json]
       macp-codex-usage.sh <thread-id> --verify <receipt> <model> <usage> <total> [<thread-usage> <baseline-receipt>]
EOF
    exit 2
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

THREAD_ID="${1:-}"
FORMAT="${2:---human}"
[[ "$THREAD_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || usage
command -v jq >/dev/null 2>&1 || die 'jq is required but not found on PATH'

CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
SESSIONS_DIR="$CODEX_ROOT/sessions"
mapfile -t MATCHES < <(find "$SESSIONS_DIR" -type f \
    -name "rollout-*-${THREAD_ID}.jsonl" -print 2>/dev/null)
[[ ${#MATCHES[@]} -eq 1 ]] || die "expected one rollout for thread ${THREAD_ID}, found ${#MATCHES[@]}"
ROLLOUT="${MATCHES[0]}"
RECEIPT_REL="${ROLLOUT#"$SESSIONS_DIR"/}"
[[ "$RECEIPT_REL" != "$ROLLOUT" && "$RECEIPT_REL" != *..* ]] || die 'invalid receipt path'

CLI_VERSION="$(jq -r 'select(.type == "session_meta") | .payload.cli_version // empty' \
    "$ROLLOUT" | head -1)"
REQUESTED_ORDINAL=""
RECEIPT_PREFIX="codex-rollout:${RECEIPT_REL}#ordinal="
if [[ "$FORMAT" == "--verify" ]]; then
    [[ ( $# -eq 6 || $# -eq 8 ) && "$3" == "$RECEIPT_PREFIX"* ]] || usage
    REQUESTED_ORDINAL="${3#"$RECEIPT_PREFIX"}"
    [[ "$REQUESTED_ORDINAL" =~ ^[0-9]+$ ]] || die 'receipt has no valid event ordinal'
fi
if [[ -n "$REQUESTED_ORDINAL" ]]; then
    TOKEN_EVENT="$(jq -c --argjson ordinal "$REQUESTED_ORDINAL" '
        select(.ordinal == $ordinal and .type == "event_msg" and
        .payload.type == "token_count" and .payload.info.total_token_usage != null)' \
        "$ROLLOUT")"
else
    TOKEN_EVENT="$(jq -cs '[.[] | select(.type == "event_msg" and
        .payload.type == "token_count" and .payload.info.total_token_usage != null)] |
        last // empty' "$ROLLOUT")"
fi
[[ -n "$CLI_VERSION" ]] || die "no cli_version in rollout for thread ${THREAD_ID}"
[[ -n "$TOKEN_EVENT" ]] || die "no token_count receipt in rollout for thread ${THREAD_ID}"

ORDINAL="$(jq -er '.ordinal | select(type == "number" and . >= 0)' <<<"$TOKEN_EVENT")"
EVENT_TIMESTAMP="$(jq -er '.timestamp | select(type == "string" and length > 0)' <<<"$TOKEN_EVENT")"
MODEL="$(jq -r --argjson ordinal "$ORDINAL" 'select((.ordinal // -1) <= $ordinal) |
    .payload.model // empty' "$ROLLOUT" | sed '/^$/d' | tail -1)"
[[ -n "$MODEL" ]] || die "no model field before receipt event for thread ${THREAD_ID}"
read -r IN CACHED OUT REASON TOTAL < <(jq -r '
    .payload.info.total_token_usage |
    [(.input_tokens // 0), (.cached_input_tokens // 0), (.output_tokens // 0),
     (.reasoning_output_tokens // 0), (.total_tokens // 0)] | @tsv' <<<"$TOKEN_EVENT")
for value in "$IN" "$CACHED" "$OUT" "$REASON" "$TOTAL"; do
    [[ "$value" =~ ^[0-9]+$ ]] || die 'rollout usage contains a non-integer field'
done

PREVIOUS_TOKEN_EVENT="$(jq -cs --argjson ordinal "$ORDINAL" '
    [.[] | select((.ordinal // -1) < $ordinal and .type == "event_msg" and
    .payload.type == "token_count" and .payload.info.total_token_usage != null)] |
    max_by(.ordinal) // empty' "$ROLLOUT")"
if [[ -n "$PREVIOUS_TOKEN_EVENT" ]]; then
    PREVIOUS_ORDINAL="$(jq -er '.ordinal | select(type == "number" and . >= 0)' \
        <<<"$PREVIOUS_TOKEN_EVENT")"
    read -r PREVIOUS_IN PREVIOUS_CACHED PREVIOUS_OUT PREVIOUS_REASON PREVIOUS_TOTAL < <(jq -r '
        .payload.info.total_token_usage |
        [(.input_tokens // 0), (.cached_input_tokens // 0), (.output_tokens // 0),
         (.reasoning_output_tokens // 0), (.total_tokens // 0)] | @tsv' \
        <<<"$PREVIOUS_TOKEN_EVENT")
else
    PREVIOUS_ORDINAL=0
    PREVIOUS_IN=0
    PREVIOUS_CACHED=0
    PREVIOUS_OUT=0
    PREVIOUS_REASON=0
    PREVIOUS_TOTAL=0
fi
for value in "$PREVIOUS_IN" "$PREVIOUS_CACHED" "$PREVIOUS_OUT" \
    "$PREVIOUS_REASON" "$PREVIOUS_TOTAL"; do
    [[ "$value" =~ ^[0-9]+$ ]] || die 'baseline rollout usage contains a non-integer field'
done

DELTA_IN=$((IN - PREVIOUS_IN))
DELTA_CACHED=$((CACHED - PREVIOUS_CACHED))
DELTA_OUT=$((OUT - PREVIOUS_OUT))
DELTA_REASON=$((REASON - PREVIOUS_REASON))
DELTA_TOTAL=$((TOTAL - PREVIOUS_TOTAL))
for value in "$DELTA_IN" "$DELTA_CACHED" "$DELTA_OUT" "$DELTA_REASON" "$DELTA_TOTAL"; do
    (( value >= 0 )) || die 'rollout usage decreased between adjacent token_count events'
done

RECEIPT="codex-rollout:${RECEIPT_REL}#ordinal=${ORDINAL}"
if [[ "$PREVIOUS_ORDINAL" -eq 0 ]]; then
    BASELINE_RECEIPT='none'
else
    BASELINE_RECEIPT="codex-rollout:${RECEIPT_REL}#ordinal=${PREVIOUS_ORDINAL}"
fi
MODEL_TRAILER="${MODEL} (codex-cli ${CLI_VERSION})"
USAGE_TRAILER="input=${DELTA_IN} cached_input=${DELTA_CACHED} output=${DELTA_OUT} reasoning_output=${DELTA_REASON} total=${DELTA_TOTAL}"
THREAD_USAGE_TRAILER="input=${IN} cached_input=${CACHED} output=${OUT} reasoning_output=${REASON} total=${TOTAL}"

case "$FORMAT" in
    --verify)
        [[ $# -eq 6 || $# -eq 8 ]] || usage
        [[ "$3" == "$RECEIPT" ]] || die 'receipt does not name this exact rollout event'
        [[ "$4" == "$MODEL_TRAILER" ]] || die 'MCP-Model does not match rollout'
        if [[ $# -eq 6 ]]; then
            LEGACY_USAGE="input=${IN} cached_input=${CACHED} output=${OUT} reasoning_output=${REASON} total=${TOTAL}"
            [[ "$5" == "$LEGACY_USAGE" ]] || die 'legacy MCP-Token-Usage does not match rollout'
            [[ "$6" == "$TOTAL" ]] || die 'legacy AI-Context-Tokens does not match rollout total'
        else
            [[ "$5" == "$USAGE_TRAILER" ]] || die 'delta MCP-Token-Usage does not match rollout'
            [[ "$6" == "$DELTA_TOTAL" ]] || die 'AI-Context-Tokens does not match rollout delta'
            [[ "$7" == "$THREAD_USAGE_TRAILER" ]] || die 'MCP-Thread-Token-Usage does not match rollout'
            [[ "$8" == "$BASELINE_RECEIPT" ]] || die 'MCP-Usage-Baseline does not match rollout'
        fi
        ;;
    --commit-trailers)
        printf 'AI-Context-Tokens: %s\n' "$DELTA_TOTAL"
        ;&
    --trailers)
        printf 'MCP-Server: codex\n'
        printf 'MCP-Model: %s\n' "$MODEL_TRAILER"
        printf 'MCP-Session-ID: %s\n' "$THREAD_ID"
        printf 'MCP-Usage-Baseline: %s\n' "$BASELINE_RECEIPT"
        printf 'MCP-Usage-Receipt: %s\n' "$RECEIPT"
        printf 'MCP-Token-Usage: %s\n' "$USAGE_TRAILER"
        printf 'MCP-Thread-Token-Usage: %s\n' "$THREAD_USAGE_TRAILER"
        ;;
    --json)
        jq -nc --arg model "$MODEL" --arg cli_version "$CLI_VERSION" \
            --arg thread "$THREAD_ID" --arg receipt "$RECEIPT_REL" \
            --arg timestamp "$EVENT_TIMESTAMP" --argjson ordinal "$ORDINAL" \
            --arg baseline "$BASELINE_RECEIPT" --argjson previous_ordinal "$PREVIOUS_ORDINAL" \
            --argjson input "$DELTA_IN" --argjson cached_input "$DELTA_CACHED" \
            --argjson output "$DELTA_OUT" --argjson reasoning_output "$DELTA_REASON" \
            --argjson total "$DELTA_TOTAL" --argjson thread_input "$IN" \
            --argjson thread_cached_input "$CACHED" --argjson thread_output "$OUT" \
            --argjson thread_reasoning_output "$REASON" --argjson thread_total "$TOTAL" \
            '{server:"codex", model:$model, cli_version:$cli_version,
              thread:$thread, receipt:$receipt, event_ordinal:$ordinal,
              event_timestamp:$timestamp, baseline_receipt:$baseline,
              baseline_ordinal:$previous_ordinal, usage_scope:"token_count_delta",
              token_usage:{input:$input, cached_input:$cached_input,
              output:$output, reasoning_output:$reasoning_output, total:$total},
              thread_token_usage:{input:$thread_input,
              cached_input:$thread_cached_input, output:$thread_output,
              reasoning_output:$thread_reasoning_output, total:$thread_total}}'
        ;;
    --human)
        printf 'codex thread : %s\n' "$THREAD_ID"
        printf 'model        : %s\n' "$MODEL_TRAILER"
        printf 'receipt      : %s\n' "$RECEIPT"
        printf 'event time   : %s\n' "$EVENT_TIMESTAMP"
        printf 'baseline     : %s\n' "$BASELINE_RECEIPT"
        printf 'token delta  : %s\n' "$USAGE_TRAILER"
        printf 'thread total : %s\n' "$THREAD_USAGE_TRAILER"
        ;;
    *) usage ;;
esac
