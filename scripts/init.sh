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
[ -d "$TPL" ] || { echo "templates not found: $TPL"; exit 2; }

TARGET="${TARGET:-$(pwd)}"
cd "$TARGET"

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
