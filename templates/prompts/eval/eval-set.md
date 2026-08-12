# Evaluation set — this project's core traps

> **This file ships empty on purpose.** An earlier version shipped with five filled-in
> example rows from a fictional app, and 17 of 19 installs still hold those examples
> untouched. A slot that looks filled never gets filled.
>
> Five rows. Write them from what actually bit this project, not from what a reader
> ought to know.

## Why this exists

This is the only instrument that can answer **"is this rule still earning its place?"**
Run the questions with the agent-os rules off, then on, and compare — see `bare-test.md`.
Without it, adding a rule and removing a rule are both guesses, and rules only ever
accumulate.

## How to write a row

1. **Decidable.** The answer is right or wrong on inspection. "How should we handle
   errors?" is not a row; "what is the one sanctioned way to reach the DB?" is.
2. **Costly to get wrong.** A row should come from something that already caused damage
   or nearly did — check `prompts/errors/` and `docs/07_known-risks.md` first.
3. **Sourced.** Name the document holding the answer. A row with no source is a row
   nobody can settle an argument with.

Not a quiz on general engineering. If a competent stranger could answer it without
reading this repo, it does not belong here.

| # | Question | Expected answer (gist) | Source |
|---|---|---|---|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |
| 4 |  |  |  |
| 5 |  |  |  |

## Scoring

Answered correctly **and with the source cited**. 90%+ = pass.
Below that, the gap is in the doc or the skill, not in the answer — go fix that.
