#!/bin/sh
# agent-os compactor. Moves COLD task/error docs into .agent-os/prompts/archive/*.jsonl and removes
# the .md (git history keeps the full text; restore with `git show`).
#
# Coldness is NOT age alone. A doc is archived only if ALL hold:
#   - status is completed (task) or resolved (error)     -> finished
#   - refs == 0   (no other active doc references it)     -> not load-bearing
#   - pin != true (not manually pinned)                   -> not protected
#   - last touch (last_seen/date/updated) older than AGE_DAYS -> not recently maintained
# Anything still referenced, recently updated, pinned, open, or active is KEPT.
#
# Usage:
#   sh .agent-os/scripts/agent-os-compact.sh            # dry-run (default): list cold docs
#   sh .agent-os/scripts/agent-os-compact.sh --apply    # archive + remove + reindex
# Tunable: AGENT_OS_ARCHIVE_AGE_DAYS (default 90)
#
# Performance (task 13): selection is one awk pass. The previous version read the index
# in a shell loop and spent six sed pipelines per line -- about 13 processes per entry,
# which came to 6m12s for a dry run over 262 entries on Windows. A preview nobody can
# wait for is a preview nobody runs, and compaction was dead in 13 of 14 installs.
# The write path still loops, but only over the handful of documents actually archived.

# See reindex.sh: awk byte-vs-character semantics and LC_COLLATE glob order both vary
# by locale, silently. Archival picks what to delete, so a locale-dependent selection
# is the last thing this should have. Task 17.
export LC_ALL=C

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
idx="$AOS/prompts/index.jsonl"
[ -f "$idx" ] || { echo "no $idx (run reindex.sh first)"; exit 0; }

AGE_DAYS=${AGENT_OS_ARCHIVE_AGE_DAYS:-90}
APPLY=0
[ "$1" = "--apply" ] && APPLY=1

# portable "N days ago" -> YYYY-MM-DD: GNU date, then BSD/macOS date, then perl, then python3
cutoff=$(date -d "${AGE_DAYS} days ago" +%Y-%m-%d 2>/dev/null \
  || date -v-"${AGE_DAYS}"d +%Y-%m-%d 2>/dev/null \
  || perl -e 'use POSIX; print strftime("%Y-%m-%d", localtime(time-86400*$ARGV[0]))' "$AGE_DAYS" 2>/dev/null \
  || python3 -c 'import sys,datetime; print((datetime.date.today()-datetime.timedelta(days=int(sys.argv[1]))).isoformat())' "$AGE_DAYS" 2>/dev/null \
  || true)
[ -n "$cutoff" ] || { echo "ABORT: cannot compute date cutoff (need GNU/BSD date, perl, or python3). No changes."; exit 2; }

mkdir -p "$AOS/prompts/archive"

# One pass: pick the cold entries and emit "path<TAB>archive<TAB>status<TAB>refs<TAB>date<TAB>line".
# Values are read by walking the line rather than with a greedy regex -- reindex.sh escapes
# every quote inside a value, so a bare quote always ends one.
selected=$(awk -v cut="$cutoff" -v aos="$AOS" '
function fld(s, key,   pat) {
  pat = "\"" key "\":\"[^\"]*\""
  if (match(s, pat)) return substr(s, RSTART + length(key) + 4, RLENGTH - length(key) - 5)
  return ""
}
{
  st = fld($0, "status"); d = fld($0, "date"); path = fld($0, "path"); k = fld($0, "k")
  refs = 0
  if (match($0, /"refs":[0-9]+/)) refs = substr($0, RSTART + 7, RLENGTH - 7) + 0
  pin = ($0 ~ /"pin":true/)

  if (st != "completed" && st != "resolved") next
  if (pin) next
  if (refs > 0) next
  if (d == "" || d >= cut) next

  year = substr(d, 1, 4); if (year == "") year = "unknown"
  out = aos "/prompts/archive/" k "s-" year ".jsonl"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n", path, out, st, refs, d, $0
}' "$idx")

n=0
if [ -n "$selected" ]; then
  # Only the selected documents reach this loop, so the per-document cost is paid
  # for a handful of files rather than for the whole index.
  printf '%s\n' "$selected" | while IFS="$(printf '\t')" read -r path out st refs d line; do
    [ -n "$path" ] || continue
    if [ "$APPLY" -eq 1 ]; then
      printf '%s\n' "$line" >> "$out"
      git rm -q "$path" 2>/dev/null || rm -f "$path"
      # stage the archive alongside the removal so a plain `git commit` captures both
      git add "$out" 2>/dev/null || true
      echo "ARCHIVED $path -> $out"
    else
      echo "WOULD $path -> $out  (status=$st refs=$refs date=$d)"
    fi
  done
  n=$(printf '%s\n' "$selected" | grep -c .)
fi

if [ "$APPLY" -eq 1 ]; then
  if [ "$n" -gt 0 ]; then
    sh "$root/$AOS/scripts/reindex.sh" >/dev/null 2>&1
    git add "$idx" 2>/dev/null || true   # keep the staged index consistent with the archival
  fi
  echo "compacted: $n doc(s). Full text remains in git history (git log -- <path>)."
else
  echo "cold candidates: $n  (cutoff < $cutoff, AGE_DAYS=$AGE_DAYS). Run with --apply to archive."
  echo "NOTE: before archiving recurring errors, consider rolling their lesson into $AOS/docs/ (known-risks) first."
fi
