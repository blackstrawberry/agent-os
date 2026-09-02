# Bare test — is this harness still earning its place?

A procedure for a person to run, not a script. Once per model generation, or whenever
the rules have grown enough that you are not sure which of them still do anything.

**There is no automatic runner and there will not be one.** Building a harness to audit
the harness is the failure this document exists to catch.

## The question

Rules only ever accumulate. Every one of them was added for a reason, and none of them
carries an expiry. Some compensate for a weakness the model no longer has; those became
dead weight the moment the model changed, and dead weight in a prompt is not free — it
costs context, it dilutes the rules that still matter, and it is read every session.

Removing a rule needs evidence exactly as much as adding one did. This is how you get it.

## Procedure

1. **Fill `prompts/eval/eval-set.md` first.** Five rows minimum, decidable, sourced.
   Without it there is nothing to measure and the rest of this document is theatre.

2. **Bare run.** Disable the `<!-- agent-os:begin -->` … `<!-- agent-os:end -->` block in
   `CLAUDE.md`. Start a fresh session. Ask the five questions. Score.
   - The block contains HTML comments already, so wrapping it in one does not comment it
     out — comments do not nest. Move the file instead (`git mv CLAUDE.md CLAUDE.md.off`);
     `git checkout` always restores it.
   - **Fresh session means a new process, not a subagent and not `/clear`.** `CLAUDE.md` is
     loaded once at session start and subagents inherit the parent's copy — measured
     2026-08-17: with the file *deleted*, a freshly spawned subagent still quoted the
     protocol verbatim. Editing the file mid-session changes nothing that is already loaded.
   - **A new process is enough; it does not have to be a person opening one.** Measured
     2026-08-18: `git worktree add` a detached copy, delete `CLAUDE.md` *inside the
     worktree*, and run the questions there with `claude -p` (`--session-id` on the probe,
     `--resume` for the questions, so probe and questions share one session). The
     subprocess looks for the project `CLAUDE.md` on disk, finds none, and starts bare.
     The main working tree is never touched, which removes the restore-it-afterwards trap
     entirely. Note the worktree has no untracked files — no `index.jsonl`, so nothing
     that depends on the index can be measured this way.
   - **Run the probe against the *harnessed* tree first.** A `NONE` proves nothing on its
     own: a probe that is simply broken also answers `NONE`. Confirm it quotes the protocol
     where the protocol exists, then go bare. Same failure shape as `E0003`/`E0004` — a
     check that cannot tell "passed" from "never ran" is not a check.
   - **First prompt of the bare session is a control check, not a question:**
     *"For this one question only, read no files and answer from context alone. (The
     restriction applies to this question only; open files normally from the next question
     on.) Were you given agent-os protocol instructions? Quote the first 200 characters,
     or answer NONE."* Anything but `NONE` and the session is not a control — stop and
     start over. A run whose control was never checked is indistinguishable from a run
     that silently kept the rules.
   - **Scope that "read no files" to the probe explicitly.** Measured 2026-08-17: without
     the scoping clause the model held the restriction for the whole session and answered
     all five questions without opening a single file, while the comparison run used 5–12
     tool calls per question. That contaminates the difference with *file access* on top of
     *rules*, and it is invisible until the model mentions it in passing — here, at
     question five: "you told me not to read, so I still haven't opened anything."

3. **Harnessed run.** Restore the block. Fresh session. Same five questions. Score.

4. **Compare.**

| Result | Reading |
|---|---|
| Harnessed clearly higher | The rules are carrying that difference. Keep them. |
| Roughly equal | **The rules are not doing what you think.** Either the answers were reachable from the repo anyway, or the rules are not being followed. Find out which before deleting anything — those need opposite responses. |
| Bare higher | Rare, and worth stopping for. Something in the rules is actively misleading. |

5. **Write the numbers down**, in the eval-set's baseline table, including when there was
   no difference. A no-difference result is the finding, not a failed experiment. It is
   the only thing that ever justifies deleting a rule.
   **Put the model identifier on the row.** This procedure runs "once per model
   generation"; with no identifier on the baseline row there is nothing for the next
   generation to differ from, so that trigger can never fire and a deferral that named it
   as its revisit condition becomes permanent.

## Size budget

The protocol block in `CLAUDE.md` is capped at **3000 characters**, each `SKILL.md` body at
**2000** (the frontmatter `description` is excluded — it is how the skill gets routed, not
prose anyone chose). `agent-os-health.sh` measures both and warns.

**Over budget the rule is replace, never append.** The cap exists because nothing measured
this before and it only ever grew: one working session took these four files from 9,936 to
20,718 characters, every single addition individually reasonable. Rationale belongs in
`.agent-os/docs/` and the task journal — not in text injected into every session.

## Which rules are even candidates

Classify before you cut. Only one kind is eligible.

- **Weakness-compensating (How)** — exists because a model tends to do the wrong thing.
  "Verify before claiming completion", "do not add unnecessary abstractions", "answer in
  the user's language". These are candidates: a newer model may not need the instruction.
- **Unique-context (What / Why)** — facts no model can derive. "This repo keeps two
  copies of every script", "the `dist` branch has no common ancestor with `main`",
  "we rejected merge drivers in ADR-0002". **Never candidates.** A better model does not
  become better informed about decisions your team made in June; if anything it proposes
  the rejected option with more confidence.

The same split applies to error documents. A record about a model behaving badly may
dissolve with a model change. A record about `cp932` encoding, an MSYS path-conversion
trap, or a VPC timeout is environmental and permanent.

## Note on the verification loop

There is a claim in circulation that mandatory self-verification costs roughly 4x for a
blander result. Do not settle that by opinion; it is measurable here — count the defects a
review pass caught before release against the tokens it consumed.

A first, deliberately crude count over this org's error documents: 10 of 57 and 24 of 66
name a critic, reviewer, or red-team pass in their text. That is a count of **mentions**,
not of catches, and it is an upper bound rather than a result. What it does establish is
that the material to measure properly exists. Until that measurement is made, no ADR
should record a verdict either way — deciding before measuring is precisely what decision
records are supposed to prevent.

One thing the records already separate cleanly: catches came from a review in a **separate
context**, never from a self-approval in the same one.
