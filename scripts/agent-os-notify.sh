#!/bin/sh
# agent-os SessionStart nudge. Run by the plugin hook in every session.
# Silent unless THIS project uses agent-os AND something is actually pending.
#
# All thresholds and all detection live in agent-os-health.sh; this only surfaces its
# one-line verdict. The previous version reimplemented the cold-document rule here and
# carried a comment warning that the copy had to stay matched with the compactor --
# which is the drift, written down. One definition, two callers.

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
health="$root/.agent-os/scripts/agent-os-health.sh"
[ -f "$root/.agent-os/prompts/index.jsonl" ] || exit 0   # not an agent-os project -> stay silent
[ -f "$health" ] || exit 0

sh "$health" --oneline 2>/dev/null
exit 0
