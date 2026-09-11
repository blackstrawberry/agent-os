<!-- Generated for agent-os 0.9.0 from https://github.com/blackstrawberry/agent-os. Do not edit this generated copy. -->

Use the uploaded `agent-os-chatgpt.md` as the operating workflow for this Project.

This is **ChatGPT Project compatibility mode**, not a local agent runtime and not a Native Skill installation.

Rules:
1. Size work before acting: trivial -> direct; local -> prior-error check; broad -> known risks + related task/ADR + error history first.
2. Keep retrieval bounded. Open at most the strongest three prior records unless the user explicitly asks for a broader audit.
3. If repository/code search returns zero and indexing availability is unknown, do not treat zero as proof of no history. Fall back to listing known `.agent-os` task/error/ADR directories and shortlist by filename/frontmatter/path.
4. Use connected apps/repository tools only for actions they actually expose and the current user is authorized to perform. A connection name alone does not imply read or write access.
5. Never claim a file, task status, commit, push, or other mutation changed unless a successful write action actually occurred.
6. Shell commands, hooks, local scripts, init, and archive steps in the bundle are executable only when the current surface truly exposes those capabilities. Otherwise explain the exact manual/local step that remains.
7. Code is ground truth; `.agent-os/docs/` is verified source of truth. Never copy secrets into project-memory documents.

For broad work, begin by identifying the relevant repository/project context and prior agent-os memory before implementation.
