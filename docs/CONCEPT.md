# The idea behind agent-os

**Languages:** English | [한국어](CONCEPT.ko.md) | [日本語](CONCEPT.ja.md)

> Read this if you want to understand *why* agent-os is shaped this way -- and whether it fits your project.

## The problem

On a large, old, or ambiguous codebase, an AI agent loses intent. It re-derives context every session, repeats mistakes it already made, and trusts stale documentation until that documentation becomes actively misleading.

The bottleneck is usually not model intelligence. It is the absence of a durable structure that connects a new request to the right project knowledge.

A pile of raw history does not solve that. agent-os instead stores a small amount of structured procedural memory: what the project is, what decisions were made, what failed before, what risks are durable, and how an agent should retrieve only the relevant slice before acting.

## The model: four layers

```text
Foundation / adapters   canonical protocol + CLAUDE.md / AGENTS.md / installed Skills
Source of Truth          .agent-os/docs/
Skills                   skills/
Validation               .agent-os/prompts/eval/
```

### 1. Foundation / host adapters

There is one operating protocol, not one policy per AI product.

`templates/AGENT_PROTOCOL.section.md` is the canonical protocol source. Claude Code receives that protocol through root `CLAUDE.md`; Codex receives the same protocol through root `AGENTS.md`. ChatGPT does not assume repository `AGENTS.md` is automatically loaded, so its primary entry point is the installed `agent-os` Skill.

The adapters are deliberately thin. Product-specific loading rules change; project memory should not.

### 2. Source of Truth

`.agent-os/docs/` holds verified project knowledge: architecture, conventions, known risks, and ADRs. Code remains ground truth. If code and docs disagree, trust the code and fix the docs in the same writable change.

`07_known-risks.md` is special: incident documents describe what happened once; known-risks turns repeated or load-bearing lessons into rules that should be read before risky work.

### 3. Shared Skills

`skills/` is shared across Claude Code, Codex, ChatGPT, and other compatible hosts. The current package provides six Skills:

- `agent-os` -- main protocol/router
- `agent-os-init` -- initialize or update agent-os
- `agent-os-archive` -- preview/apply cold-memory archival
- `task-scan` -- retrieve related prior work and decisions
- `error-check` -- retrieve prior mistakes and known risks
- `error-log` -- record a new mistake or update a recurrence

Skills choose behavior by **capability**, not by product name. A host with shell + writes can use scripts and the full lifecycle; a repository-only host uses repository tools; a read-only host researches and proposes exact changes without pretending it committed anything.

### 4. Validation

`.agent-os/prompts/eval/` is the offline known-answer layer. Rules and retrieval changes should be checked against failures that actually occurred in the project. A rule that cannot be tested eventually becomes dead prompt weight.

## What agent-os installs and ships

A project initialized with agent-os receives:

- `.agent-os/prompts/tasks/` and `completed/` -- structured task memory
- `.agent-os/prompts/errors/` -- structured incident and recurrence memory
- `.agent-os/docs/` and `.agent-os/docs/adr/` -- source of truth and decisions
- `.agent-os/vocab.txt` -- project/domain/cross-language aliases
- `.agent-os/scripts/` -- ranking, indexing, linting, health, compaction, portability checks
- `.agent-os/scripts/hooks/pre-commit` -- opt-in mechanical gate
- root `CLAUDE.md` and `AGENTS.md` -- synchronized views of the same protocol

The distribution repository also ships the host adapters themselves:

- `.claude-plugin/` -- Claude Code packaging
- `.codex-plugin/` -- OpenAI/Codex packaging
- `.agents/plugins/marketplace.json` -- OpenAI marketplace metadata
- `skills/` -- the shared Skills above
- `commands/` -- Claude compatibility commands such as init/archive
- `hooks/hooks.json` -- convention-discovered session hook
- `templates/` -- canonical protocol and scaffold templates
- `scripts/host-adapter-test.sh` -- cross-host distribution fixture

The private development repository additionally keeps its own `.agent-os/`, root `CLAUDE.md`, and root `AGENTS.md` as dogfood state. Those paths are private and must not leak into the public distribution.

## The work protocol

Work is sized instead of forcing every request through the same ceremony.

- **Trivial** work: act directly.
- **Local** work: normally check relevant prior errors/risks first.
- **Broad** work: read known risks, retrieve related tasks/ADRs/errors, inspect the actual code, implement, synchronize docs, and close the task when verification is real.

The important property is bounded retrieval. agent-os should not dump the whole memory into context.

In shell-capable mode, `rank.sh` scores the generated index and the agent opens only the strongest few records. In repository mode, it searches frontmatter. If repository code search returns an ambiguous zero because the repository is unindexed or search is unavailable, it falls back to bounded directory/frontmatter inspection instead of concluding that no history exists.

## Memory: ranking instead of raw recall

`.agent-os/prompts/index.jsonl` is a generated catalog of task/error/ADR metadata. `rank.sh` orders candidates using query terms, project vocabulary, file paths, recurrence and other structured signals.

This matters because retrieval quality is mostly a ranking problem. Finding 50 possibly-related records is not success if the correct one is buried at position 37.

`vocab.txt` expands the **query**, not every document. That keeps cross-language and project-specific aliases cheap: one concept can map to Korean, Japanese, English, product names, legacy names, or abbreviations without retagging the corpus.

## Errors become durable prevention

An error record captures root cause, files, recurrence, severity and what fixed it. If the same root cause happens again, agent-os updates the existing record instead of creating a duplicate incident that hides recurrence.

Repeated lessons should move upward in abstraction:

```text
incident -> recurring error -> known risk / mechanical gate
```

The goal is not to accumulate prose forever. It is to turn expensive rediscovery into cheap prevention.

## Bounded memory and compaction

Old does not automatically mean cold. A completed/resolved document becomes a compaction candidate only when it is also unreferenced, unpinned and sufficiently inactive.

`agent-os-health.sh` reports stale indexes, cold candidates, stale open tasks, over-pinning, unpromoted recurrence and prompt-budget problems. `agent-os-archive` previews before applying. Nothing should disappear silently.

The full historical text remains recoverable from git even after active memory is compacted.

## Why the core is host-neutral

Claude Code, Codex and ChatGPT have different loading and execution surfaces:

- Claude Code naturally uses `CLAUDE.md` and Claude plugin commands.
- Codex naturally uses `AGENTS.md` and Skills.
- ChatGPT primarily enters through installed Skills and may expose anything from read-only repository access to richer writable environments.

Those are adapter differences, not reasons to fork project memory.

Keeping `.agent-os/` and `skills/` shared means one task, one error, one ADR and one durable lesson exist regardless of which agent handled the work. ADR-0004 records this as the long-term architecture decision.

## Distribution correctness matters too

The project has already seen failures where a gate existed but did not actually run, or where a convention hook was declared twice and broke plugin loading. Therefore cross-host compatibility is protected mechanically:

- canonical protocol / Claude / AGENTS drift checks
- fresh init and update-preservation fixtures
- malformed-marker negative fixture
- Skill metadata checks
- Claude/OpenAI manifest name/version sync
- convention-hook duplicate checks
- public-release private-path leak checks

A green check is useful only when a negative fixture proves that the check can fail.

## Design principles

1. **Code is ground truth; docs are source of truth.** Fix stale docs when code proves them wrong.
2. **Frontmatter makes memory scannable.** Structured fields are cheaper to route than prose.
3. **Rank, then open a few.** More recall is not the same as better retrieval.
4. **The agent records its own mistakes.** Repeated root causes must become visible recurrence.
5. **Promote durable lessons.** Incidents should eventually become known risks or gates.
6. **Capability-first, not product-name-first.** Use what the active host can really read, write and execute.
7. **One core, thin adapters.** Do not maintain Claude/OpenAI forks of the same memory.
8. **A gate must prove it ran.** Positive-only verification is not enough.
9. **Memory is bounded.** Archive cold material without deleting recoverability.
10. **Everything is maintainable, including the protocol and Skills.** Replace obsolete rules instead of only appending new ones.

## Why it generalizes

Nothing in the memory model depends on a programming language or framework. Any repository large enough to lose context, old enough to have accumulated traps, or important enough that repeated mistakes are expensive can benefit from a verified source of truth, structured task/error memory, bounded retrieval and mechanical synchronization.

agent-os is not another model memory service. It is a repository-local operating discipline that lets different agents share the same verified project memory.

## Credit

The emphasis on structured procedural knowledge over raw history is inspired in part by Anthropic's writing on building reusable agent Skills. agent-os applies that idea to repository work while keeping the memory and operating protocol independent of any single host.