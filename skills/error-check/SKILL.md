---
name: error-check
description: Before local or broad code work, check agent-os known risks and prior error records so the same trap is not repeated. Use before editing/debugging, on recurring-error questions, and in ChatGPT-style repository analysis as well as shell-capable hosts.
---

# error-check

<Purpose>
Read durable lessons and the most relevant error history BEFORE changing code.
</Purpose>

<Steps>
0. Read `.agent-os/docs/07_known-risks.md` first. What it already covers needs no incident dump.

1. Find prior errors without loading them all.
   **Shell available:**
   ```sh
   sh .agent-os/scripts/rank.sh -q "<what you are about to do>" -f "<paths>" -k error -n 8
   ```
   **No shell:** search `.agent-os/prompts/errors/` by root cause, summary, tags, keywords and
   touched paths. If code search is unavailable, unindexed, or an empty result is ambiguous,
   list the errors directory and shortlist by filename/frontmatter/path instead. Include archived
   error JSONL only for old topics. Prefer path/root-cause hits. Open the top 3 at most.

2. Read root cause and prevention on matches and apply them now. A recorded file-path hit matters
   even when wording differs. Follow `related_errors` when a hit says it recurred from another id.

3. If retrieval should have matched but did not, first distinguish **unindexed search** from a
   missing vocabulary alias. Writable hosts add a truly missing alias to `.agent-os/vocab.txt`;
   read-only hosts report it instead.
</Steps>

<Output>
"Related past errors: [id -- summary -- caution]" — or "no related history". Then proceed.
Never claim a repository update in read-only mode.
</Output>

<Links>
A new mistake -> `error-log`.
</Links>

<Self_Maintenance>
Sync matched fields with `prompts/errors/_TEMPLATE.md`. Keep retrieval bounded.
</Self_Maintenance>
