---
name: error-check
description: Before or while working, scan .agent-os/prompts/errors frontmatter to check whether the same or a similar mistake happened before, and avoid repeating it. Use before editing code, before debugging, on "have I made this mistake before?", or when a recurring error is suspected.
---

# error-check

<Purpose>
Read the error history FIRST so the same trap is not sprung twice.
</Purpose>

<Use_When>
Before any local or broad change. Especially shared core, DB queries, environment-specific
code, external integrations, deploys.
</Use_When>

<Steps>
0. Read `.agent-os/docs/07_known-risks.md` first — one file of rules instead of N incident
   records. What it covers needs no further search. Its absence is itself a finding.

1. Rank, do not scan:
   ```sh
   sh .agent-os/scripts/rank.sh -q "<what you are about to do>" -f "<paths>" -k error -n 8
   ```
   **Open the top 3 at most.** Do NOT grep the index for `"k":"error"` — that pulls every
   error into context.
   - Score 10+ = a **file hit**: a path you will touch is in that error's `files`. Act on it
     with zero keyword matches. Filled on ~20% of docs — a miss means "no information".
   - Do read `recof` on a hit: the earlier errors this one repeats are worth opening too.
   - `rc` is matched, so describing the failure mode works, not just naming the component.
   - No `rank.sh`: grep the index by `area`/`cat`/`tags`/`summary`. No index: `reindex.sh`.
     Old topic: also `prompts/archive/errors-*.jsonl`.

2. Read the root-cause and prevention sections of any match and apply them now.
   Warn briefly: "Past EXXXX in the same area — watch out for: ...".
</Steps>

<Output>
"Related past errors: [EXXXX -- summary -- caution]" — or "no related history". Then proceed.
</Output>

<Links>
New mistake -> `error-log`. A search that should have hit and did not -> add the missing
word to `.agent-os/vocab.txt`.
</Links>

<Self_Maintenance>
Sync matched field names with `prompts/errors/_TEMPLATE.md`. Budget 2000 chars.
</Self_Maintenance>
