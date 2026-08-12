#!/bin/sh
# agent-os frontmatter linter.
#
#   sh check-prompts.sh                 lint every doc. Missing keys FAIL; bad values WARN.
#   sh check-prompts.sh --strict        bad values FAIL too.
#   sh check-prompts.sh FILE...         lint only these docs, with bad values FAILING.
#
# The file-list form is what the pre-commit hook uses: a document you are touching is
# held to the enum, while legacy documents you did not touch only warn. Enum drift is
# real -- 18 distinct task `status` values across the installs -- but failing all of
# them at once would block every commit until a bulk migration happened, and that
# migration is deliberately not part of this check.
#
# Performance: one awk process per kind. See task 12 -- the per-file shell version
# spent ~13 processes per document and took 32s for 13 documents on Windows.

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2

STRICT=0
REPORT=0
FILES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --report) REPORT=1; shift ;;     # list everything, never exit non-zero
    *) FILES="$FILES $1"; STRICT=1; shift ;;
  esac
done

AWK_LINT='
function q(s) { return sprintf("%c%s%c", 39, s, 39) }
function bad(path, msg) {
  if (strict) { printf "FAIL  %s : %s\n", path, msg; fail = 1 }
  else        { printf "WARN  %s : %s\n", path, msg; warned = 1 }
}
function hint(path, msg) {
  # Never fatal, not even under --strict. Thin tags cost recall, but blocking a
  # commit over them would push people to type three throwaway words to get past
  # the gate, and bad tags in the highest-weighted search field are worse than none.
  printf "WARN  %s : %s\n", path, msg
}
function checktags(path,   v, n, a, i, c) {
  v = get("tags")
  sub(/^\[/, "", v); sub(/\]$/, "", v)
  gsub(/"/, "", v)
  if (v ~ /^[ \t]*$/) {
    hint(path, "tags is empty -- it is the highest-weighted search field, so this document is only findable through its summary prose")
    return
  }
  n = split(v, a, ",")
  c = 0
  for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t]+$/, "", a[i]); if (a[i] != "") c++ }
  if (c < 3) hint(path, "tags has only " c " entry(s) -- aim for 3 to 8 words you would actually search for")
}
function get(name,   i, v) {
  for (i = 1; i <= nfm; i++) if (fm[i] ~ ("^" name ":")) {
    v = fm[i]
    sub("^" name ":[ \t]*", "", v)
    sub(/[ \t]+$/, "", v)
    return v
  }
  return ""
}
function unquote(v) {
  sub(/^"/, "", v); sub(/"$/, "", v)
  return v
}
function inlist(v, list) { return index(" " list " ", " " v " ") > 0 }
function checkenum(path, field, list,   v) {
  v = unquote(get(field))
  if (v == "") return                       # absence is the key check-s job, not this
  if (inlist(v, list)) return
  if (index(v, "#") > 0)      { bad(path, field " keeps the template comment: " q(v) " -- leave only the value"); return }
  if (index(v, "|") > 0)      { bad(path, field " kept the choice list itself: " q(v)); return }
  if (index(v, "_") > 0 && inlist(gensub_dash(v), list)) {
                                bad(path, field " is " q(v) " -- this schema uses hyphens: " q(gensub_dash(v))); return }
  bad(path, field " is " q(v) " -- allowed: " list)
}
function gensub_dash(v) { gsub(/_/, "-", v); return v }
function checkdate(path, field,   v) {
  v = unquote(get(field))
  if (v == "") return
  if (v ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return
  bad(path, field " is not a bare YYYY-MM-DD date: " q(v))
}
function checkplaceholder(path,   v) {
  v = unquote(get("title"))
  if (v == "short-kebab-slug") bad(path, "title is still the template placeholder")
  v = unquote(get("summary"))
  if (v ~ /^one-line summary/) bad(path, "summary is still the template placeholder")
  v = unquote(get("id"))
  if (v == "E0000" || v == "00") bad(path, "id is still the template placeholder: " q(v))
}
$0 != "" {
  path = $0
  ln = 0; nfm = 0; first = ""
  while ((getline line < path) > 0) {
    gsub(/\r/, "", line)
    ln++
    if (ln == 1) { first = line; continue }
    if (line ~ /^---/) break
    fm[++nfm] = line
  }
  close(path)
  if (first != "---") {
    printf "FAIL  %s : no frontmatter (first line is not %s)\n", path, q("---")
    fail = 1
    next
  }
  # required keys -- unchanged, always fatal
  for (i = 1; i <= nk; i++) {
    found = 0
    for (j = 1; j <= nfm; j++) if (fm[j] ~ ("^" K[i] ":")) { found = 1; break }
    if (!found) { printf "FAIL  %s : missing %s\n", path, q(K[i]); fail = 1 }
  }
  # values
  checkenum(path, "type", typelist)
  checkenum(path, "status", statuslist)
  if (kind == "error") {
    checkenum(path, "severity", "low medium high critical")
    checkenum(path, "category", catlist)
  }
  checkdate(path, "date"); checkdate(path, "created"); checkdate(path, "updated"); checkdate(path, "last_seen")
  checkplaceholder(path)
  checktags(path)
}
BEGIN { nk = split(keys, K, " ") }
END { exit fail }
'

# Enum contents come from a census of 700 documents, not from the template guess.
# category gained process / verification / design, which the field invented and uses
# often enough to be real (9 / 8 / 4 uses). The long tail of one-off categories is
# deliberately not adopted -- a category with a single use is a tag, not a category.
TYPES="task error reference"
TASK_STATUS="planned in-progress completed blocked superseded"
ERROR_STATUS="open resolved"
CATEGORIES="assumption tooling logic env regression security data process verification design"

lint() { # kind keys statuslist catlist  (paths on stdin)
  awk -v keys="$2" -v kind="$1" -v strict="$STRICT" \
      -v typelist="$TYPES" -v statuslist="$3" -v catlist="$CATEGORIES" "$AWK_LINT"
}

fail=0
if [ -n "$FILES" ]; then
  # explicit list: split by directory so each doc is checked against its own schema
  for f in $FILES; do
    [ -e "$f" ] || continue
    case "$f" in
      */_TEMPLATE.md) continue ;;
      "$AOS"/prompts/errors/*)
        printf '%s\n' "$f" | lint error "type id date severity category status summary" "$ERROR_STATUS" || fail=1 ;;
      */manual-*.md) continue ;;
      "$AOS"/prompts/tasks/*)
        printf '%s\n' "$f" | lint task "type id title status created updated summary" "$TASK_STATUS" || fail=1 ;;
    esac
  done
else
  set --
  for f in "$AOS"/prompts/tasks/*.md "$AOS"/prompts/tasks/completed/*.md; do
    [ -e "$f" ] || continue
    case "$f" in */_TEMPLATE.md|*/manual-*.md) continue ;; esac
    set -- "$@" "$f"
  done
  [ $# -eq 0 ] || printf '%s\n' "$@" | lint task "type id title status created updated summary" "$TASK_STATUS" || fail=1

  set --
  for f in "$AOS"/prompts/errors/*.md; do
    [ -e "$f" ] || continue
    case "$f" in */_TEMPLATE.md) continue ;; esac
    set -- "$@" "$f"
  done
  [ $# -eq 0 ] || printf '%s\n' "$@" | lint error "type id date severity category status summary" "$ERROR_STATUS" || fail=1
fi

if [ "$REPORT" -eq 1 ]; then
  echo "(--report: findings above are informational; exiting 0)"
  exit 0
fi
[ "$fail" -eq 0 ] && echo "OK: prompts frontmatter valid"
exit $fail
