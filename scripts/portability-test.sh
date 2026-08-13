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
  { printf '%s\n%s\n' "$FN_UCHARS" "$FN_DESTEM"
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

# --- verdict --------------------------------------------------------------
if [ "$fail" -gt 0 ]; then
  printf 'portability-test: %d passed, %d FAILED\n' "$pass" "$fail"
  exit 1
fi
printf 'portability-test: %d passed.\n' "$pass"
exit 0
