# agent-os

**Languages:** English | [한국어](README.ko.md) | [日本語](README.ja.md)

A **host-independent agent operating system** for legacy / high-ambiguity codebases — packaged for Claude Code, Codex, and ChatGPT.

On a big or old codebase, an AI agent's intent leaks: it assumes instead of verifying, repeats past mistakes, and lets docs rot. agent-os fixes the *structure*, not the model. The durable memory lives in `.agent-os/`; each host gets a thin adapter that points at the same tasks, errors, decisions, source-of-truth docs, ranking, and maintenance rules.

> **How to use it:** start with the **[Operating Guide](docs/GUIDE.md)**. The rationale is in **[docs/CONCEPT.md](docs/CONCEPT.md)**.

## Core idea

- **Foundation**: one canonical operating protocol. Claude Code reads it through root `CLAUDE.md`; Codex reads the same protocol through root `AGENTS.md`.
- **Source of Truth** (`.agent-os/docs/`): verified system knowledge. Code is ground truth; when docs disagree, verify code and fix the docs.
- **Skills**: shared across hosts — `agent-os`, `agent-os-init`, `agent-os-archive`, `task-scan`, `error-check`, `error-log`.
- **Validation** (`.agent-os/prompts/eval/`): known-answer cases that tell you whether a rule still earns its place.

## Host support

| Host | Entry point | Persistent project guidance | Repository writes |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | full local mode |
| Codex | installed Skill/plugin, `$agent-os` | `AGENTS.md` | full local/Codex mode |
| ChatGPT | installed Skill such as `agent-os` | Skills are the primary entry point; do **not** assume repository `AGENTS.md` is auto-loaded | capability-dependent; the ordinary GitHub app is read-only |

Skills select behavior by **capability**, not by product name. With shell + writable files they run full mode. With repository write actions but no shell they reproduce the same lifecycle using repository tools. With read-only repository access they research prior work/risks and prepare exact task/error updates without claiming those updates were written.

## What you get

- **Ranking, not scanning.** `rank.sh` scores the index and the skills open only the strongest few results.
- **File paths are a first-class signal.** A past error about a file you are about to touch can surface with zero keyword overlap.
- **Cross-language retrieval.** `.agent-os/vocab.txt` expands the query instead of retagging every old document.
- **Recurrence counting.** The same root cause bumps one record; at recurrence 3, prose is no longer enough — promote a known risk or build a mechanical gate.
- **Decision records** (`.agent-os/docs/adr/`): rejected alternatives plus explicit revisit conditions.
- **Bounded memory.** Cold finished/unreferenced/unpinned docs can be archived after durable lessons are promoted.
- **Health checks.** Detect stale indexes, rotting tasks, over-pinning, empty evals and prompt-budget drift.

## Install

Public repository: **https://github.com/blackstrawberry/agent-os**

### Claude Code — plugin install

Paste these directly into Claude Code:

```text
/plugin marketplace add blackstrawberry/agent-os
/plugin install agent-os@agent-os
/agent-os:init
```

`blackstrawberry/agent-os` is Claude Code's supported GitHub `owner/repo` shorthand. A full `https://github.com/...git` URL is **not required** for GitHub repositories; full Git URLs are also supported when needed, including non-GitHub hosts.

Development checkout:

```sh
git clone https://github.com/blackstrawberry/agent-os.git
claude --plugin-dir "$(pwd)/agent-os"
```

### Codex — GitHub Skill install

Codex's built-in `$skill-installer` can install a Skill directly from a GitHub directory. For the minimal agent-os entry point, paste this into Codex:

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

Restart Codex after installation. Then open an initialized project and either say your request normally or invoke the Skill explicitly:

```text
$agent-os inspect the related task, ADR, known risks and past errors before changing this repo
```

For a **new project**, the Skill alone is not the project scaffold. Clone the public repository once and run the installer:

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

For an existing agent-os project:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

That creates/updates `.agent-os/`, root `CLAUDE.md`, and root `AGENTS.md`. Codex automatically uses the project's `AGENTS.md`; the installed `agent-os` Skill supplies the reusable routing/workflow entry point.

If **agent-os** is available in your Codex Plugins directory or through a workspace-imported marketplace, you can install the plugin there instead; the Skill-only GitHub route above is the portable public-repo path.

### ChatGPT — Skill install

If your ChatGPT Skills surface supports uploads, download the repository and upload the **`skills/agent-os/` folder** as one Skill:

- Repository: https://github.com/blackstrawberry/agent-os
- ZIP: https://github.com/blackstrawberry/agent-os/archive/refs/heads/main.zip
- Skill folder: `skills/agent-os/`

For workspace-managed plugin distribution, an eligible admin can import the GitHub marketplace from `https://github.com/blackstrawberry/agent-os` and keep it synchronized from GitHub. Availability depends on the workspace/product surface.

After installation, a normal request may route to agent-os implicitly. ChatGPT should enter through the installed Skill; a plain GitHub connection is not treated as writable project state.

## Initialize / migrate a project

The bundled installer creates `.agent-os/` and adds the **same marked protocol block** to root `CLAUDE.md` and `AGENTS.md`:

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
```

For an existing agent-os project:

```sh
bash /path/to/agent-os/scripts/init.sh --update /path/to/project
```

`--update` preserves all text outside the `<!-- agent-os:begin -->` / `<!-- agent-os:end -->` markers. A pre-0.8 Claude-only install is migrated by creating the missing `AGENTS.md`; malformed markers abort before either guidance file is partially rewritten.

After scaffolding:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. Fill `.agent-os/docs/` from a real repository scan.
3. Seed `.agent-os/prompts/eval/eval-set.md` with failures that actually happened.
4. Customize `.agent-os/vocab.txt` for the project's language and domain.

## Day to day

There is no required daily command. Talk normally; Skills route the request.

| Say something like | What runs |
|---|---|
| "use agent-os for this repo" | `agent-os` |
| "write this up as a task" / "did we do this before?" | `task-scan` |
| "have I hit this mistake before?" | `error-check` |
| "log that mistake" | `error-log` |
| "initialize/update agent-os" | `agent-os-init` / `/agent-os:init` in Claude |
| "clean up cold memory" | `agent-os-archive` / `/agent-os:archive` in Claude |

Work is sized, not marched through: trivial goes straight to the answer; local work needs prior-error checking; broad work reads known risks, prior tasks/ADRs and relevant error history before implementation.

## Structure

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/{plugin.json,marketplace.json}
├── .codex-plugin/plugin.json
├── skills/
│   ├── agent-os/SKILL.md
│   ├── agent-os-init/SKILL.md
│   ├── agent-os-archive/SKILL.md
│   ├── task-scan/SKILL.md
│   ├── error-check/SKILL.md
│   └── error-log/SKILL.md
├── commands/{init.md,archive.md}        # Claude compatibility adapters
├── hooks/hooks.json                     # convention hook for plugin hosts
├── scripts/
│   ├── init.sh
│   ├── host-adapter-test.sh
│   ├── reindex.sh rank.sh
│   ├── check-prompts.sh tags-gap.sh
│   ├── agent-os-compact.sh agent-os-health.sh
│   └── portability-test.sh
├── templates/
│   ├── AGENT_PROTOCOL.section.md        # canonical protocol
│   ├── CLAUDE.section.md
│   └── AGENTS.section.md
└── docs/
```

The lab repository dogfoods root `CLAUDE.md` and `AGENTS.md`, but those root files are private development state. The public release ships the templates and adapters, not the lab's project memory.

## Verification

For distribution changes:

```sh
sh scripts/host-adapter-test.sh
```

It checks protocol drift, Claude/OpenAI manifest name+version drift, shared Skill metadata, fresh init, Claude-only migration, outside-marker preservation and malformed-marker fail-closed behavior. `portability-test.sh` remains the machine/awk/locale gate for project scripts.

## Conventions

Operational Skills/templates/scripts are English-only. Localized README/Guide files explain the workflow; `.agent-os/` records only verified facts and never copies secrets.

## License

MIT — see [LICENSE](LICENSE).
