#!/bin/sh
# agent-os portability fixture. Asserts that the platform-sensitive parts of the
# toolchain behave the SAME on macOS/BSD and Linux/Windows(MSYS2).
#
# Why this exists (task 14): macOS awk (one-true-awk) counts length()/substr() in
# BYTES; GNU awk in a UTF-8 locale counts CHARACTERS. A guard written as
# "length(w) < 3" therefore never fires for Korean on macOS -- every syllable is
# 3 bytes -- and rank.sh silently over-stemmed 2-syllable query words there.
# That class of bug is invisible to any single-platform measurement, so it needs a
# fixture rather than an eval set.
#
# Usage:
#   sh .agent-os/scripts/portability-test.sh          # quiet on success
#   sh .agent-os/scripts/portability-test.sh -v       # print every case
#
# Exit 0 = all pass. Exit 1 = at least one failure (the failing lines are printed).
#
# The awk functions under test are EXTRACTED from rank.sh rather than copied here.
# A copy would be a third definition to keep in sync (see E0001) and would happily
# pass while the real script stayed broken.

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2

VERBOSE=0
[ "$1" = "-v" ] && VERBOSE=1

# Prefer the dogfooding copy; fall back to the distribution original so this runs
# from either side of the two-copy layout.
RANK="$AOS/scripts/rank.sh"
[ -f "$RANK" ] || RANK="scripts/rank.sh"
[ -f "$RANK" ] || { echo "portability-test: cannot find rank.sh"; exit 2; }

fail=0
pass=0

report() {
  # $1 = ok|FAIL, $2 = case name, $3 = expected, $4 = got
  if [ "$1" = ok ]; then
    pass=$((pass + 1))
    [ "$VERBOSE" = 1 ] && printf '  ok    %s\n' "$2"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s -- expected [%s], got [%s]\n' "$2" "$3" "$4"
  fi
  return 0
}

# --- extract the functions under test -------------------------------------
# Every function in rank.sh starts at column 0 with "function NAME(" and ends at a
# column-0 "}". That is the whole grammar this needs.
extract_fn() {
  awk -v n="$1" '
    $0 ~ "^function " n "\\(" { p = 1 }
    p { print }
    p && /^}$/ { exit }
  ' "$2"
}

FN_UCHARS=$(extract_fn uchars "$RANK")
FN_DESTEM=$(extract_fn destem "$RANK")
FN_ISWORD=$(extract_fn isword "$RANK")
FN_TERMHIT=$(extract_fn termhit "$RANK")

[ -n "$FN_DESTEM" ] || { echo "portability-test: destem() not found in $RANK"; exit 2; }
if [ -z "$FN_UCHARS" ]; then
  printf '  FAIL  uchars() is not defined in %s\n' "$RANK"
  printf '        (destem still uses byte-based length() -- the macOS bug is unfixed)\n'
  fail=$((fail + 1))
fi

# Run one awk expression against the extracted functions. Prints the result.
# The program goes through a file, not a shell string: the extracted bodies contain
# regex slashes and quotes, and `awk -f -` is not portable.
PROG=$(mktemp) || exit 2
trap 'rm -f "$PROG"' EXIT
# LC_ALL=C because that is how rank.sh invokes awk, and uchars() is only valid there
# (a UTF-8-locale BSD awk dies on a lone continuation byte).
call() {
  { printf '%s\n%s\n' "$FN_UCHARS" "$FN_DESTEM" "$FN_ISWORD" "$FN_TERMHIT"
    printf 'BEGIN { print %s }\n' "$1"; } > "$PROG"
  LC_ALL=C awk -f "$PROG" </dev/null 2>/dev/null
}

echo "portability-test: $(uname -s) / $(awk --version 2>&1 | head -1)"

# --- 1. character counting is not byte counting ---------------------------
for case in '한글ABC:5' ':0' 'abc:3' '테스트:3' 'あア漢:3'; do
  in=${case%:*}; want=${case##*:}
  got=$(call "uchars(\"$in\")")
  [ "$got" = "$want" ] && report ok "uchars(\"$in\")" || report FAIL "uchars(\"$in\")" "$want" "$got"
done

# --- 1b. short ASCII terms need a word boundary; longer ones and CJK do not ---
# Measured on a 267-document corpus: "expected 403 to be 202" put the wrong document
# first at 50.0
# because `to` sat inside `tool` and `be` inside `before`, and the right document fell
# out of the top two. CJK queries never showed it, which is the tell -- Korean and
# Japanese have no word separators, so a boundary rule there breaks them outright.
# Hence the scope: ASCII tokens of 3 characters or fewer. Hyphens are not word
# characters on purpose, so `s3` still reaches `s3-bucket` and still misses `s3fs`.
if [ -n "$FN_TERMHIT" ]; then
  for case in 'to|tool broke|0' 'to|expected to be|1' 'be|before deploy|0' \
              'be|to be 202|1' 's3|s3fs mount|0' 's3|s3 bucket|1' \
              's3|s3-bucket sync|1' 'deploy|deployment failed|1' 'ec2|on ec2 today|1'; do
    t=${case%%|*}; rest=${case#*|}; hay=${rest%|*}; want=${rest##*|}
    got=$(call "termhit(\"$hay\", \"$t\")")
    [ "$got" = "$want" ] && report ok "termhit($t in '$hay')" \
                         || report FAIL "termhit($t in '$hay')" "$want" "$got"
  done
else
  report FAIL "termhit() is defined in rank.sh" "present" "missing"
fi

# --- 2. destem: the short-word guard must fire for short KOREAN words -----
# These are the cases that regress on macOS. 결과/문의 end in a particle-shaped
# syllable (과/의) but are only 2 characters, so the guard must protect them.
for case in '결과:결과' '문의:문의' '나:나' '정도:정도' '제로:제로'; do
  in=${case%:*}; want=${case##*:}
  got=$(call "destem(\"$in\")")
  [ "$got" = "$want" ] && report ok "destem(\"$in\") kept" || report FAIL "destem(\"$in\") kept" "$want" "$got"
done

# --- 3. destem: the guard must NOT over-correct ---------------------------
# Genuine particle removal still has to happen, or the fix trades one bug for another.
for case in '테스트를:테스트' '인덱스를:인덱스' '브라우저에서:브라우저' '커밋이:커밋' '스크립트의:스크립트'; do
  in=${case%:*}; want=${case##*:}
  got=$(call "destem(\"$in\")")
  [ "$got" = "$want" ] && report ok "destem(\"$in\") stemmed" || report FAIL "destem(\"$in\") stemmed" "$want" "$got"
done

# --- 4. the date ladder resolves on this platform -------------------------
# GNU date, BSD date, perl, python3 -- in that order. rank.sh and
# agent-os-compact.sh both depend on this producing a real YYYY-MM-DD.
d=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null \
    || date -v-30d +%Y-%m-%d 2>/dev/null \
    || perl -e 'use POSIX; print strftime("%Y-%m-%d", localtime(time-86400*30))' 2>/dev/null \
    || python3 -c 'import datetime; print((datetime.date.today()-datetime.timedelta(days=30)).isoformat())' 2>/dev/null)
case "$d" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) report ok "date ladder -> $d" ;;
  *) report FAIL "date ladder" "YYYY-MM-DD" "$d" ;;
esac

# --- 5. the two script copies have not drifted (E0001) --------------------
if [ -d scripts ] && [ -d "$AOS/scripts" ]; then
  for n in reindex.sh check-prompts.sh rank.sh tags-gap.sh agent-os-compact.sh agent-os-health.sh portability-test.sh; do
    [ -f "scripts/$n" ] || continue
    if cmp -s "scripts/$n" "$AOS/scripts/$n"; then
      report ok "2-copy sync: $n"
    else
      report FAIL "2-copy sync: $n" "identical" "differs"
    fi
  done
  if [ -f scripts/pre-commit ]; then
    cmp -s scripts/pre-commit "$AOS/scripts/hooks/pre-commit" \
      && report ok "2-copy sync: pre-commit" \
      || report FAIL "2-copy sync: pre-commit" "identical" "differs"
  fi
fi

# --- 5b. the pre-commit hook is actually executable -----------------------
# git REFUSES to run a hook without the exec bit, and says so only as a hint that
# scrolls past. Windows/MSYS ignores the mode and runs it anyway, so a hook stored
# as 100644 works there and is silently dead on macOS and Linux -- the gate reports
# nothing and blocks nothing. Same failure class as E0003. See E0004.
hook="$AOS/scripts/hooks/pre-commit"
if [ -f "$hook" ]; then
  [ -x "$hook" ] && report ok "pre-commit is executable" \
                 || report FAIL "pre-commit is executable" "executable" "chmod +x $hook"
  # The mode git STORES is what every fresh clone gets; the working-tree bit is not
  # enough, because a clone reads the index.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    mode=$(git ls-files -s "$hook" 2>/dev/null | awk '{print $1}')
    case "$mode" in
      100755|"") report ok "pre-commit mode in git (${mode:-untracked})" ;;
      *) report FAIL "pre-commit mode in git" "100755" "$mode -- run: git update-index --chmod=+x $hook" ;;
    esac
  fi
fi

# --- 5c. core.hooksPath is set -------------------------------------------
# Not a repo defect -- it is per-clone config that no checkout carries. A new machine
# has the hook file and no gate until this is run once.
if git rev-parse --git-dir >/dev/null 2>&1 && [ -f "$hook" ]; then
  [ -n "$(git config core.hooksPath)" ] \
    && report ok "core.hooksPath is set" \
    || report FAIL "core.hooksPath is set" "$AOS/scripts/hooks" "unset -- run: git config core.hooksPath $AOS/scripts/hooks"
fi

# --- 6. the caller's locale does not change the answer --------------------
# End-to-end, not on the extracted functions: what has to hold is that rank.sh and
# agent-os-health.sh give the same answer no matter what locale the user's shell is
# in. Testing the extracted functions here would pass by construction, because this
# harness pins LC_ALL=C itself.
if [ -f "$AOS/prompts/index.jsonl" ]; then
  q='결과 통과 문의 나 테스트를'
  a=$(LC_ALL=C sh "$RANK" -q "$q" -n 5 2>/dev/null)
  b=$(LC_ALL=ja_JP.UTF-8 sh "$RANK" -q "$q" -n 5 2>/dev/null)
  c=$(LC_ALL=ko_KR.UTF-8 sh "$RANK" -q "$q" -n 5 2>/dev/null)
  if [ "$a" = "$b" ] && [ "$a" = "$c" ]; then
    report ok "rank.sh locale invariance (C / ja_JP.UTF-8 / ko_KR.UTF-8)"
  else
    report FAIL "rank.sh locale invariance" "identical output" "differs by locale"
  fi

  # Every script, byte-for-byte, across locales. reindex.sh is the one that mattered:
  # glob expansion sorts by LC_COLLATE, so two machines produced the same entries in a
  # different ORDER -- and index.jsonl is tracked in most installs, so that is a diff
  # each contributor flips back forever. Ordering bugs do not announce themselves.
  for s in reindex.sh check-prompts.sh tags-gap.sh agent-os-compact.sh agent-os-health.sh; do
    [ -f "$AOS/scripts/$s" ] || continue
    ref=""; same=1
    for L in C ja_JP.UTF-8 ko_KR.UTF-8 en_US.UTF-8; do
      m=$(LC_ALL=$L sh "$AOS/scripts/$s" 2>&1 | cksum)
      if [ -z "$ref" ]; then ref=$m; elif [ "$m" != "$ref" ]; then same=0; fi
    done
    [ "$same" = 1 ] && report ok "locale-stable output: $s" \
                    || report FAIL "locale-stable output: $s" "identical" "varies by locale"
  done
else
  [ "$VERBOSE" = 1 ] && printf '  skip  locale invariance (no index; run reindex.sh)\n'
fi

# --- 6b. reindex.sh actually emits the documents that exist -----------------
# The locale check above compares one run against another, so a reindex that emits
# ZERO entries passes it -- identically broken in four locales is still identical.
# Measured 2026-08-18: a printf whose argument list had one fewer value than its
# format string made awk abort per file; reindex reported "0 entries" and this suite
# still said 40 passed. Same shape as E0003/E0004 -- a check that cannot tell a pass
# from a run that did nothing. Count the inputs independently of the parser.
if [ -d "$AOS/prompts" ]; then
  # Decision records live under docs/adr/, not prompts/ -- reindex walks both, so the
  # independent count has to as well. Getting that wrong once is how this check first
  # reported 27 against 30 and looked like a reindex bug rather than a counting bug.
  want=$(find "$AOS/prompts" "$AOS/docs/adr" -name '*.md' -not -name '_TEMPLATE.md'            -exec grep -lE '^type:[[:space:]]*[a-z]' {} + 2>/dev/null | wc -l | tr -d ' ')
  sh "$AOS/scripts/reindex.sh" >/dev/null 2>&1
  got=$(wc -l < "$AOS/prompts/index.jsonl" 2>/dev/null | tr -d ' ')
  got=${got:-0}
  if [ "$want" -gt 0 ] && [ "$got" = "$want" ]; then
    report ok "reindex emits one entry per frontmatter doc ($got)"
  else
    report FAIL "reindex emits one entry per frontmatter doc" "$want" "$got"
  fi
  # Every line has to be one object with a path, or downstream reads garbage quietly.
  bad=$(awk 'NF && ($0 !~ /^\{.*"path":"[^"]+".*\}$/) { n++ } END { print n+0 }' "$AOS/prompts/index.jsonl" 2>/dev/null)
  [ "${bad:-1}" = 0 ] && report ok "every index line is one object with a path"                       || report FAIL "every index line is one object with a path" "0 malformed" "$bad malformed"
fi

# --- 7. rank.sh rejects bad option values ---------------------------------
# The option loop shifted 2 for every flag without checking that a value was there.
# `-n` at the end of the line made `shift 2` fail, $# never shrank, and the loop spun
# forever -- a search command that hangs the caller. `-n 0` was worse in the quiet
# way: head -n 0 prints nothing and exits 0, which is byte-identical to "no related
# prior work", and the protocol tells the agent to move on when it sees that. Same
# class as E0003 -- a gate that cannot tell "passed" from "never ran".
#
# macOS has no timeout(1), so the cap is hand-rolled. Whole seconds only: POSIX sleep
# is not required to accept fractions, and the wait only happens when the bug is back.
run_capped() { # $1 = seconds, rest = command; returns 124 if it outlived the cap
  _secs=$1; shift
  "$@" >/dev/null 2>&1 &
  _cp=$!
  _i=0
  while [ "$_i" -lt "$_secs" ]; do
    kill -0 "$_cp" 2>/dev/null || { wait "$_cp"; return $?; }
    sleep 1
    _i=$((_i + 1))
  done
  kill -9 "$_cp" 2>/dev/null
  wait "$_cp" 2>/dev/null
  return 124
}

for bad in "-n:0" "-n:abc" "-n:-3"; do
  flag=${bad%%:*}; val=${bad#*:}
  run_capped 5 sh "$RANK" -q test "$flag" "$val"
  rc=$?
  [ "$rc" = 2 ] && report ok "rank.sh rejects $flag $val" \
                || report FAIL "rank.sh rejects $flag $val" "exit 2" "exit $rc"
done

# Value missing entirely -- this is the one that used to hang.
for flag in -n -q -f -k; do
  run_capped 5 sh "$RANK" -q test "$flag"
  rc=$?
  [ "$rc" = 2 ] && report ok "rank.sh rejects trailing $flag" \
                || report FAIL "rank.sh rejects trailing $flag" "exit 2" \
                       "exit $rc$([ "$rc" = 124 ] && echo ' -- HUNG')"
done

# --- verdict --------------------------------------------------------------
if [ "$fail" -gt 0 ]; then
  printf 'portability-test: %d passed, %d FAILED\n' "$pass" "$fail"
  exit 1
fi
printf 'portability-test: %d passed.\n' "$pass"
exit 0
