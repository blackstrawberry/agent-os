#!/bin/sh
# agent-os health check. READ-ONLY: it reports, it never edits or reindexes.
# A SessionStart hook that rewrites files makes session start unpredictable, so the
# only automatic write stays in pre-commit.
#
#   sh .agent-os/scripts/agent-os-health.sh              full report
#   sh .agent-os/scripts/agent-os-health.sh --oneline    one line if anything is pending, else silent
#
# Thresholds (all overridable):
#   AGENT_OS_MAX_ACTIVE       default = AGENT_OS_CONTEXT_TOKENS/1000
#   AGENT_OS_CONTEXT_TOKENS   default 200000
#   AGENT_OS_COMPACT_NUDGE    default = MAX/4
#   AGENT_OS_ARCHIVE_AGE_DAYS default 90    (cold)
#   AGENT_OS_TASK_ROT_DAYS    default 30    (an open task nobody has touched)
#   AGENT_OS_PIN_STALE_DAYS   default 180   (a pin worth re-examining)
#   AGENT_OS_PIN_MAX_PCT      default 30    (pin means load-bearing, not important)
#   AGENT_OS_AREA_RISK_MIN    default 3     (errors in one area before known-risks should cover it)

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
idx="$AOS/prompts/index.jsonl"
risks="$AOS/docs/07_known-risks.md"

ONELINE=0
[ "$1" = "--oneline" ] && ONELINE=1

[ -f "$idx" ] || {
  [ "$ONELINE" -eq 1 ] || echo "[health] no index (run: sh $AOS/scripts/reindex.sh)"
  exit 0
}

MAX=${AGENT_OS_MAX_ACTIVE:-$(( ${AGENT_OS_CONTEXT_TOKENS:-200000} / 1000 ))}
[ "$MAX" -lt 50 ] && MAX=50
NUDGE=${AGENT_OS_COMPACT_NUDGE:-$(( MAX / 4 ))}
[ "$NUDGE" -lt 5 ] && NUDGE=5
PIN_MAX_PCT=${AGENT_OS_PIN_MAX_PCT:-30}
AREA_MIN=${AGENT_OS_AREA_RISK_MIN:-3}

ago() { # days -> YYYY-MM-DD, portable
  date -d "$1 days ago" +%Y-%m-%d 2>/dev/null \
    || date -v-"$1"d +%Y-%m-%d 2>/dev/null \
    || perl -e 'use POSIX; print strftime("%Y-%m-%d", localtime(time-86400*$ARGV[0]))' "$1" 2>/dev/null \
    || python3 -c 'import sys,datetime; print((datetime.date.today()-datetime.timedelta(days=int(sys.argv[1]))).isoformat())' "$1" 2>/dev/null \
    || true
}
COLD_CUT=$(ago "${AGENT_OS_ARCHIVE_AGE_DAYS:-90}")
ROT_CUT=$(ago "${AGENT_OS_TASK_ROT_DAYS:-30}")
PIN_CUT=$(ago "${AGENT_OS_PIN_STALE_DAYS:-180}")

# Documents edited since the index was built. The index is only refreshed on commit,
# so uncommitted work leaves every scan reading a stale catalogue -- and nothing said so.
stale=0
if [ -d "$AOS/prompts" ]; then
  stale=$(find "$AOS/prompts" -name '*.md' -newer "$idx" 2>/dev/null \
          | grep -v '_TEMPLATE\.md' | grep -vc '/manual-')
fi
[ -n "$stale" ] || stale=0

# The eval set is the only instrument that can say whether a rule still earns its
# place. Measured across 19 installs, 17 still hold the shipped file untouched --
# the same failure as known-risks: a slot that looks filled never gets filled.
# Detected by counting written rows, never by looking for template phrases. The first
# attempt matched marker strings like "fictional app" -- which the template's own
# explanation of that history contains, so every file derived from it stayed flagged
# forever no matter how many rows were filled in. A detector coupled to prose in the
# thing it inspects is a detector that lies.
evalfile="$AOS/prompts/eval/eval-set.md"
evalrows=-1
if [ -f "$evalfile" ]; then
  evalrows=$(awk -F'|' '/^\|[ \t]*[0-9]+[ \t]*\|/ { q = $3; gsub(/[ \t]/, "", q); if (q != "") c++ } END { print c+0 }' "$evalfile")
fi

# Injected-text budget. Nothing measured this before, and it only ever grew: one working
# session took the same four files from 9,936 to 20,718 characters, every addition
# individually reasonable. Over budget the rule is REPLACE, not append.
CLAUDE_MAX=${AGENT_OS_CLAUDE_MAX_CHARS:-3000}
SKILL_MAX=${AGENT_OS_SKILL_MAX_CHARS:-2000}
overbudget=""
if [ -f CLAUDE.md ]; then
  csz=$(awk '/<!-- agent-os:begin -->/,/<!-- agent-os:end -->/' CLAUDE.md | wc -m)
  csz=$(printf '%s' "$csz" | tr -d ' ')
  [ "$csz" -gt "$CLAUDE_MAX" ] && overbudget="$overbudget CLAUDE.md agent-os block ${csz}/${CLAUDE_MAX};"
fi
for sk in "$AOS"/skills/*/SKILL.md .claude/skills/*/SKILL.md; do
  [ -e "$sk" ] || continue
  # body only: the frontmatter description is how the skill gets routed, not prose
  bsz=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$sk" | wc -m)
  bsz=$(printf '%s' "$bsz" | tr -d ' ')
  [ "$bsz" -gt "$SKILL_MAX" ] && overbudget="$overbudget $sk body ${bsz}/${SKILL_MAX};"
done

archived=0
if [ -d "$AOS/prompts/archive" ]; then
  archived=$(find "$AOS/prompts/archive" -name '*.jsonl' 2>/dev/null | wc -l)
  archived=$(printf '%s' "$archived" | tr -d ' ')
fi

# One pass over the index for everything else.
REPORT=$(awk -v coldcut="$COLD_CUT" -v rotcut="$ROT_CUT" -v pincut="$PIN_CUT" \
             -v risks="$risks" -v areamin="$AREA_MIN" '
function fld(s, key,   pat) {
  pat = "\"" key "\":\"[^\"]*\""
  if (match(s, pat)) return substr(s, RSTART + length(key) + 4, RLENGTH - length(key) - 5)
  return ""
}
function num(s, key,   pat) {
  pat = "\"" key "\":[0-9]+"
  if (match(s, pat)) return substr(s, RSTART + length(key) + 3, RLENGTH - length(key) - 3) + 0
  return 0
}
BEGIN {
  while ((getline line < risks) > 0) { gsub(/\r/, "", line); body = body tolower(line) "\n" }
  close(risks)
}
{
  n++
  k = fld($0, "k"); st = fld($0, "status"); d = fld($0, "date")
  id = fld($0, "id"); area = fld($0, "area"); path = fld($0, "path")
  refs = num($0, "refs"); rec = num($0, "rec")
  pin = ($0 ~ /"pin":true/)

  if (pin) npin++
  if ((st == "completed" || st == "resolved") && !pin && refs == 0 && d != "" && coldcut != "" && d < coldcut) cold++
  if (pin && refs == 0 && d != "" && pincut != "" && d < pincut) { unpin++; ulist[unpin] = path " (" d ")" }
  # A task is closed if it has been MOVED to completed/, or if its status starts with
  # a closing word. Location is checked first because it is the one signal that does
  # not drift: statuses like "INDEX, split done" or "weekly deployed, gate PASS" are
  # closed in meaning but match no keyword, while an exact planned|in-progress test
  # misses the install that writes in_progress with an underscore.
  # `blocked` is open but deliberately parked, so it is not rot.
  if (k == "task" && path !~ /\/completed\// && st !~ /^(completed|resolved|superseded|discarded)/) {
    open_tasks++
    if (st !~ /^blocked/ && d != "" && rotcut != "" && d < rotcut) { rot++; rlist[rot] = path " (" d ")" }
  }
  if (k == "error") {
    nerr++
    m = split(tolower(area), a, ",")
    for (i = 1; i <= m; i++) { gsub(/^[ \t]+|[ \t]+$/, "", a[i]); if (a[i] != "") acount[a[i]]++ }
    if (rec >= 3 && id != "" && index(body, tolower(id)) == 0) { unprom++; plist[unprom] = id " (recurred " rec ")" }
  }
}
END {
  printf "N %d\nCOLD %d\nPIN %d\nUNPIN %d\nOPEN %d\nROT %d\nERR %d\nUNPROM %d\n", \
         n, cold+0, npin+0, unpin+0, open_tasks+0, rot+0, nerr+0, unprom+0
  for (i = 1; i <= rot; i++)    print "ROTLIST " rlist[i]
  for (i = 1; i <= unpin; i++)  print "UNPINLIST " ulist[i]
  for (i = 1; i <= unprom; i++) print "UNPROMLIST " plist[i]
  for (ar in acount) if (acount[ar] >= areamin && index(body, ar) == 0) print "AREAGAP " ar " " acount[ar]
}' "$idx")

get() { printf '%s\n' "$REPORT" | awk -v k="$1" '$1==k {print $2; exit}'; }
list() { printf '%s\n' "$REPORT" | awk -v k="$1" '$1==k {$1=""; sub(/^ /,""); print}'; }

N=$(get N); COLD=$(get COLD); NPIN=$(get PIN); UNPIN=$(get UNPIN)
OPEN=$(get OPEN); ROT=$(get ROT); NERR=$(get ERR); UNPROM=$(get UNPROM)
AREAGAP=$(printf '%s\n' "$REPORT" | grep -c '^AREAGAP ')
PINPCT=0
[ "$N" -gt 0 ] && PINPCT=$(( NPIN * 100 / N ))

pending=0
[ "$N" -gt "$MAX" ] && pending=1
[ "$COLD" -ge "$NUDGE" ] && pending=1
[ "$stale" -gt 0 ] && pending=1
[ "$ROT" -gt 0 ] && pending=1
[ "$PINPCT" -gt "$PIN_MAX_PCT" ] && pending=1
[ "$UNPIN" -gt 0 ] && pending=1
[ "$COLD" -ge 10 ] && [ "$archived" -eq 0 ] && pending=1
[ "$UNPROM" -gt 0 ] && pending=1
[ "$evalrows" -ge 0 ] && [ "$evalrows" -lt 3 ] && pending=1
[ -n "$overbudget" ] && pending=1
[ "$AREAGAP" -gt 0 ] && pending=1
[ ! -f "$risks" ] && [ "$NERR" -gt 0 ] && pending=1

if [ "$ONELINE" -eq 1 ]; then
  [ "$pending" -eq 0 ] && exit 0
  parts=""
  [ "$stale" -gt 0 ]                && parts="$parts index stale by $stale doc(s);"
  [ "$N" -gt "$MAX" ]               && parts="$parts $N entries (max $MAX);"
  [ "$COLD" -ge "$NUDGE" ]          && parts="$parts $COLD cold;"
  [ "$ROT" -gt 0 ]                  && parts="$parts $ROT open task(s) untouched 30d+;"
  [ "$PINPCT" -gt "$PIN_MAX_PCT" ]  && parts="$parts pin at $PINPCT%;"
  [ "$UNPROM" -gt 0 ]               && parts="$parts $UNPROM recurring error(s) not promoted;"
  [ ! -f "$risks" ] && [ "$NERR" -gt 0 ] && parts="$parts no known-risks file;"
  [ "$evalrows" -ge 0 ] && [ "$evalrows" -lt 3 ] && parts="$parts eval-set unwritten;"
  [ -n "$overbudget" ] && parts="$parts injected text over budget;"
  echo "[agent-os]$parts run: sh $AOS/scripts/agent-os-health.sh"
  exit 0
fi

echo "[health] index: $N entries (max $MAX, nudge $NUDGE) | open tasks: $OPEN | errors: $NERR | pinned: $NPIN ($PINPCT%)"
echo "[health] cold candidates: $COLD (finished, unreferenced, unpinned, older than $COLD_CUT)"

[ "$stale" -gt 0 ] && {
  echo "[health][warn] $stale prompt doc(s) newer than the index -- every scan is reading a stale catalogue."
  echo "[health]       run: sh $AOS/scripts/reindex.sh   (health never writes)"
}
[ "$N" -gt "$MAX" ]      && echo "[health][warn] active index over $MAX -- compaction recommended."
[ "$COLD" -ge "$NUDGE" ] && echo "[health][warn] $COLD cold doc(s) (>= nudge $NUDGE) -- preview: sh $AOS/scripts/agent-os-compact.sh"
[ "$COLD" -ge 10 ] && [ "$archived" -eq 0 ] && \
  echo "[health][warn] $COLD cold doc(s) and no archive yet -- compaction has never run here. See /agent-os:archive."

if [ "$ROT" -gt 0 ]; then
  echo "[health][warn] $ROT open task(s) untouched for 30+ days -- close them, or record why they are blocked:"
  list ROTLIST | sed 's/^/[health]       /'
fi

if [ "$PINPCT" -gt "$PIN_MAX_PCT" ]; then
  echo "[health][warn] $NPIN of $N documents are pinned ($PINPCT% > $PIN_MAX_PCT%)."
  echo "[health]       pin means load-bearing forever, not important. Over-pinning makes cold detection impossible."
fi
if [ "$UNPIN" -gt 0 ]; then
  echo "[health][warn] $UNPIN pinned doc(s) nothing references and nobody has touched in 180 days -- unpin candidates:"
  list UNPINLIST | sed 's/^/[health]       /'
fi

if [ ! -f "$risks" ]; then
  [ "$NERR" -gt 0 ] && {
    echo "[health][warn] $NERR error doc(s) but no $risks -- nothing has been promoted to a rule."
    echo "[health]       Until it exists, errors are the only memory and compaction cannot run safely."
  }
else
  if [ "$UNPROM" -gt 0 ]; then
    echo "[health][warn] $UNPROM error(s) at recurrence 3+ that known-risks does not cite -- promote them or build a gate:"
    list UNPROMLIST | sed 's/^/[health]       /'
  fi
  printf '%s\n' "$REPORT" | awk '$1=="AREAGAP" { printf "[health][warn] area %s has %s errors but no known-risks coverage.\n", $2, $3 }'
fi

if [ -n "$overbudget" ]; then
  echo "[health][warn] injected text over budget:$overbudget"
  echo "[health]       Replace, do not append. Rationale belongs in docs/, not in the prompt."
fi

if [ "$evalrows" -ge 0 ] && [ "$evalrows" -lt 3 ]; then
  echo "[health][warn] $evalfile has $evalrows written row(s) -- it is still the shipped file."
  echo "[health]       Without it there is no way to tell whether a rule still earns its place;"
  echo "[health]       adding and removing rules are both guesses. See $AOS/scripts/bare-test.md."
fi

[ "$pending" -eq 0 ] && echo "[health] ok -- nothing pending."
exit 0
