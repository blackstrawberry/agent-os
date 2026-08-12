#!/bin/sh
# agent-os compactor. Moves COLD task/error docs into .agent-os/prompts/archive/*.jsonl and removes
# the .md (git history keeps the full text; restore with `git show`).
#
# Coldness is NOT age alone. A doc is archived only if ALL hold:
#   - status is completed (task) or resolved (error)     -> finished
#   - refs == 0   (no other active doc references it)     -> not load-bearing
#   - pin != true (not manually pinned)                   -> not protected
#   - last touch (updated/date) older than AGE_DAYS       -> not recently maintained
# Anything still referenced, recently updated, pinned, open, or active is KEPT.
#
# Usage:
#   sh .agent-os/scripts/agent-os-compact.sh            # dry-run (default): list cold docs
#   sh .agent-os/scripts/agent-os-compact.sh --apply    # archive + remove + reindex
# Tunable: AGENT_OS_ARCHIVE_AGE_DAYS (default 90)

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

field() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\\([^\"]*\\)\".*/\\1/p"; }
fnum()  { printf '%s' "$1" | sed -n "s/.*\"$2\":\\([0-9][0-9]*\\).*/\\1/p"; }
fbool() { printf '%s' "$1" | sed -n "s/.*\"$2\":\\(true\\|false\\).*/\\1/p"; }

mkdir -p "$AOS/prompts/archive"
n=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  k=$(field "$line" k); status=$(field "$line" status); d=$(field "$line" date)
  path=$(field "$line" path); refs=$(fnum "$line" refs); pin=$(fbool "$line" pin)
  [ -n "$refs" ] || refs=0
  case "$status" in completed|resolved) ;; *) continue ;; esac
  [ "$pin" = "true" ] && continue
  [ "$refs" -gt 0 ] && continue
  [ -n "$d" ] || continue
  # POSIX-safe string compare (test's \< is a bash/ksh extension); awk compare is portable
  awk -v a="$d" -v b="$cutoff" 'BEGIN{exit !(a<b)}' || continue   # not old enough -> keep
  # -> COLD
  year=$(printf '%s' "$d" | cut -c1-4); [ -n "$year" ] || year=unknown
  out="$AOS/prompts/archive/${k}s-${year}.jsonl"
  if [ "$APPLY" -eq 1 ]; then
    printf '%s\n' "$line" >> "$out"
    git rm -q "$path" 2>/dev/null || rm -f "$path"
    # stage the archive alongside the removal so a plain `git commit` captures both
    git add "$out" 2>/dev/null || true
    echo "ARCHIVED $path -> $out"
  else
    echo "WOULD $path -> $out  (status=$status refs=$refs date=$d)"
  fi
  n=$((n+1))
done < "$idx"

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
