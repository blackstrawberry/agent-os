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

| Host | Entry point | Persistent project guidance | Mutation capability |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | full local mode |
| Codex | installed Skill/plugin, `$agent-os` | `AGENTS.md` | full local/Codex mode |
| ChatGPT Native | installed plugin or Skill when the current surface exposes it | plugin/Skill | depends on the concrete exposed actions + authorization |
| ChatGPT Project compatibility | `chatgpt/agent-os-chatgpt.md` + Project instructions | Project files/instructions | depends on connected tools/actions; Project mode alone is not a shell/runtime |

Skills select behavior by **capability**, not by product name. A connected app or GitHub source does not by itself prove read or write access: use only actions the current surface exposes and the current user is authorized to perform. Without a successful write action, agent-os prepares exact task/error/patch text but does not claim the repository changed.

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

Choose by **host**, then for ChatGPT by **intent first and capability second**. Plan names are useful hints, but the actual UI/actions available to your account or workspace are the source of truth.

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

First smoke request:

```text
Use agent-os to inspect related history and known risks before changing this repo.
```

### Codex — GitHub Skill install

Codex's built-in `$skill-installer` can install the canonical entry Skill directly from GitHub:

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

Restart Codex after installation. Then open an initialized project and either ask normally or invoke it explicitly:

```text
$agent-os inspect the related task, ADR, known risks and past errors before changing this repo
```

For a **new project**, the Skill alone is not the project scaffold:

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

For an existing agent-os project:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

That creates/updates `.agent-os/`, root `CLAUDE.md`, and root `AGENTS.md`. Codex automatically uses the project's `AGENTS.md`; the installed `agent-os` Skill supplies the reusable workflow entry point.

### ChatGPT — personal use (`Just me`)

Use the first path your current surface actually supports:

1. **Plugin Directory** — if **agent-os is actually listed** and your UI shows an install action, install it there. Do not assume directory visibility means this particular plugin is available.
2. **Native Skills** — if `Plugins -> Skills -> Create -> Upload from your computer` is available, install the canonical `skills/agent-os/` Skill using the upload format accepted by that surface. Native Skill upload is currently documented for eligible managed-workspace users; availability can change by account/workspace/surface.
3. **ChatGPT Project compatibility** — if the native paths are unavailable but Projects are available:
   - Create a new ChatGPT Project.
   - Upload **`chatgpt/agent-os-chatgpt.md`** from this public repository.
   - Open **`chatgpt/PROJECT_INSTRUCTIONS.md`** and copy its contents into the Project instructions.
   - Optionally connect GitHub or another app for live repository context. Inspect the actions actually exposed before treating the connection as readable or writable.
4. **No Projects either** — this surface is currently unsupported; do not fake an installation.

Project compatibility is intentionally smaller than Native Skills: its explicit profile includes `agent-os`, `task-scan`, `error-check`, and `error-log`. Local-only `agent-os-init` and `agent-os-archive` are not bundled because a Project does not inherently provide shell/hooks/local scripts.

First Project smoke request:

```text
Use agent-os for this broad request. Check known risks and the strongest related task/ADR/error history first. If search returns an ambiguous zero, use the directory/frontmatter fallback. Do not claim a repository write unless an authorized write action actually succeeds.
```

### ChatGPT — workspace/team distribution

If the goal is to distribute agent-os to a workspace, check admin intent **before** personal-install options.

If you are an authorized workspace admin and `Workspace settings -> Plugins -> Add -> Import marketplace` is available:

1. Source: `https://github.com/blackstrawberry/agent-os`
2. Leave Path empty for the repository-root `.agents/plugins/marketplace.json`.
3. Import the marketplace, then configure installation policy and any app/action permissions in the workspace.
4. GitHub marketplace sync distributes plugin content; it does **not** grant provider-account access or write permission by itself.

If marketplace import is unavailable or you are not an admin, use only the Native Skill/plugin/Project options actually allowed by workspace policy. Otherwise the surface is unsupported.

Current OpenAI references used for this chooser:
- Skills: https://help.openai.com/en/articles/20001066-skills-in-chatgpt
- Plugins: https://help.openai.com/en/articles/20001256-plugins-in-chatgpt-and-codex
- GitHub marketplace import: https://help.openai.com/en/articles/20001504-importing-and-syncing-plugin-marketplaces-from-github
- Projects: https://help.openai.com/en/articles/10169521-projects-in-chatgpt

These product surfaces can change; the decision rule is the capability you can actually see/use, not a hard-coded plan name.

## Initialize / migrate a project

The bundled installer creates `.agent-os/` and adds the **same marked protocol block** to root `CLAUDE.md` and `AGENTS.md`:

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
```

For an existing agent-os project:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

`--update` preserves all text outside the `<!-- agent-os:begin -->` / `<!-- agent-os:end -->` markers. A pre-0.8 Claude-only install is migrated by creating the missing `AGENTS.md`; malformed markers abort before either guidance file is partially rewritten.

After scaffolding:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. Fill `.agent-os/docs/` from a real repository scan.
3. Seed `.agent-os/prompts/eval/eval-set.md` with failures that actually happened.
4. Customize `.agent-os/vocab.txt` for the project's language and domain.

## Day to day

There is no required daily command. Talk normally; Skills or the Project compatibility instructions route the request.

| Say something like | What runs |
|---|---|
| "use agent-os for this repo" | `agent-os` |
| "write this up as a task" / "did we do this before?" | `task-scan` |
| "have I hit this mistake before?" | `error-check` |
| "log that mistake" | `error-log` |
| "initialize/update agent-os" | `agent-os-init` / `/agent-os:init` in Claude; local-capability path only |
| "clean up cold memory" | `agent-os-archive` / `/agent-os:archive` in Claude; local-capability path only |

Work is sized, not marched through: trivial goes straight to the answer; local work needs prior-error checking; broad work reads known risks, prior tasks/ADRs and relevant error history before implementation.

## Structure

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/{plugin.json,marketplace.json}
├── .codex-plugin/plugin.json
├── chatgpt/
│   ├── agent-os-chatgpt.md              # generated, ready to upload
│   └── PROJECT_INSTRUCTIONS.md          # generated, ready to copy
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
│   ├── build-chatgpt-project.sh
│   ├── chatgpt-project-test.sh
│   ├── init.sh
│   ├── host-adapter-test.sh
│   ├── reindex.sh rank.sh
│   ├── check-prompts.sh tags-gap.sh
│   ├── agent-os-compact.sh agent-os-health.sh
│   └── portability-test.sh
├── templates/
│   ├── chatgpt/{profile.txt,BUNDLE_HEADER.md,PROJECT_INSTRUCTIONS.md}
│   ├── AGENT_PROTOCOL.section.md        # canonical protocol
│   ├── CLAUDE.section.md
│   └── AGENTS.section.md
└── docs/
```

The lab repository dogfoods root `CLAUDE.md` and `AGENTS.md`, but those root files and `.agent-os/` are private development state. The public release ships only classified CORE paths, including the generated `chatgpt/` artifacts.

## Verification

For distribution changes:

```sh
sh scripts/host-adapter-test.sh
sh scripts/chatgpt-project-test.sh
```

`host-adapter-test.sh` preserves the Claude/Codex baseline: protocol drift, manifest name/version, convention hook behavior, shared Skill metadata, fresh init and migration. `chatgpt-project-test.sh` checks the explicit Project profile, deterministic rebuild, tracked-artifact drift, public provenance, size budget, private-lab leakage, capability guardrails, and missing-Skill fail-closed behavior. `portability-test.sh` remains the machine/awk/locale gate.

## Conventions

Operational Skills/templates/scripts are English-only. Localized README/Guide files explain the workflow; `.agent-os/` records only verified facts and never copies secrets.

## License

MIT — see [LICENSE](LICENSE).
