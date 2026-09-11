#!/bin/sh
# agent-os scaffolder. Installs the host-independent memory structure under .agent-os/
# and thin host guidance at the repository root (CLAUDE.md + AGENTS.md).
# Never overwrites project-owned memory.
# Usage: bash init.sh [--update] [--no-eval] [target_dir]
set -e

AOS=".agent-os"
WANT_EVAL=1
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
PROTO="$TPL/AGENT_PROTOCOL.section.md"
[ -f "$PROTO" ] || PROTO="$TPL/CLAUDE.section.md"
AOS_VERSION=$( (cd "$PLUGIN_DIR" && git rev-parse --short HEAD) 2>/dev/null || date +%Y-%m-%d )
[ -d "$TPL" ] || { echo "templates not found: $TPL"; exit 2; }
[ -f "$PROTO" ] || { echo "protocol template not found: $PROTO"; exit 2; }

TARGET="${TARGET:-$(pwd)}"
cd "$TARGET"

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
  if [ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1; then
    if [ "$(git ls-files -s "$AOS/scripts/hooks/pre-commit" 2>/dev/null | awk '{print $1}')" = "100644" ]; then
      git update-index --chmod=+x "$AOS/scripts/hooks/pre-commit" 2>/dev/null \
        && echo "UPDATE $AOS/scripts/hooks/pre-commit (git mode -> 100755)"
    fi
  fi
}

insert_keys() {
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
  if [ "$(pwd -P)" != "$(cd "$PLUGIN_DIR" && pwd -P)" ] \
     && [ -f "$AOS/vocab.txt" ] && [ -f "$TPL/vocab.txt" ] && cmp -s "$AOS/vocab.txt" "$TPL/vocab.txt"; then
    echo "NOTE   $AOS/vocab.txt is still the shipped file -- seed it with this project's own"
    echo "       terms. An unseeded alias map can turn related work into a false zero-result."
  fi
}

MARK_BEGIN='<!-- agent-os:begin -->'
MARK_END='<!-- agent-os:end -->'

validate_guidance() {
  f="$1"
  [ -f "$f" ] || return 0
  b=$(grep -c "$MARK_BEGIN" "$f" || true)
  e=$(grep -c "$MARK_END" "$f" || true)
  if [ "$b" -ne 1 ] || [ "$e" -ne 1 ]; then
    echo "ABORT: $f needs exactly one agent-os:begin and one agent-os:end marker (found $b / $e)."
    echo "       Refusing to guess where the protocol block is. No guidance files changed."
    return 2
  fi
}

strip_guidance() {
  awk '/<!-- agent-os:begin -->/{skip=1;next} /<!-- agent-os:end -->/{skip=0;next} !skip{print}' "$1"
}

update_guidance() {
  f="$1"
  if [ ! -f "$f" ]; then
    cat "$PROTO" > "$f"
    echo "CREATE $f (agent-os protocol)"
    return 0
  fi

  prev="$f.aos-prevblock"
  incoming="$f.aos-incoming.$$"
  before="$f.aos-outside-before.$$"
  after="$f.aos-outside-after.$$"
  new="$f.aos-new"

  awk '/<!-- agent-os:begin -->/{p=1;next} /<!-- agent-os:end -->/{p=0} p{print}' "$f" > "$prev"
  awk '/<!-- agent-os:begin -->/{p=1;next} /<!-- agent-os:end -->/{p=0} p{print}' "$PROTO" > "$incoming"
  strip_guidance "$f" > "$before"

  if cmp -s "$prev" "$incoming"; then
    rm -f "$prev"
  elif git ls-files --error-unmatch "$f" >/dev/null 2>&1 && git diff --quiet -- "$f" 2>/dev/null; then
    rm -f "$prev"
    echo "NOTE   the replaced $f block differed; the old text is recoverable from git."
  else
    echo "NOTE   the replaced $f block differed and is not committed clean."
    echo "       Saved the old block as $prev."
  fi
  rm -f "$incoming"

  awk -v tpl="$PROTO" '
    /<!-- agent-os:begin -->/ { while ((getline l < tpl) > 0) print l; close(tpl); skip = 1; next }
    /<!-- agent-os:end -->/   { skip = 0; next }
    !skip { print }
  ' "$f" > "$new"

  if ! grep -q "$MARK_BEGIN" "$new" || ! grep -q "$MARK_END" "$new"; then
    rm -f "$new" "$before" "$after"
    echo "ABORT: rewritten $f lost protocol markers. No change made."
    return 2
  fi
  strip_guidance "$new" > "$after"
  if ! cmp -s "$before" "$after"; then
    rm -f "$new" "$before" "$after"
    echo "ABORT: content outside the protocol block changed in $f. No change made."
    return 2
  fi
  rm -f "$before" "$after"
  mv "$new" "$f"
  echo "UPDATE $f (agent-os block replaced; outside text preserved)"
}

scaffold_guidance() {
  f="$1"
  if [ -f "$f" ]; then
    if grep -q "$MARK_BEGIN" "$f" 2>/dev/null; then
      echo "SKIP   $f (agent-os section already present)"
    else
      printf '\n' >> "$f"
      cat "$PROTO" >> "$f"
      echo "APPEND $f (agent-os section added)"
    fi
  else
    cat "$PROTO" > "$f"
    echo "CREATE $f"
  fi
}

if [ "$UPDATE" -eq 1 ]; then
  validate_guidance CLAUDE.md || exit 2
  validate_guidance AGENTS.md || exit 2
  update_guidance CLAUDE.md
  update_guidance AGENTS.md
  update_scripts
  update_templates
  report_theirs
  if [ -x "$AOS/scripts/check-prompts.sh" ] || [ -f "$AOS/scripts/check-prompts.sh" ]; then
    lf=$(sh "$AOS/scripts/check-prompts.sh" 2>&1 | grep -c '^FAIL' || true)
    if [ "${lf:-0}" -gt 0 ]; then
      echo "WARN   the refreshed linter reports $lf failing doc(s) in this project."
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

copy() {
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
  copy "$TPL/prompts/eval/README.md"      "$AOS/prompts/eval/README.md"
  copy "$TPL/prompts/eval/eval-set.md"    "$AOS/prompts/eval/eval-set.md"
fi

scaffold_guidance CLAUDE.md
scaffold_guidance AGENTS.md

sh "$AOS/scripts/reindex.sh" >/dev/null 2>&1 && echo "CREATE $AOS/prompts/index.jsonl"
[ -n "$AOS_VERSION" ] && printf '%s\n' "$AOS_VERSION" > "$AOS/VERSION"

echo ""
echo "Done. Next:"
echo "  1) enable the forced-sync hook: git config core.hooksPath $AOS/scripts/hooks"
echo "     then confirm it can run: sh $AOS/scripts/portability-test.sh"
echo "  2) fill $AOS/docs/ with this project's source of truth from a real repository scan"
echo "  3) seed $AOS/prompts/eval/eval-set.md with failures that actually happened"
echo "  4) promote durable lessons to $AOS/docs/07_known-risks.md before archiving incidents"
echo "  5) lint: sh $AOS/scripts/check-prompts.sh   |  health: sh $AOS/scripts/agent-os-health.sh"
