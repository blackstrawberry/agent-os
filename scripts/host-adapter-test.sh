#!/bin/sh
# Distribution-level fixture for Claude/Codex/ChatGPT host adapters.
# This tests plugin packaging and init migration; it is not copied into target projects.
set -e

root=$(git rev-parse --show-toplevel 2>/dev/null) || \
  root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

fail=0
pass=0
ok() { pass=$((pass + 1)); [ "$1" ] && printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }

for f in templates/AGENT_PROTOCOL.section.md templates/CLAUDE.section.md templates/AGENTS.section.md; do
  [ -f "$f" ] || bad "missing $f"
done
if [ -f templates/AGENT_PROTOCOL.section.md ] && [ -f templates/CLAUDE.section.md ] && [ -f templates/AGENTS.section.md ]; then
  cmp -s templates/AGENT_PROTOCOL.section.md templates/CLAUDE.section.md \
    && cmp -s templates/AGENT_PROTOCOL.section.md templates/AGENTS.section.md \
    && ok "protocol templates are byte-identical" \
    || bad "protocol template drift (canonical/Claude/AGENTS differ)"
fi

if [ -f CLAUDE.md ] && [ -f AGENTS.md ]; then
  cmp -s CLAUDE.md AGENTS.md && ok "lab CLAUDE.md and AGENTS.md agree" \
                            || bad "lab host guidance drift"
fi

for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .agents/plugins/marketplace.json; do
  [ -f "$f" ] && ok "present: $f" || bad "missing $f"
done

# Parse JSON when a parser is available. The release host should fail loudly on malformed
# manifests, but this fixture remains runnable on minimal POSIX environments too.
if command -v python3 >/dev/null 2>&1; then
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .agents/plugins/marketplace.json; do
    if python3 -m json.tool "$f" >/dev/null 2>&1; then ok "valid JSON: $f"; else bad "invalid JSON: $f"; fi
  done
fi

json_value() { # file key; shallow top-level string extractor, sufficient for name/version gate
  sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}
if [ -f .claude-plugin/plugin.json ] && [ -f .codex-plugin/plugin.json ]; then
  cn=$(json_value .claude-plugin/plugin.json name); cv=$(json_value .claude-plugin/plugin.json version)
  on=$(json_value .codex-plugin/plugin.json name); ov=$(json_value .codex-plugin/plugin.json version)
  [ -n "$cn" ] && [ "$cn" = "$on" ] && ok "plugin names match ($cn)" || bad "plugin name drift: Claude=$cn OpenAI=$on"
  [ -n "$cv" ] && [ "$cv" = "$ov" ] && ok "plugin versions match ($cv)" || bad "plugin version drift: Claude=$cv OpenAI=$ov"
fi

# Both hosts auto-discover hooks/hooks.json by convention. Keep the native manifests thin.
if grep -Eq '"(\./)?hooks/hooks\.json"' .claude-plugin/plugin.json 2>/dev/null; then
  bad "Claude manifest re-declares convention hook"
else
  ok "Claude manifest leaves convention hook implicit"
fi
if grep -Eq '"(\./)?hooks/hooks\.json"' .codex-plugin/plugin.json 2>/dev/null; then
  bad "OpenAI manifest re-declares convention hook"
else
  ok "OpenAI manifest leaves convention hook implicit"
fi

# A SessionStart hook's stdout is parsed as JSON by the host whenever it looks like JSON.
# Printing the "[agent-os] ..." verdict raw reads as a JSON array, so the host rejects the
# hook and drops the nudge -- silently on one host, as a visible failure on the other.
# The contract is therefore: print nothing, or print one valid SessionStart object. E0012.
notify=scripts/agent-os-notify.sh
if [ ! -f "$notify" ]; then
  bad "missing $notify"
elif command -v python3 >/dev/null 2>&1; then
  nt=$(mktemp -d 2>/dev/null || mktemp -d -t aos-notify-test) || exit 2
  # 1. A project that does not use agent-os must produce no output at all.
  quiet=$( (cd "$nt" && sh "$root/$notify") 2>/dev/null )
  [ -z "$quiet" ] && ok "notify hook stays silent outside agent-os projects" \
                  || bad "notify hook spoke in a non-agent-os project"
  # 2. Inside a real scaffold with something pending, the output must parse as the
  #    documented SessionStart object -- never as a bare line and never as an array.
  mkdir -p "$nt/p"
  if sh scripts/init.sh --no-eval "$nt/p" >"$nt/init.out" 2>&1; then
    spoken=$( (cd "$nt/p" && sh "$root/$notify") 2>/dev/null )
    if [ -z "$spoken" ]; then
      bad "notify hook said nothing in a scaffold with pending work"
    elif printf '%s' "$spoken" | python3 -c '
import json,sys
d = json.load(sys.stdin)
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "SessionStart", h["hookEventName"]
assert h["additionalContext"].strip(), "empty additionalContext"
' >/dev/null 2>&1; then
      ok "notify hook emits a valid SessionStart object"
    else
      bad "notify hook output is not a valid SessionStart object: $(printf '%s' "$spoken" | head -1)"
    fi
  else
    bad "notify fixture could not scaffold: $(head -1 "$nt/init.out")"
  fi
  rm -rf "$nt"
fi

for s in agent-os agent-os-init agent-os-archive task-scan error-check error-log; do
  f="skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then bad "missing $f"; continue; fi
  grep -q '^name:' "$f" && grep -q '^description:' "$f" \
    && ok "skill metadata: $s" || bad "skill metadata missing: $s"
done

# Fresh scaffold + update/migration fixture using the real distribution files.
t=$(mktemp -d 2>/dev/null || mktemp -d -t aos-host-test) || exit 2
trap 'rm -rf "$t"' EXIT INT TERM
mkdir -p "$t/project"
if sh scripts/init.sh --no-eval "$t/project" >"$t/fresh.out" 2>&1; then
  [ -f "$t/project/CLAUDE.md" ] && [ -f "$t/project/AGENTS.md" ] \
    && ok "fresh init creates both host guidance files" \
    || bad "fresh init missed CLAUDE.md or AGENTS.md"
  cmp -s "$t/project/CLAUDE.md" "$t/project/AGENTS.md" \
    && ok "fresh host guidance is identical" || bad "fresh host guidance differs"
else
  bad "fresh init failed: $(head -1 "$t/fresh.out")"
fi

if [ -f "$t/project/CLAUDE.md" ] && [ -f "$t/project/AGENTS.md" ]; then
  { printf 'CLAUDE-BEFORE\n'; cat "$t/project/CLAUDE.md"; printf 'CLAUDE-AFTER\n'; } > "$t/c" && mv "$t/c" "$t/project/CLAUDE.md"
  { printf 'AGENTS-BEFORE\n'; cat "$t/project/AGENTS.md"; printf 'AGENTS-AFTER\n'; } > "$t/a" && mv "$t/a" "$t/project/AGENTS.md"
  # Make the existing blocks stale without touching text outside them.
  sed 's/## Agent Operating Protocol (agent-os)/## Old Agent Protocol/' "$t/project/CLAUDE.md" > "$t/c" && mv "$t/c" "$t/project/CLAUDE.md"
  sed 's/## Agent Operating Protocol (agent-os)/## Old Agent Protocol/' "$t/project/AGENTS.md" > "$t/a" && mv "$t/a" "$t/project/AGENTS.md"
  if sh scripts/init.sh --update "$t/project" >"$t/update.out" 2>&1; then
    grep -q '^CLAUDE-BEFORE$' "$t/project/CLAUDE.md" && grep -q '^CLAUDE-AFTER$' "$t/project/CLAUDE.md" \
      && grep -q '^## Agent Operating Protocol (agent-os)$' "$t/project/CLAUDE.md" \
      && ok "update preserves CLAUDE outside text" || bad "CLAUDE outside text changed"
    grep -q '^AGENTS-BEFORE$' "$t/project/AGENTS.md" && grep -q '^AGENTS-AFTER$' "$t/project/AGENTS.md" \
      && grep -q '^## Agent Operating Protocol (agent-os)$' "$t/project/AGENTS.md" \
      && ok "update preserves AGENTS outside text" || bad "AGENTS outside text changed"
  else
    bad "update fixture failed: $(head -1 "$t/update.out")"
  fi

  rm -f "$t/project/AGENTS.md"
  sh scripts/init.sh --update "$t/project" >"$t/migrate.out" 2>&1 \
    && [ -f "$t/project/AGENTS.md" ] \
    && ok "update migrates Claude-only install with AGENTS.md" \
    || bad "Claude-only migration did not create AGENTS.md"

  cp "$t/project/CLAUDE.md" "$t/claude.before"
  printf '%s\n' '<!-- agent-os:begin -->' 'broken' > "$t/project/AGENTS.md"
  if sh scripts/init.sh --update "$t/project" >"$t/bad.out" 2>&1; then
    bad "malformed AGENTS markers were accepted"
  else
    cmp -s "$t/project/CLAUDE.md" "$t/claude.before" \
      && ok "malformed host file aborts before partial write" \
      || bad "malformed AGENTS caused partial CLAUDE update"
  fi
fi

rm -rf "$t"; trap - EXIT INT TERM

if [ "$fail" -gt 0 ]; then
  printf 'host-adapter-test: %s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
printf 'host-adapter-test: %s passed\n' "$pass"
