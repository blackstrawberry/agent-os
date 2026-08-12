#!/bin/sh
# agent-os health check. Reports index size and cold-doc count, and warns when compaction is due.
# Thresholds (all overridable):
#   AGENT_OS_MAX_ACTIVE   default = AGENT_OS_CONTEXT_TOKENS/1000  (keep a full index scan <= ~10% of context, ~100 tok/line)
#   AGENT_OS_CONTEXT_TOKENS default 200000
#   AGENT_OS_COMPACT_NUDGE default = MAX/4  (batch worth a compaction pass)

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
idx="$AOS/prompts/index.jsonl"

MAX=${AGENT_OS_MAX_ACTIVE:-$(( ${AGENT_OS_CONTEXT_TOKENS:-200000} / 1000 ))}
[ "$MAX" -lt 50 ] && MAX=50
NUDGE=${AGENT_OS_COMPACT_NUDGE:-$(( MAX / 4 ))}
[ "$NUDGE" -lt 5 ] && NUDGE=5

[ -f "$idx" ] || { echo "[health] no index (run: sh $AOS/scripts/reindex.sh)"; exit 0; }
n=$(wc -l < "$idx" | tr -d ' ')
cold=$(sh "$root/$AOS/scripts/agent-os-compact.sh" 2>/dev/null | grep -c '^WOULD')

echo "[health] active index: $n entries (max $MAX, nudge $NUDGE) | cold candidates: $cold"
due=0
[ "$n" -gt "$MAX" ]     && { echo "[health][warn] active index over $MAX -- compaction recommended."; due=1; }
[ "$cold" -ge "$NUDGE" ] && { echo "[health][warn] $cold cold doc(s) (>= nudge $NUDGE) -- preview: sh $AOS/scripts/agent-os-compact.sh"; due=1; }
[ "$due" -eq 0 ] && echo "[health] ok -- no compaction needed."
exit 0
