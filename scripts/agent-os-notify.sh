#!/bin/sh
# agent-os SessionStart nudge. Run by the plugin hook in every session.
# Silent unless THIS project uses agent-os AND something is actually pending.
#
# All thresholds and all detection live in agent-os-health.sh; this only surfaces its
# one-line verdict. The previous version reimplemented the cold-document rule here and
# carried a comment warning that the copy had to stay matched with the compactor --
# which is the drift, written down. One definition, two callers.
#
# Output contract: a SessionStart hook's stdout is parsed as JSON by the host when it
# looks like JSON. The verdict line starts with "[agent-os]", which reads as a JSON
# array, so printing it raw made Codex report the hook as failed and drop the nudge
# entirely. Emit the documented SessionStart object instead -- Claude Code and Codex
# both accept it -- or print nothing at all. See errors/E0012.

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
health="$root/.agent-os/scripts/agent-os-health.sh"
[ -f "$root/.agent-os/prompts/index.jsonl" ] || exit 0   # not an agent-os project -> stay silent
[ -f "$health" ] || exit 0

# Collapse to a single line: a raw newline is not legal inside a JSON string.
msg=$(sh "$health" --oneline 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')
[ -n "$msg" ] || exit 0                                   # nothing pending -> stay silent

esc=$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
exit 0
