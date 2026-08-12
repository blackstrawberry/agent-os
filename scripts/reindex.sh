#!/bin/sh
# agent-os indexer. Builds .agent-os/prompts/index.jsonl (one compact line per active task/error)
# so routing skills scan ONE small file instead of globbing every doc.
# Each line carries the eviction signals: refs (inbound references), updated date, pin, status.
# Usage:
#   sh .agent-os/scripts/reindex.sh              # rebuild the index
#   sh .agent-os/scripts/reindex.sh --emit FILE KIND   # print one JSON line (internal helper)

AOS=".agent-os"

# Inbound-reference pools, scoped by kind so a task id (a bare 2-digit number)
# can't collide with a doc path (e.g. docs/04.md) or an error id. A task id is
# matched only against fields that name a task (related_tasks, generic related,
# and an error's `task:`); an error id only against related_errors / related.
relpool() { # kind
  case "$1" in
    task)  grep -rhE '^(related_tasks|related|task):' "$AOS/prompts" 2>/dev/null | tr -d '\r' ;;
    error) grep -rhE '^(related_errors|related):'     "$AOS/prompts" 2>/dev/null | tr -d '\r' ;;
  esac
}

emit_json() { # file kind   (expects $REL set)
  f="$1"; kind="$2"
  fm=$(awk 'NR==1{if($0!~/^---/)exit} NR==1{next} /^---/{exit} {print}' "$f" | tr -d '\r')
  get() { printf '%s\n' "$fm" | sed -n "s/^$1:[[:space:]]*//p" | head -1 \
          | sed 's/^\[//; s/\]$//; s/^"//; s/"$//'; }
  esc() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
  id=$(get id); status=$(get status); summary=$(get summary)
  area=$(get area); tags=$(get tags); cat=$(get category); pin=$(get pin)
  d=$(get date); [ -n "$d" ] || d=$(get updated); [ -n "$d" ] || d=$(get created)
  [ "$pin" = "true" ] || pin=false
  refs=0
  if [ -n "$id" ]; then
    case "$kind" in
      task)  pool="$REL_TASK" ;;
      error) pool="$REL_ERR" ;;
      *)     pool=$(printf '%s\n%s\n' "$REL_TASK" "$REL_ERR") ;;
    esac
    refs=$(printf '%s\n' "$pool" | grep -ow "$id" | wc -l | tr -d ' ')
  fi
  printf '{"k":"%s","id":"%s","status":"%s","cat":"%s","area":"%s","tags":"%s","date":"%s","refs":%s,"pin":%s,"summary":"%s","path":"%s"}\n' \
    "$kind" \
    "$(printf %s "$id"      | esc)" "$(printf %s "$status" | esc)" \
    "$(printf %s "$cat"     | esc)" "$(printf %s "$area"   | esc)" \
    "$(printf %s "$tags"    | esc)" "$(printf %s "$d"      | esc)" \
    "${refs:-0}" "$pin" \
    "$(printf %s "$summary" | esc)" "$(printf %s "$f"      | esc)"
}

if [ "$1" = "--emit" ]; then
  REL_TASK=$(relpool task); REL_ERR=$(relpool error); emit_json "$2" "$3"; exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
[ -d "$AOS/prompts" ] || { echo "no $AOS/prompts here"; exit 0; }

REL_TASK=$(relpool task); REL_ERR=$(relpool error)
out="$AOS/prompts/index.jsonl"
tmp="$out.tmp.$$"
: > "$tmp"
for f in "$AOS"/prompts/tasks/*.md "$AOS"/prompts/tasks/completed/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md) continue ;; esac
  emit_json "$f" task >> "$tmp"
done
for f in "$AOS"/prompts/errors/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md) continue ;; esac
  emit_json "$f" error >> "$tmp"
done
mv "$tmp" "$out"
echo "reindexed: $(wc -l < "$out" | tr -d ' ') entries -> $out"
