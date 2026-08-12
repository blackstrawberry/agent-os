<!-- agent-os:begin -->
## Agent Operating Protocol (agent-os)

<!-- (How)/(Why) tags and the size budget: see .agent-os/scripts/bare-test.md.
     Over budget, replace -- never append. -->

### Sizing the work (How)
- **Trivial** (a commit, one command, a one-line answer): do it. No scans.
- **Local** (one file, a clear bug): `error-check` only. A task doc is optional.
- **Broad** (many files, design change, new feature): everything below.
When unsure, assume the smaller one.

### Before broad work, you must KNOW (Why)
No fixed order -- get these however is cheapest: related prior work and rejected decisions;
the source of truth (`.agent-os/docs/`, `07_known-risks.md` first); past traps in this area.
Low top score = nothing related. Say so and move on.

### Finding things (How)
```sh
sh .agent-os/scripts/rank.sh -q "<words>" -f "<paths you will touch>" -n 8
```
Open the top 3 at most. **Never** grep the index for `"k":"error"` -- that loads every one.
`-f` is the strongest signal: a doc naming a file you will touch matters with zero keyword
hits. Ask in any language; `.agent-os/vocab.txt` expands the query. A search that should
have hit but did not means a missing vocab line -- add it.

### Recording (Why)
- **Errors**: same root cause as an existing one -> bump its `recurrence` and `last_seen`,
  add a history row. Never open a second doc for one trap.
  **At `recurrence` 3, editing the doc is not a response** -- promote it to
  `docs/07_known-risks.md`, or build a mechanical gate (hook, lint, test).
- **Decisions** (`docs/adr/`): only when reversal is expensive AND a real alternative was
  rejected. Two sections carry it -- *Rejected alternatives* (named as someone would
  propose them) and *Revisit when*; without the second a deferral becomes permanent.
  Indexed, so a re-proposal hits the rejection first. Keep them rare.
- **Docs are the source of truth, but code is ground truth.** They disagree -> fix the
  doc in the same change. Never copy secret values anywhere. Verified facts only: confirm
  where a symbol lives with grep, never infer it from an import line.

### Closing (How)
`status: completed`, move to `prompts/tasks/completed/`, docs updated in the same change.
`hooks/pre-commit` enforces the mechanical part (`git config core.hooksPath
.agent-os/scripts/hooks`).

### Keeping memory cheap (How)
- Promote a lesson to `07_known-risks.md` **before** archiving the incident -- that is what
  makes archiving safe. Preview `agent-os-compact.sh`, apply via `/agent-os:archive`.
- `pin: true` = load-bearing forever, not important. Over-pinning kills cold detection.
- `agent-os-health.sh` reports what has gone quiet (stale index, rotting tasks, over-pinning,
  unpromoted repeats, empty eval set, prompt over budget). Read-only.
<!-- agent-os:end -->
