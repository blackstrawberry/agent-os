---
type: adr
id: ADR-0001            # ADR- + 4 digits (matches the filename)
title: short-kebab-slug
date: 2025-01-01         # YYYY-MM-DD (real date)
status: accepted        # proposed | accepted | superseded | reverted
supersedes: ""          # the ADR id this overturns, if any
area: []                # same vocabulary as tasks and errors
tags: []                # search keys. Include the names of the REJECTED options --
                        # someone about to re-propose one will search for it by name
summary: one-line statement of what was decided
---

# [decision title]

## Context
<!-- What had to be decided, and what made it a decision rather than a default.
     Enough for someone who was not there. -->

## Decision
<!-- What was chosen. Present tense: "X is used", not "we will use X". -->

## Rejected alternatives
<!-- THE REASON THIS DOCUMENT EXISTS.
     One block per option that was seriously considered and dropped:
       - the option, named the way someone would propose it
       - why it was dropped -- the actual reason, not a summary
       - what it would have cost or bought
     A rejection recorded only inside a task or an error document is invisible to the
     next person, who then proposes it again. That has already happened here. -->

## Revisit when
<!-- THE OTHER REASON.
     Name the condition that should reopen this: "the same failure recurs twice",
     "the dataset passes 10M rows", "the vendor ships a supported API".
     Without a condition, a deferral silently becomes permanent -- which is how a
     "postponed for now" decision turns into a rule nobody remembers choosing.
     If a recurrence count is the trigger, say the number; the error `recurrence`
     field then becomes the trigger automatically. -->

## Consequences
<!-- What this costs, what it locks in, what becomes harder. Honest, not a sales pitch. -->
