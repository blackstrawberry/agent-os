# 07 — Known risks

> The traps of this project, as **rules**. Read before working, not after failing.
>
> An error document is a record of one incident. This file is what that incident taught.
> A lesson that lives only in `prompts/errors/` has to be searched for; a lesson here is
> read every time. That is the whole difference.
>
> **This file is what makes archiving safe.** Once a lesson is a rule here, the incident
> document behind it can be compacted away without losing anything. Skip the promotion and
> you get one of two bad ends: archive anyway and the lesson disappears, or keep everything
> and the index grows until nobody scans it.

## How to write an entry

One entry per trap, under the area it belongs to. Four lines, in this order:

- **Risk** — what goes wrong, in one sentence. Present tense, not a story.
- **Symptom** — what you will actually see first. This is the line someone matches against.
- **Response** — what to do instead. Concrete enough to follow without reading the source.
- **Source** — the error ids this came from (`E0031`, `E0038`).

Keep it short. A section nobody finishes reading protects nothing.

## When an entry belongs here

- An error whose `recurrence` reached 3. Three repeats prove the incident document is not
  preventing anything. Promote it, or build a mechanical gate — see the error-log skill.
- A trap that is structural rather than accidental: it will bite anyone who touches that
  area, not just whoever hit it first.
- Anything where the fix is "you have to know this beforehand".

Not everything belongs. A one-off typo stays an incident record.

## When to prefer a gate over an entry

If the mistake can be caught by a hook, a lint rule, a test, or a type — build that instead.
This file relies on being read. A gate does not.

---

## <area>

### <trap name>
- **Risk**:
- **Symptom**:
- **Response**:
- **Source**:

<!-- Add areas as they earn entries. Suggested starting points, from what the installs
     actually tag: deploy, infra, ops, verify, collect, config, security, authz, data-integrity.
     Delete the ones this project does not have. -->
