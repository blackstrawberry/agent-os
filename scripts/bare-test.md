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

2. **Bare run.** Comment out the `<!-- agent-os:begin -->` … `<!-- agent-os:end -->`
   block in `CLAUDE.md`. Start a fresh session. Ask the five questions. Score.
   - Fresh session matters. A session that already read the rules has them in context.

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
