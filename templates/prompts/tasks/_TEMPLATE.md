---
type: task
id: "00"                 # 2-digit number (matches the filename)
title: short-kebab-slug  # short identifier
status: planned          # planned | in-progress | completed | blocked | superseded
                         # Exactly one of these, nothing appended. Detail belongs in the body --
                         # a status like "planned, waiting on approval" is not greppable, and the
                         # linter rejects it. Note the hyphen: in-progress, not in_progress.
created: 2025-01-01       # YYYY-MM-DD (real date)
updated: 2025-01-01       # YYYY-MM-DD
tags: []                 # free keywords (for search)
keywords: []             # extra search keys, weight 3 like tags -- symptom words, error
                         # strings, library and symbol names. Separate from tags on purpose:
                         # tags are the shelf it sits on, keywords are what you would type.
area: []                 # code area (adapt per project): frontend | backend | api | db | common | infra | meta
pin: false               # true = never auto-archive (load-bearing / permanently relevant)
related_docs: []         # docs paths referenced
related_errors: []       # related error ids (EXXXX)
files:                   # source paths this task touched, comma separated -- rank.sh's
                         # strongest signal. `rank.sh -f <path>` surfaces this document
                         # when someone edits one of these, even with zero keyword hits.
                         # Leave it empty and the task is findable by wording only.
summary: one-line summary
---

# [task title]

## Request
<!-- the user's request, verbatim or summarized -->

## Scope / non-scope
<!-- what is and is not being done -->

## Plan
<!-- step by step -->

## Work log
<!-- record as you go: files touched, decisions, rationale -->

## Verification
<!-- how completion was confirmed (evidence) -->

## docs/skill sync
<!-- docs/skills updated by this task. If none, write "none" + why -->
