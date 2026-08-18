#!/bin/sh
# agent-os scaffolder. Installs the operating-system structure into a project under .agent-os/
# (so the project root stays clean). Never overwrites existing files.
# Usage: bash init.sh [--no-eval] [target_dir]   (the Validation eval set scaffolds by default)
set -e

AOS=".agent-os"
WANT_EVAL=1   # Validation eval set scaffolds by default; pass --no-eval to skip
UPDATE=0
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --eval) WANT_EVAL=1; shift ;;
    --no-eval) WANT_EVAL=0; shift ;;
    --update) UPDATE=1; shift ;;
    *) TARGET="$1"; shift ;;
  esac
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(dirname "$SCRIPT_DIR")
TPL="$PLUGIN_DIR/templates"
# An install that cannot say what it has cannot be told it is behind. Cheap version:
# the source checkout's short commit, falling back to a date when git is unavailable.
AOS_VERSION=$( (cd "$PLUGIN_DIR" && git rev-parse --short HEAD) 2>/dev/null || date +%Y-%m-%d )
[ -d "$TPL" ] || { echo "templates not found: $TPL"; exit 2; }

TARGET="${TARGET:-$(pwd)}"
cd "$TARGET"

# --update refreshes the parts agent-os owns and REPORTS the parts the project owns.
# Before this existed the only upgrade path was copying files by hand into every
# install; that was done five times in one day across twelve repositories, and each
# sweep is a chance to miss one. copy() deliberately skips anything that exists, which
# is right for scaffolding and useless for upgrading, so --update needs its own rules:
#
#   ours     scripts/, hooks/pre-commit, the CLAUDE.md block   -> overwrite
#   theirs   templates, vocab.txt, docs/, prompts/             -> never overwrite
#
# Templates are the awkward middle. Every install customises them -- measured, all ten
# differed from the shipped copy -- so replacing the file destroys their work. But the
# indexer reads specific keys, and a template that never asks for a key means that key
# is empty everywhere: `keywords` and `root_cause` were dead in ten of ten repositories
# for exactly that reason. So keys get INSERTED when missing and nothing is ever
# removed or rewritten.
update_scripts() {
  for f in check-prompts.sh reindex.sh rank.sh tags-gap.sh bare-test.md \
           agent-os-compact.sh agent-os-health.sh portability-test.sh; do
    [ -f "$SCRIPT_DIR/$f" ] || continue
    if [ -f "$AOS/scripts/$f" ] && cmp -s "$SCRIPT_DIR/$f" "$AOS/scripts/$f"; then
      echo "SAME   $AOS/scripts/$f"
    else
      mkdir -p "$AOS/scripts"; cp "$SCRIPT_DIR/$f" "$AOS/scripts/$f"
      echo "UPDATE $AOS/scripts/$f"
    fi
  done
  if [ -f "$SCRIPT_DIR/pre-commit" ]; then
    mkdir -p "$AOS/scripts/hooks"
    if cmp -s "$SCRIPT_DIR/pre-commit" "$AOS/scripts/hooks/pre-commit" 2>/dev/null; then
      echo "SAME   $AOS/scripts/hooks/pre-commit"
    else
      cp "$SCRIPT_DIR/pre-commit" "$AOS/scripts/hooks/pre-commit"
      echo "UPDATE $AOS/scripts/hooks/pre-commit"
    fi
  fi
  chmod +x "$AOS"/scripts/*.sh "$AOS"/scripts/hooks/pre-commit 2>/dev/null || true
  # git stores the mode separately from the filesystem, and Windows ignores the
  # filesystem one entirely, so a hook can be executable here and 100644 for everyone
  # who clones it. That is how a commit gate ran on nobody's machine but ours.
  if [ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1; then
    if [ "$(git ls-files -s "$AOS/scripts/hooks/pre-commit" 2>/dev/null | awk '{print $1}')" = "100644" ]; then
      git update-index --chmod=+x "$AOS/scripts/hooks/pre-commit" 2>/dev/null \
        && echo "UPDATE $AOS/scripts/hooks/pre-commit (git mode -> 100755)"
    fi
  fi
}

# One line per key. Insert before summary:, which every template has.
insert_keys() {  # $1 = template path, $2... = "key:default  # comment"
  t="$1"; shift
  [ -f "$t" ] || { echo "SKIP   $t (absent)"; return 0; }
  grep -q '^summary:' "$t" || { echo "SKIP   $t (no summary: anchor)"; return 0; }
  added=""
  for spec in "$@"; do
    k=${spec%%:*}
    grep -qE "^$k:" "$t" && continue
    awk -v line="$spec" '/^summary:/ && !done { print line; done = 1 } { print }' "$t" > "$t.aos-new" \
      && mv "$t.aos-new" "$t"
    added="$added $k"
  done
  [ -n "$added" ] && echo "UPDATE $t (added:$added)" || echo "SAME   $t"
}

update_templates() {
  insert_keys "$AOS/prompts/errors/_TEMPLATE.md" \
    'keywords: []            # extra search keys, weight 3 like tags: symptom words, error strings' \
    'recurrence: 1           # times this has bitten, counting the first. Bump instead of a second doc.' \
    'last_seen: ""           # YYYY-MM-DD of the most recent occurrence' \
    'root_cause: ""          # one line. Indexed as a search key and for recurrence matching.' \
    'caught_by: ""           # self | review | user | runtime -- who FIRST surfaced it. Empty if unrecorded.' \
    'files: []               # related paths -- what rank.sh -f matches on'
  insert_keys "$AOS/prompts/tasks/_TEMPLATE.md" \
    'keywords: []            # extra search keys, weight 3 like tags' \
    'files:                  # source paths this task touched -- what rank.sh -f matches on'
}

report_theirs() {
  for f in vocab.txt docs/07_known-risks.md; do
    [ -f "$AOS/$f" ] || echo "MISSING $AOS/$f (this project owns it -- agent-os will not write it)"
  done
  # In the source checkout the two ARE the same file by definition, and a note that can
  # never be acted on is how people learn to skim past this output.
  if [ "$(pwd)" != "$PLUGIN_DIR" ]      && [ -f "$AOS/vocab.txt" ] && [ -f "$TPL/vocab.txt" ] && cmp -s "$AOS/vocab.txt" "$TPL/vocab.txt"; then
    echo "NOTE   $AOS/vocab.txt is still the shipped file -- seed it with this project's own"
    echo "       terms. Measured: an unseeded alias map costs about 17 points of top-3, and"
    echo "       the failures arrive as ZERO results, which reads as 'no prior work'."
  fi
}

# --update: refresh ONLY the protocol block in an existing CLAUDE.md, leaving everything
# outside the markers untouched. Scaffolding never overwrites, so without this an install
# keeps its original protocol text forever.
if [ "$UPDATE" -eq 1 ]; then
  [ -f CLAUDE.md ] || { echo "no CLAUDE.md here -- run without --update to scaffold one"; exit 2; }
  b=$(grep -c '<!-- agent-os:begin -->' CLAUDE.md || true)
  e=$(grep -c '<!-- agent-os:end -->' CLAUDE.md || true)
  if [ "$b" -ne 1 ] || [ "$e" -ne 1 ]; then
    echo "ABORT: expected exactly one agent-os:begin and one agent-os:end marker (found $b / $e)."
    echo "       Refusing to guess where the block is. No changes made."
    exit 2
  fi
  awk -v tpl="$TPL/CLAUDE.section.md" '
    /<!-- agent-os:begin -->/ { while ((getline l < tpl) > 0) print l; close(tpl); skip = 1; next }
    /<!-- agent-os:end -->/   { skip = 0; next }
    !skip { print }
  ' CLAUDE.md > CLAUDE.md.aos-new
  # sanity: the replacement must still carry both markers and keep the outside content
  if ! grep -q '<!-- agent-os:begin -->' CLAUDE.md.aos-new || ! grep -q '<!-- agent-os:end -->' CLAUDE.md.aos-new; then
    rm -f CLAUDE.md.aos-new
    echo "ABORT: the rewritten file lost its markers. No changes made."
    exit 2
  fi
  before=$(awk '/<!-- agent-os:begin -->/{f=1} !f' CLAUDE.md | wc -m)
  after=$(awk '/<!-- agent-os:begin -->/{f=1} !f' CLAUDE.md.aos-new | wc -m)
  if [ "$before" != "$after" ]; then
    rm -f CLAUDE.md.aos-new
    echo "ABORT: content above the marker changed. No changes made."
    exit 2
  fi
  mv CLAUDE.md.aos-new CLAUDE.md
  echo "UPDATE CLAUDE.md (agent-os block replaced; everything outside the markers untouched)"
  update_scripts
  update_templates
  report_theirs
  # The linter just got replaced, and a newer one is stricter. If this project carries
  # legacy frontmatter the hook will now block every commit -- so say it here, loudly,
  # instead of letting the next person discover it mid-commit with no idea what changed.
  if [ -x "$AOS/scripts/check-prompts.sh" ] || [ -f "$AOS/scripts/check-prompts.sh" ]; then
    lf=$(sh "$AOS/scripts/check-prompts.sh" 2>&1 | grep -c '^FAIL' || true)
    if [ "${lf:-0}" -gt 0 ]; then
      echo "WARN   the refreshed linter reports $lf failing doc(s) in this project."
      echo "       core.hooksPath is $(git config core.hooksPath 2>/dev/null || echo unset);"
      echo "       if it points at agent-os hooks, commits are blocked until those are fixed."
      echo "       Fix the frontmatter, or restore the old linter from git and upgrade later."
    fi
  fi
  if [ -n "$AOS_VERSION" ]; then
    printf '%s\n' "$AOS_VERSION" > "$AOS/VERSION"
    echo "UPDATE $AOS/VERSION ($AOS_VERSION)"
  fi
  exit 0

fi
echo "scaffold target: $TARGET/$AOS  (eval=$WANT_EVAL)"

mkdir -p "$AOS/prompts/tasks/completed" "$AOS/prompts/errors" "$AOS/prompts/reference" "$AOS/docs" "$AOS/scripts/hooks"

copy() { # src dst
  if [ -e "$2" ]; then echo "SKIP   $2 (exists)"; else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "CREATE $2"; fi
}

copy "$TPL/prompts/README.md"            "$AOS/prompts/README.md"
copy "$TPL/prompts/tasks/_TEMPLATE.md"   "$AOS/prompts/tasks/_TEMPLATE.md"
copy "$TPL/prompts/errors/_TEMPLATE.md"  "$AOS/prompts/errors/_TEMPLATE.md"
copy "$TPL/docs/README.md"               "$AOS/docs/README.md"
copy "$TPL/docs/07_known-risks.md"       "$AOS/docs/07_known-risks.md"
mkdir -p "$AOS/docs/adr"
copy "$TPL/docs/adr/_TEMPLATE.md"        "$AOS/docs/adr/_TEMPLATE.md"
copy "$TPL/vocab.txt"                    "$AOS/vocab.txt"
copy "$SCRIPT_DIR/check-prompts.sh"      "$AOS/scripts/check-prompts.sh"
copy "$SCRIPT_DIR/reindex.sh"            "$AOS/scripts/reindex.sh"
copy "$SCRIPT_DIR/rank.sh"               "$AOS/scripts/rank.sh"
copy "$SCRIPT_DIR/tags-gap.sh"           "$AOS/scripts/tags-gap.sh"
copy "$SCRIPT_DIR/bare-test.md"          "$AOS/scripts/bare-test.md"
copy "$SCRIPT_DIR/agent-os-compact.sh"   "$AOS/scripts/agent-os-compact.sh"
copy "$SCRIPT_DIR/agent-os-health.sh"    "$AOS/scripts/agent-os-health.sh"
copy "$SCRIPT_DIR/portability-test.sh"   "$AOS/scripts/portability-test.sh"
copy "$SCRIPT_DIR/pre-commit"            "$AOS/scripts/hooks/pre-commit"
chmod +x "$AOS"/scripts/*.sh "$AOS"/scripts/hooks/pre-commit 2>/dev/null || true

if [ "$WANT_EVAL" -eq 1 ]; then
  copy "$TPL/prompts/eval/README.md"   "$AOS/prompts/eval/README.md"
  copy "$TPL/prompts/eval/eval-set.md" "$AOS/prompts/eval/eval-set.md"
fi

# CLAUDE.md stays at the project ROOT (Claude Code reads it there); only the protocol section is added.
MARK="<!-- agent-os:begin -->"
if [ -f CLAUDE.md ]; then
  if grep -q "$MARK" CLAUDE.md 2>/dev/null; then
    echo "SKIP   CLAUDE.md (agent-os section already present)"
  else
    printf '\n' >> CLAUDE.md
    cat "$TPL/CLAUDE.section.md" >> CLAUDE.md
    echo "APPEND CLAUDE.md (agent-os section added)"
  fi
else
  cat "$TPL/CLAUDE.section.md" > CLAUDE.md
  echo "CREATE CLAUDE.md"
fi

sh "$AOS/scripts/reindex.sh" >/dev/null 2>&1 && echo "CREATE $AOS/prompts/index.jsonl"

echo ""
echo "Done. Next:"
echo "  1) enable the forced-sync hook: git config core.hooksPath $AOS/scripts/hooks"
echo "     then confirm it can actually run: sh $AOS/scripts/portability-test.sh"
echo "     (git refuses a hook without the exec bit, and says so only in a passing hint)"
echo "  2) fill $AOS/docs/ with this project's source of truth (initial full scan)"
echo "  3) fill $AOS/prompts/eval/eval-set.md -- 5 rows, from what has actually bitten"
echo "     this project. It is the ONLY way to tell later whether a rule still earns its"
echo "     place; without it, adding and removing rules are both guesses."
echo "     Measured across 19 installs: 17 never filled it in."
echo "  4) fill $AOS/docs/07_known-risks.md as lessons appear -- promoting a lesson is"
echo "     what makes archiving the incident safe."
echo "  5) lint: sh $AOS/scripts/check-prompts.sh   |  health: sh $AOS/scripts/agent-os-health.sh"
