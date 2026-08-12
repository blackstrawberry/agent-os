#!/bin/sh
# agent-os scaffolder. Installs the operating-system structure into a project under .agent-os/
# (so the project root stays clean). Never overwrites existing files.
# Usage: bash init.sh [--no-eval] [target_dir]   (the Validation eval set scaffolds by default)
set -e

AOS=".agent-os"
WANT_EVAL=1   # Validation eval set scaffolds by default; pass --no-eval to skip
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --eval) WANT_EVAL=1; shift ;;
    --no-eval) WANT_EVAL=0; shift ;;
    *) TARGET="$1"; shift ;;
  esac
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(dirname "$SCRIPT_DIR")
TPL="$PLUGIN_DIR/templates"
[ -d "$TPL" ] || { echo "templates not found: $TPL"; exit 2; }

TARGET="${TARGET:-$(pwd)}"
cd "$TARGET"
echo "scaffold target: $TARGET/$AOS  (eval=$WANT_EVAL)"

mkdir -p "$AOS/prompts/tasks/completed" "$AOS/prompts/errors" "$AOS/prompts/reference" "$AOS/docs" "$AOS/scripts/hooks"

copy() { # src dst
  if [ -e "$2" ]; then echo "SKIP   $2 (exists)"; else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "CREATE $2"; fi
}

copy "$TPL/prompts/README.md"            "$AOS/prompts/README.md"
copy "$TPL/prompts/tasks/_TEMPLATE.md"   "$AOS/prompts/tasks/_TEMPLATE.md"
copy "$TPL/prompts/errors/_TEMPLATE.md"  "$AOS/prompts/errors/_TEMPLATE.md"
copy "$TPL/docs/README.md"               "$AOS/docs/README.md"
copy "$SCRIPT_DIR/check-prompts.sh"      "$AOS/scripts/check-prompts.sh"
copy "$SCRIPT_DIR/reindex.sh"            "$AOS/scripts/reindex.sh"
copy "$SCRIPT_DIR/agent-os-compact.sh"   "$AOS/scripts/agent-os-compact.sh"
copy "$SCRIPT_DIR/agent-os-health.sh"    "$AOS/scripts/agent-os-health.sh"
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
echo "  1) (recommended) enable forced-sync hook: git config core.hooksPath $AOS/scripts/hooks"
echo "  2) fill $AOS/docs/ with this project's source of truth (initial full scan)"
echo "  3) lint: sh $AOS/scripts/check-prompts.sh   |  health: sh $AOS/scripts/agent-os-health.sh"
