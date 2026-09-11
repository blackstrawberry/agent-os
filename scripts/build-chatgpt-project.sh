#!/bin/sh
# Build the ready-to-upload ChatGPT Project compatibility artifacts from canonical Skills.
# Maintainer/release tool: end users should download the tracked files under chatgpt/.
set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || \
  root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

profile="templates/chatgpt/profile.txt"
instructions="templates/chatgpt/PROJECT_INSTRUCTIONS.md"
outdir="${1:-chatgpt}"
source_url="https://github.com/blackstrawberry/agent-os"
max_bytes=18000
max_tokens_approx=6000

[ -f "$profile" ] || { echo "missing $profile" >&2; exit 1; }
[ -f "$instructions" ] || { echo "missing $instructions" >&2; exit 1; }

json_value() {
  sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}
version=$(json_value .claude-plugin/plugin.json version)
[ -n "$version" ] || { echo "cannot read plugin version" >&2; exit 1; }
[ "$version" = "$(json_value .codex-plugin/plugin.json version)" ] || {
  echo "plugin version drift" >&2; exit 1;
}

mkdir -p "$outdir"
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t aos-chatgpt-build) || exit 2
trap 'rm -rf "$tmp"' EXIT INT TERM
bundle="$tmp/agent-os-chatgpt.md"
project="$tmp/PROJECT_INSTRUCTIONS.md"

sed -e "s|@VERSION@|$version|g" -e "s|@SOURCE@|$source_url|g" \
  templates/chatgpt/BUNDLE_HEADER.md > "$bundle"

count=0
seen=" "
while IFS= read -r skill || [ -n "$skill" ]; do
  case "$skill" in ''|'#'*) continue ;; esac
  case "$skill" in *[!A-Za-z0-9_-]*) echo "invalid profile entry: $skill" >&2; exit 1 ;; esac
  case "$seen" in *" $skill "*) echo "duplicate profile entry: $skill" >&2; exit 1 ;; esac
  seen="$seen$skill "
  f="skills/$skill/SKILL.md"
  [ -f "$f" ] || { echo "profile requires missing $f" >&2; exit 1; }
  grep -q "^name:[[:space:]]*$skill$" "$f" || { echo "skill name metadata mismatch: $f" >&2; exit 1; }
  grep -q "^description:" "$f" || { echo "skill description metadata missing: $f" >&2; exit 1; }
  count=$((count + 1))
  {
    printf '\n---\n\n## Skill: `%s`\n\nCanonical source: `%s`\n\n<canonical-skill>\n' "$skill" "$f"
    cat "$f"
    printf '\n</canonical-skill>\n'
  } >> "$bundle"
done < "$profile"
[ "$count" -gt 0 ] || { echo "empty Project compatibility profile" >&2; exit 1; }

bytes=$(wc -c < "$bundle" | tr -d ' ')
approx_tokens=$(( (bytes + 2) / 3 ))
[ "$bytes" -le "$max_bytes" ] || {
  echo "Project bundle exceeds byte budget: $bytes > $max_bytes" >&2; exit 1;
}
[ "$approx_tokens" -le "$max_tokens_approx" ] || {
  echo "Project bundle exceeds approximate token budget: $approx_tokens > $max_tokens_approx" >&2; exit 1;
}

{
  printf '<!-- Generated for agent-os %s from %s. Do not edit this generated copy. -->\n\n' "$version" "$source_url"
  cat "$instructions"
} > "$project"

cp "$bundle" "$outdir/agent-os-chatgpt.md"
cp "$project" "$outdir/PROJECT_INSTRUCTIONS.md"
printf 'built ChatGPT Project artifacts: %s skills, %s bytes, ~%s tokens\n' "$count" "$bytes" "$approx_tokens"
