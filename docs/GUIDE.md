# agent-os — Operating Guide

**Languages:** English | [한국어](GUIDE.ko.md) | [日本語](GUIDE.ja.md)

agent-os is not a one-shot tool. It is a **human-in-the-loop cycle**: you set it up once, then every request flows through the same loop so the agent stays on-intent and the project's knowledge compounds instead of rotting.

```
                          ┌──────────────────────────────────────────────┐
                          v                                              │
  SETUP (once) ──>  1.FRAME ──> 2.REVIEW PLAN ──> 3.EXECUTE ──> 4.REVIEW ─┘
                    (task)       (human gate)      (agent)      RESULT
                                                              5.SELF-IMPROVE
                                                                 + SYNC
                                                              6.CLOSE task
                                                              7.MAINTAIN
                                                                (compact)
  legend:  human = you set direction & approve;  agent = does the work
```

---

## 0. Setup (once per project)

1. **Install** the plugin:
   ```
   /plugin marketplace add /path/to/agent-os-plugin
   /plugin install agent-os@agent-os
   ```
2. **Scaffold** the structure into the repo: `/agent-os:init` (the eval set is included; `--no-eval` skips it). Already have agent-os? `sh <plugin>/scripts/init.sh --update .` refreshes only the protocol block in your `CLAUDE.md` and leaves everything outside the markers alone.
3. **Enable forced sync** (recommended): `git config core.hooksPath .agent-os/scripts/hooks`.
4. **Build the Source of Truth** — the most important step. Ask the agent to scan the whole repo and fill `.agent-os/docs/01..07` (overview, architecture, directory map, core, data layer, conventions, known risks). **You review it once.** Everything downstream trusts `.agent-os/docs/`, so a wrong doc here poisons later work. Write only verified facts.
5. **Fill the eval set** — five rows in `.agent-os/prompts/eval/eval-set.md`, taken from what has actually bitten this project. Skipping this is the common failure: measured across 19 installs, 17 never filled it in, and without it you can never tell whether a rule is still earning its place.
6. **Trim `.agent-os/vocab.txt`** to the axes this project uses, and add its own. This is what lets a question in one language reach documents written in another.

After this, the project has: `CLAUDE.md` (the protocol), `.agent-os/docs/` (truth), `.agent-os/prompts/` (memory), `vocab.txt` (the alias map), the skills, and the hook.

---

## 1. The cycle (per request)

Roles: **[H]** = you (human), **[A]** = the agent.

### Step 0 — Size it  [A]
Not every request deserves the whole loop. **Trivial** (a commit, one command, a one-line answer) is answered directly. **Local** (one file, a clear bug) needs only `error-check`. Only **broad** work — many files, a design change, a new feature — runs steps 1 to 6. The old binary sent every medium job through the full course, which is how a protocol earns a reputation for being slow.

### Step 1 — Frame the task  [H states -> A writes]
You state the request in plain language. The agent then:
- runs **task-scan**, which *ranks* rather than scans: `rank.sh` scores every index entry and the agent opens the top 3. Passing the paths it is about to touch (`-f`) surfaces a past error about one of them even with no keyword match,
- reads a **decision record** first if one comes back — someone already rejected an option here, and its *Revisit when* says whether that still holds,
- reads the relevant **`.agent-os/docs/`**, starting with `07_known-risks.md`,
- runs **error-check** (did we trip on this before?),
- writes `.agent-os/prompts/tasks/NN_slug.md` with **Request / Scope-non-scope / Plan** filled in — `tags` included, because an untagged document is one the ranker cannot find later.

### Step 2 — Review the plan  [H GATE]
Read the task doc's **Scope** and **Plan**. This is the cheapest place to fix misunderstanding. Correct the scope, reject bad assumptions, or approve. Do not let execution start on a wrong frame.

### Step 3 — Execute  [A]
The agent implements per the plan, recording decisions and touched files in the **Work log**. It runs **error-check** again before risky steps (shared core, DB, migrations) and verifies its own work (build/lint/tests).

### Step 4 — Review the result  [H GATE]
Read the **Verification** section and the diff. Accept, or send it back with feedback. For anything irreversible or outward-facing (deploys, deletions, credentials, external calls) the agent must stop and ask here regardless.

### Step 5 — Self-improve + sync  [A]
Before closing, the agent:
- updates **`.agent-os/docs/`** for any changed behavior/structure (Source-of-Truth sync — the hook warns if code changed without docs),
- if a procedure recurred, proposes a **new skill** or updates an existing one,
- if it made a mistake, runs **error-log** — which searches *before* filing. The same root cause bumps the existing document's `recurrence` and `last_seen` instead of opening a second one; two files for one trap make a three-time trap look like three one-offs.
- **at `recurrence` 3, editing the document is no longer an acceptable response.** Three repeats are evidence that prose does not prevent this. The lesson is promoted to `.agent-os/docs/07_known-risks.md`, or a task is opened for a mechanical gate — a hook, a lint rule, a test.
- if an alternative was seriously considered and dropped, and reversing would be expensive, writes a **decision record** in `.agent-os/docs/adr/` — with what was rejected and what would reopen it.

This is what makes the system get *better* each loop instead of just bigger.

### Step 6 — Close the task  [A]
Set frontmatter `status: completed`, move the file to `.agent-os/prompts/tasks/completed/`, fill `related_docs`/`related_errors`. The index refreshes; commit (the pre-commit hook lints frontmatter and warns on missing doc sync).

### Step 7 — Maintain  [H when nudged]
`agent-os-health.sh` is what breaks the silence. It reports an index older than the documents it catalogues, open tasks nobody has touched in 30 days, over-pinning (`pin` means load-bearing forever, not important — over-pin and cold detection stops working at all), repeats that never became rules, an empty eval set, and a protocol block that has outgrown its budget. It is **read-only**: it tells you to reindex, it never does it.

When it says memory is large, run **`/agent-os:archive`** (it previews cold docs, then archives on your OK). Cold = finished AND unreferenced AND unpinned AND old — never by age alone. **Promote the lesson to known-risks first**: archive an un-promoted lesson and it is gone; keep everything instead and the index grows until nobody scans it. Promotion is the only exit.

Then the next request starts the loop again.

---

## 2. Human-in-the-loop checkpoints

You must be in the loop at these points; the rest is the agent's to run:

| When | Why |
|---|---|
| Initial `.agent-os/docs/` sign-off (setup) | Everything trusts the source of truth |
| Plan review (step 2) | Fix misframing before it costs work |
| Result review (step 4) | Catch wrong/incomplete output |
| Irreversible / outward actions | Deploys, deletes, credentials, external services |
| Compaction apply (step 7) | Confirm what leaves the active set |
| Security decisions | e.g. credential rotation, exposed tools |

---

## 3. Worked example (real)

Request: *"the club detail page shows different buy/sell status than the list page; make them match."*

1. **Frame**: `task-scan` finds no prior task; agent reads `.agent-os/docs/` for the list module; `error-check` clean. Writes `.agent-os/prompts/tasks/04_buysell-detail-status-mismatch.md` with root-cause analysis in the Plan.
2. **Review plan** [H]: you confirm the root cause (detail's row-selection omits the status field) and scope (PC + mobile twin).
3. **Execute** [A]: edits both files; `php -l` + a logic simulation prove old vs new behavior.
4. **Review result** [H]: live render verification is environment-gated, so it is flagged as pending; you decide.
5. **Self-improve + sync** [A]: writes `.agent-os/docs/08_list-module.md` (new module doc) + updates the data-layer doc; notes the legacy trap.
6. **Close**: task moves to `completed/` (or stays `in-progress` until live-verified).

The point: the request did not just get "done" — the codebase's source of truth grew, and the next person/agent inherits it.

---

## 4. Maintenance cadence

- **Docs sync**: every behavior/structure change, in the same task. Enforced by the pre-commit warning.
- **Compaction**: when nudged (index size / cold count vs thresholds). Roll recurring error lessons into `.agent-os/docs/` *before* archiving.
- **Eval**: after editing skills/docs, run the `.agent-os/prompts/eval` questions to confirm the agent still answers the project's traps correctly.
- **Bare test** (once per model generation): run the eval set with the protocol block commented out, then with it on, and compare. See [`scripts/bare-test.md`](../scripts/bare-test.md). This is the only thing that ever justifies *deleting* a rule — and a no-difference result is the finding, not a failed experiment. Rules only accumulate otherwise.
- **Vocabulary**: when a search that should have hit comes back empty, add the missing word to `vocab.txt`. Never retag old documents to match a query.
- **Tags**: `tags-gap.sh` lists documents nothing can find because their tags are empty. It only reports — a wrong tag in the highest-weighted field is worse than a gap.
- **Skills are not frozen**: when a path/schema drifts, fix the skill that references it in the same change.

---

## 5. Cheatsheet

| Thing | What it is |
|---|---|
| `/agent-os:init [--no-eval]` | scaffold the structure into a project |
| `init.sh --update` | refresh only the protocol block in an existing `CLAUDE.md` |
| `/agent-os:archive [--apply]` | archive cold docs (preview, then apply) |
| skill `task-scan` | find related prior work + rejected decisions, route to docs |
| skill `error-check` | check past mistakes before working |
| skill `error-log` | the agent records its own mistakes (search first, count recurrences) |
| `CLAUDE.md` | the always-loaded work protocol (budget: 3000 chars) |
| `.agent-os/docs/` | source of truth (you fill it from a real scan) |
| `.agent-os/docs/07_known-risks.md` | the traps, as rules. Read before working |
| `.agent-os/docs/adr/` | decisions: what was rejected, what would reopen it |
| `.agent-os/vocab.txt` | concept → its spellings across languages |
| `.agent-os/prompts/tasks/` `errors/` | the working memory (frontmatter docs) |
| `.agent-os/prompts/eval/eval-set.md` | five known-answer questions; the only rule-lifetime instrument |
| `.agent-os/prompts/index.jsonl` | generated catalog the ranker reads |
| `rank.sh -q "..." -f "paths"` | **the way to find things.** Top few, not everything |
| `reindex.sh` | rebuild the index |
| `check-prompts.sh [--report]` | frontmatter lint; `--report` never fails |
| `tags-gap.sh` | documents nothing can find (tags empty) |
| `agent-os-health.sh [--oneline]` | what has gone quiet. Read-only |
| `bare-test.md` | is this harness still earning its place? |
| `git config core.hooksPath .agent-os/scripts/hooks` | turn on forced sync |

See [CONCEPT.md](CONCEPT.md) for *why* it is built this way.
