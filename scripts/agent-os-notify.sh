#!/bin/sh
# agent-os SessionStart nudge. Run by the plugin hook in every session.
# Silent unless THIS project uses agent-os AND memory has grown past a threshold.
# Then it prints a one-line reminder to run /agent-os:archive.
# Thresholds (all overridable):
#   AGENT_OS_MAX_ACTIVE   default = AGENT_OS_CONTEXT_TOKENS/1000  (full index scan <= ~10% of context, ~100 tok/line)
#   AGENT_OS_CONTEXT_TOKENS default 200000
#   AGENT_OS_COMPACT_NUDGE default = MAX/4

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
idx="$root/.agent-os/prompts/index.jsonl"
[ -f "$idx" ] || exit 0   # not an agent-os project -> stay silent

MAX=${AGENT_OS_MAX_ACTIVE:-$(( ${AGENT_OS_CONTEXT_TOKENS:-200000} / 1000 ))}
[ "$MAX" -lt 50 ] && MAX=50
NUDGE=${AGENT_OS_COMPACT_NUDGE:-$(( MAX / 4 ))}
[ "$NUDGE" -lt 5 ] && NUDGE=5

n=$(wc -l < "$idx" | tr -d ' ')

# cold must match the compactor: finished AND refs:0 AND pin:false AND older than AGE_DAYS.
# (Omitting the age gate here over-counts and nags to compact when nothing is actually cold.)
AGE_DAYS=${AGENT_OS_ARCHIVE_AGE_DAYS:-90}
cutoff=$(date -d "${AGE_DAYS} days ago" +%Y-%m-%d 2>/dev/null \
  || date -v-"${AGE_DAYS}"d +%Y-%m-%d 2>/dev/null \
  || perl -e 'use POSIX; print strftime("%Y-%m-%d", localtime(time-86400*$ARGV[0]))' "$AGE_DAYS" 2>/dev/null \
  || true)
if [ -n "$cutoff" ]; then
  cold=$(awk -v cut="$cutoff" '
    /"status":"(completed|resolved)"/ && /"refs":0/ && /"pin":false/ {
      if (match($0, /"date":"[0-9-]*"/)) {
        d=substr($0, RSTART+8, RLENGTH-9)
        if (d != "" && d < cut) c++
      }
    }
    END { print c+0 }' "$idx" 2>/dev/null)
else
  # no date tool -> fall back to the approximate count (no age gate); never fail a SessionStart hook
  cold=$(grep -E '"status":"(completed|resolved)"' "$idx" 2>/dev/null | grep '"refs":0' | grep '"pin":false' | wc -l | tr -d ' ')
fi
[ -n "$cold" ] || cold=0

if [ "$n" -gt "$MAX" ] || [ "$cold" -ge "$NUDGE" ]; then
  echo "[agent-os] memory is large: $n active index entries, ~$cold finished/unreferenced. Run /agent-os:archive to archive cold docs (preview first)."
fi
exit 0
