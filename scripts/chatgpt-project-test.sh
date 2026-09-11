#!/bin/sh
# Distribution fixture for ChatGPT Project compatibility artifacts.
set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || \
  root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

fail=0
pass=0
ok() { pass=$((pass + 1)); [ "$1" ] && printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }

for f in \
  templates/chatgpt/profile.txt \
  templates/chatgpt/BUNDLE_HEADER.md \
  templates/chatgpt/PROJECT_INSTRUCTIONS.md \
  scripts/build-chatgpt-project.sh \
  chatgpt/agent-os-chatgpt.md \
  chatgpt/PROJECT_INSTRUCTIONS.md; do
  [ -f "$f" ] && ok "present: $f" || bad "missing $f"
done

if sh -n scripts/build-chatgpt-project.sh 2>/dev/null; then
  ok "builder shell syntax"
else
  bad "builder shell syntax"
fi

profile_entries=$(grep -Ev '^[[:space:]]*(#|$)' templates/chatgpt/profile.txt 2>/dev/null || true)
profile_count=$(printf '%s\n' "$profile_entries" | grep -c . || true)
[ "$profile_count" -eq 4 ] && ok "Project profile is explicit (4 skills)" \
                          || bad "Project profile expected 4 skills, got $profile_count"
for s in agent-os task-scan error-check error-log; do
  printf '%s\n' "$profile_entries" | grep -qx "$s" \
    && ok "Project profile includes $s" || bad "Project profile missing $s"
done
for s in agent-os-init agent-os-archive; do
  if printf '%s\n' "$profile_entries" | grep -qx "$s"; then
    bad "Project profile unexpectedly includes $s"
  else
    ok "Project profile excludes local-only $s"
  fi
done

# Rebuild twice: same source must be byte-identical, and the tracked public artifact must match.
t=$(mktemp -d 2>/dev/null || mktemp -d -t aos-chatgpt-test) || exit 2
trap 'rm -rf "$t"' EXIT INT TERM
mkdir -p "$t/a" "$t/b"
if sh scripts/build-chatgpt-project.sh "$t/a" >"$t/build-a.out" 2>"$t/build-a.err" && \
   sh scripts/build-chatgpt-project.sh "$t/b" >"$t/build-b.out" 2>"$t/build-b.err"; then
  ok "Project artifacts build"
  cmp -s "$t/a/agent-os-chatgpt.md" "$t/b/agent-os-chatgpt.md" && \
    cmp -s "$t/a/PROJECT_INSTRUCTIONS.md" "$t/b/PROJECT_INSTRUCTIONS.md" \
    && ok "Project export is deterministic" || bad "Project export is not deterministic"
  cmp -s "$t/a/agent-os-chatgpt.md" chatgpt/agent-os-chatgpt.md && \
    cmp -s "$t/a/PROJECT_INSTRUCTIONS.md" chatgpt/PROJECT_INSTRUCTIONS.md \
    && ok "tracked Project artifacts match canonical sources" \
    || bad "tracked Project artifacts are stale; run scripts/build-chatgpt-project.sh"
else
  bad "Project artifact build failed: $(head -1 "$t/build-a.err" 2>/dev/null)"
fi

version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
if [ -n "$version" ]; then
  grep -Fq "> Version: $version" chatgpt/agent-os-chatgpt.md \
    && grep -Fq "Generated for agent-os $version" chatgpt/PROJECT_INSTRUCTIONS.md \
    && ok "Project provenance matches plugin version ($version)" \
    || bad "Project provenance/version drift"
fi
grep -Fq 'https://github.com/blackstrawberry/agent-os' chatgpt/agent-os-chatgpt.md \
  && ok "Project provenance points to public source" || bad "Project public source provenance missing"

if grep -Eq 'agent-os-lab|27_universal_install_distribution|ADR-0005_intent_capability_distribution' chatgpt/agent-os-chatgpt.md chatgpt/PROJECT_INSTRUCTIONS.md; then
  bad "Project artifacts leak private lab identifiers"
else
  ok "Project artifacts exclude private lab identifiers"
fi

for phrase in \
  'does not imply repository write access' \
  'Never claim a task/file/status/commit/push changed' \
  'ambiguous zero'; do
  grep -Fq "$phrase" chatgpt/agent-os-chatgpt.md \
    && ok "capability contract: $phrase" || bad "missing capability contract: $phrase"
done

# Negative fixture: an allowlisted Skill missing from canonical skills must fail closed.
mkdir -p "$t/negative/scripts" "$t/negative/templates" "$t/negative/skills" "$t/negative/.claude-plugin" "$t/negative/.codex-plugin"
cp scripts/build-chatgpt-project.sh "$t/negative/scripts/"
cp -R templates/chatgpt "$t/negative/templates/"
cp -R skills/agent-os skills/task-scan skills/error-check skills/error-log "$t/negative/skills/"
cp .claude-plugin/plugin.json "$t/negative/.claude-plugin/"
cp .codex-plugin/plugin.json "$t/negative/.codex-plugin/"
printf '\nmissing-skill\n' >> "$t/negative/templates/chatgpt/profile.txt"
if (cd "$t/negative" && sh scripts/build-chatgpt-project.sh "$t/out-negative") >/dev/null 2>"$t/negative.err"; then
  bad "missing allowlisted Skill was accepted"
else
  grep -q 'profile requires missing' "$t/negative.err" \
    && ok "missing allowlisted Skill fails closed" \
    || bad "negative fixture failed for an unexpected reason"
fi

rm -rf "$t"; trap - EXIT INT TERM

if [ "$fail" -gt 0 ]; then
  printf 'chatgpt-project-test: %s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
printf 'chatgpt-project-test: %s passed\n' "$pass"
