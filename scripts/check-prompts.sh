#!/bin/sh
# agent-os frontmatter linter. Fails (exit 1) if any task/error doc is missing required frontmatter keys.
# Usage: sh .agent-os/scripts/check-prompts.sh   (manual)  or called from the pre-commit hook.

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
fail=0

check_keys() {
  file="$1"; shift
  if [ "$(head -1 "$file" | tr -d '\r')" != "---" ]; then
    echo "FAIL  $file : no frontmatter (first line is not '---')"; fail=1; return
  fi
  fm=$(awk 'NR==1{next} /^---/{exit} {print}' "$file" | tr -d '\r')
  for key in "$@"; do
    printf '%s\n' "$fm" | grep -q "^$key:" || { echo "FAIL  $file : missing '$key'"; fail=1; }
  done
}

for f in "$AOS"/prompts/tasks/*.md "$AOS"/prompts/tasks/completed/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md) continue ;; esac
  check_keys "$f" type id title status created updated summary
done

for f in "$AOS"/prompts/errors/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md) continue ;; esac
  check_keys "$f" type id date severity category status summary
done

[ "$fail" -eq 0 ] && echo "OK: prompts frontmatter valid"
exit $fail
