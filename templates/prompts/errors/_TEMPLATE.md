---
type: error
id: E0000               # E + 4 digits (matches the filename)
title: short-kebab-slug
date: 2025-01-01         # YYYY-MM-DD (real date)
task: ""                # related task id ("" if none)
severity: medium        # low | medium | high | critical  -- exactly these four, lowercase
category: assumption    # assumption | tooling | logic | env | regression | security | data
                        #  | process | verification | design
                        # Exactly one, nothing appended. Anything finer goes in tags, not here.
status: open            # open | resolved
area: []                # frontend | backend | api | db | common | infra | meta
tags: []                # search keys. NOT optional -- an empty tags list degrades the scan to prose matching
keywords: []            # extra search keys: symptom words, error strings, library names
pin: false              # true = never auto-archive (load-bearing / permanently relevant)
files: []               # related file paths. The strongest signal error-check has -- fill it
recurrence: 1           # HOW MANY TIMES THIS HAS BITTEN, counting the first one. 1 = happened once.
                        # Not "how many repeats" -- do not write 0. Bump it on every recurrence.
                        # Alternative form, where the value carries more than a count: list the
                        # earlier error ids this one repeats, e.g. ["12", "14"].
last_seen: ""           # YYYY-MM-DD of the MOST RECENT occurrence. Set it on every recurrence.
                        # `date` stays the first occurrence; ranking and archival read last_seen first,
                        # so a trap that bit again last week does not look a year stale.
root_cause: ""          # one line, distilled from the section below. Indexed for recurrence matching
summary: one-line summary (what went wrong)
---

# [error title]

## What happened (symptom)
<!-- observed symptom. Quote error messages verbatim -->

## Root cause
<!-- why it happened. Verified, not guessed -->

## How it was fixed
<!-- the fix. If unresolved, the next step -->

## Prevention (lesson)
<!-- how to avoid this next time. Promote to docs/skills if it is a general rule -->

## Recurrence history
<!-- One line per occurrence. Add a row instead of opening a new EXXXX when the root
     cause is the same, and bump `recurrence` / `last_seen` above.
     At recurrence 3 the document has stopped working: three repeats prove prose does
     not prevent this. Promote it to .agent-os/docs/ known-risks, or open a task for a
     mechanical gate (hook, lint, test). Recording a fourth line is not a response. -->
| date | how it surfaced | response |
|---|---|---|
