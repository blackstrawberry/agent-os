# agent-os

**언어:** [English](README.md) | 한국어 | [日本語](README.ja.md)

레거시/모호한 코드베이스를 위한 **호스트 독립형 에이전트 운영 체계**. Claude Code, Codex, ChatGPT에서 같은 프로젝트 메모리를 공유한다.

agent-os의 본체는 특정 모델이 아니라 `.agent-os/`다. 태스크·에러·ADR·Source of Truth·랭킹·메모리 유지 규칙은 하나만 두고, Claude/Codex/ChatGPT는 얇은 어댑터로 같은 정보를 읽는다.

> **운영법:** [운영 가이드](docs/GUIDE.ko.md) · 배경: [CONCEPT](docs/CONCEPT.ko.md)

## 핵심 구조

- **Foundation**: canonical 프로토콜 하나. Claude Code는 루트 `CLAUDE.md`, Codex는 같은 내용을 담은 `AGENTS.md`로 읽는다.
- **Source of Truth**: `.agent-os/docs/`. 코드가 ground truth이며 문서와 다르면 코드를 확인한 뒤 문서를 고친다.
- **공용 Skills**: `agent-os`, `agent-os-init`, `agent-os-archive`, `task-scan`, `error-check`, `error-log`.
- **Validation**: `.agent-os/prompts/eval/`의 known-answer 세트로 규칙의 실효성을 측정한다.

## 호스트 지원

| 호스트 | 진입점 | 지속 지침 | 쓰기 능력 |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init` | `CLAUDE.md` | 로컬 full mode |
| Codex | `.codex-plugin/`, `$agent-os-init`, `$agent-os` | `AGENTS.md` | Codex/local full mode |
| ChatGPT | 설치된 Skill (`@agent-os` 등) | Skill이 기본 진입점. repo `AGENTS.md` 자동 로드를 전제로 하지 않음 | 연결된 도구 능력에 따라 다름; 일반 GitHub app은 read-only |

Skills는 제품명이 아니라 **실제 capability**로 모드를 고른다. shell+쓰기 가능하면 full mode, repo write만 있으면 repository mode, 읽기만 가능하면 prior task/error/known-risk 조사와 정확한 수정안까지만 만들고 실제로 썼다고 말하지 않는다.

## 설치

### Claude Code

```text
/plugin marketplace add <owner>/<repo>
/plugin install agent-os@agent-os
/agent-os:init
```

개발 checkout 직접 로드:

```text
claude --plugin-dir /absolute/path/to/agent-os
```

### Codex / ChatGPT

OpenAI용 native manifest는 `.codex-plugin/plugin.json`, marketplace descriptor는 `.agents/plugins/marketplace.json`에 있다. 지원되는 ChatGPT/Codex Plugin 화면에서 이 repository/marketplace를 추가·설치한 뒤:

```text
Codex:   $agent-os-init
ChatGPT: @agent-os-init
```

Codex는 작업 전에 root `AGENTS.md`를 읽는다. ChatGPT는 설치된 Skills가 주 진입점이며, GitHub만 연결된 일반 채팅은 repository write가 가능하다고 가정하지 않는다.

## 프로젝트 초기화 / 마이그레이션

```sh
bash <plugin>/scripts/init.sh [--no-eval] /path/to/project
bash <plugin>/scripts/init.sh --update /path/to/project
```

설치기는 `.agent-os/`를 만들고 **같은 프로토콜 블록**을 루트 `CLAUDE.md`와 `AGENTS.md`에 넣는다. `--update`는 marker 밖 사용자 텍스트를 보존한다. 기존 Claude-only 설치에서는 빠진 `AGENTS.md`를 생성한다. marker가 깨져 있으면 한쪽만 업데이트한 상태로 남기지 않고 중단한다.

초기화 후:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. 실제 repo 스캔으로 `.agent-os/docs/` 작성
3. 실제로 물린 사례로 eval set 작성
4. 프로젝트 용어를 `.agent-os/vocab.txt`에 추가

## 일상 운영

| 이렇게 말하면 | 동작 |
|---|---|
| "이 repo에서 agent-os 써줘" | `agent-os` |
| "태스크로 정리 / 전에 했나?" | `task-scan` |
| "이 실수 전에 했나?" | `error-check` |
| "방금 실수 기록" | `error-log` |
| "agent-os 초기화/업데이트" | `agent-os-init` |
| "콜드 메모리 정리" | `agent-os-archive` |

작업은 크기로 나눈다. trivial은 바로 처리, local은 과거 에러 확인, broad만 known-risks + prior task/ADR + error history를 먼저 읽는다.

## 구조

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/
├── .codex-plugin/plugin.json
├── skills/{agent-os,agent-os-init,agent-os-archive,task-scan,error-check,error-log}/
├── commands/                  # Claude 호환 어댑터
├── hooks/hooks.json
├── scripts/
├── templates/
│   ├── AGENT_PROTOCOL.section.md
│   ├── CLAUDE.section.md
│   └── AGENTS.section.md
└── docs/
```

lab 저장소의 루트 `CLAUDE.md`/`AGENTS.md`는 dogfooding용 PRIVATE 상태다. 공개 `agent-os`에는 template/adapter만 배포한다.

## 검증

```sh
sh scripts/host-adapter-test.sh
```

protocol drift, Claude/OpenAI manifest name·version 불일치, Skill metadata, fresh init, Claude-only migration, marker 밖 텍스트 보존, malformed marker fail-closed를 검사한다. OS/awk/locale 차이는 기존 `portability-test.sh`가 담당한다.

## 라이선스

MIT — [LICENSE](LICENSE)
