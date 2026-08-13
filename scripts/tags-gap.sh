#!/bin/sh
# agent-os tags gap report. Lists documents whose `tags` is empty or thin.
#
#   sh .agent-os/scripts/tags-gap.sh            summary counts plus the empty ones
#   sh .agent-os/scripts/tags-gap.sh --all      also list the thin ones (1-2 tags)
#
# `tags` is the highest-weighted field the ranker scores (3 points per hit, same as
# keywords, against 1 for summary). An empty tags list drops that document to prose
# matching only.
#
# It only reports. Auto-tagging from body text is deliberately not offered: a wrong
# tag in the top-weighted field pollutes every future search, which is worse than a
# gap that shows up here.

# See reindex.sh: awk byte-vs-character semantics and LC_COLLATE glob order both vary
# by locale, silently. Task 17.
export LC_ALL=C

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
[ -d "$AOS/prompts" ] || { echo "no $AOS/prompts here"; exit 0; }

ALL=0
[ "$1" = "--all" ] && ALL=1

set --
for f in "$AOS"/prompts/tasks/*.md "$AOS"/prompts/tasks/completed/*.md "$AOS"/prompts/errors/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md) continue ;; esac
  set -- "$@" "$f"
done
[ $# -gt 0 ] || { echo "no documents"; exit 0; }

printf '%s\n' "$@" | awk -v all="$ALL" '
{
  path = $0
  ln = 0; nfm = 0
  while ((getline line < path) > 0) {
    gsub(/\r/, "", line); ln++
    if (ln == 1) { if (line !~ /^---/) break; else continue }
    if (line ~ /^---/) break
    fm[++nfm] = line
  }
  close(path)
  n++
  v = ""
  for (i = 1; i <= nfm; i++) if (fm[i] ~ /^tags:/) { v = fm[i]; sub(/^tags:[ \t]*/, "", v); break }
  sub(/^\[/, "", v); sub(/\]$/, "", v); gsub(/"/, "", v)
  c = 0
  m = split(v, a, ",")
  for (i = 1; i <= m; i++) { gsub(/^[ \t]+|[ \t]+$/, "", a[i]); if (a[i] != "") c++ }
  if (c == 0)      { empty++; elist[++ei] = path }
  else if (c < 3)  { thin++;  tlist[++ti] = path " (" c ")" }
  else             { ok++ }
}
END {
  printf "documents %d   tags ok (3+) %d   thin (1-2) %d   EMPTY %d   -> %.0f%% empty\n", \
         n, ok+0, thin+0, empty+0, (n ? 100*empty/n : 0)
  if (empty) { print "\nempty:"; for (i = 1; i <= ei; i++) print "  " elist[i] }
  if (all && thin) { print "\nthin:"; for (i = 1; i <= ti; i++) print "  " tlist[i] }
}'
