# prompts/eval — offline evaluation set (Validation layer)

A set of "questions with clear answers" that **measures** whether the agent / docs / skills actually remove ambiguity.

## Why
- After changing docs or skills, confirm with numbers (not vibes) whether quality improved or regressed -> prevents doc rot.

## How to use
1. After a new session / model / skill change, ask the questions in `eval-set.md`.
2. Compare answers to the expected answers. Pass if the agent also points at the right source doc.
3. On a miss: find which doc/skill is ambiguous and fix it; record in `prompts/errors/` if warranted.
4. When a new trap is found, add a question to `eval-set.md` (the eval set is maintained too).

## Pass bar
- 90%+ of questions correct, each citing a source doc path.
