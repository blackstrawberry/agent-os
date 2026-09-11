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
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | 로컬 full mode |
| Codex | 설치된 Skill/plugin, `$agent-os` | `AGENTS.md` | Codex/local full mode |
| ChatGPT | 설치된 Skill (`agent-os` 등) | Skill이 기본 진입점. repo `AGENTS.md` 자동 로드를 전제로 하지 않음 | 연결된 도구 능력에 따라 다름; 일반 GitHub app은 read-only |

Skills는 제품명이 아니라 **실제 capability**로 모드를 고른다. shell+쓰기 가능하면 full mode, repo write만 있으면 repository mode, 읽기만 가능하면 prior task/error/known-risk 조사와 정확한 수정안까지만 만들고 실제로 썼다고 말하지 않는다.

## 설치

공개 저장소: **https://github.com/blackstrawberry/agent-os**

### Claude Code — 플러그인 설치

Claude Code에 아래를 그대로 붙여넣으면 된다.

```text
/plugin marketplace add blackstrawberry/agent-os
/plugin install agent-os@agent-os
/agent-os:init
```

`blackstrawberry/agent-os`는 Claude Code가 공식 지원하는 GitHub `owner/repo` 단축형이다. GitHub 저장소에서는 `https://github.com/...git` 전체 주소가 **필수는 아니며**, GitHub가 아닌 Git 서버 등을 사용할 때는 전체 Git URL을 사용할 수 있다.

개발 checkout을 직접 로드하려면:

```sh
git clone https://github.com/blackstrawberry/agent-os.git
claude --plugin-dir "$(pwd)/agent-os"
```

### Codex — GitHub Skill 설치

Codex의 기본 `$skill-installer`는 GitHub의 Skill 디렉터리 URL을 직접 설치할 수 있다. 최소 구성으로 agent-os 진입점만 설치하려면 Codex에 아래를 그대로 붙여넣는다.

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

설치 후 Codex를 재시작한다. 그 다음 초기화된 프로젝트를 열고 평소처럼 요청하거나 명시적으로 호출할 수 있다.

```text
$agent-os 이 repo를 수정하기 전에 관련 task, ADR, known risks, 과거 error를 확인해줘
```

**새 프로젝트**라면 Skill 설치만으로 `.agent-os/` 구조가 생기는 것은 아니다. 공개 저장소를 한 번 clone한 뒤 installer를 실행한다.

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

기존 agent-os 프로젝트를 업데이트하려면:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

이 과정에서 `.agent-os/`, 루트 `CLAUDE.md`, 루트 `AGENTS.md`가 생성/갱신된다. Codex는 프로젝트의 `AGENTS.md`를 자동으로 읽고, 설치한 `agent-os` Skill은 재사용 가능한 라우팅/운영 진입점 역할을 한다.

Codex의 Plugins 화면이나 workspace marketplace에서 **agent-os**가 제공되는 환경이라면 거기서 플러그인 전체를 설치해도 된다. 위 GitHub Skill 경로는 public repo에서 바로 쓸 수 있는 이식성 높은 경로다.

### ChatGPT — Skill 설치

현재 ChatGPT의 Skills 화면에서 업로드를 지원하는 계정이라면 공개 저장소를 내려받아 **`skills/agent-os/` 폴더 하나**를 Skill로 업로드한다.

- 저장소: https://github.com/blackstrawberry/agent-os
- ZIP: https://github.com/blackstrawberry/agent-os/archive/refs/heads/main.zip
- 업로드할 폴더: `skills/agent-os/`

workspace 관리형 배포에서는 권한이 있는 관리자가 `https://github.com/blackstrawberry/agent-os` GitHub marketplace를 import해 GitHub와 동기화할 수 있다. 실제 메뉴/권한은 workspace와 product surface에 따라 다르다.

설치 후에는 평범한 요청도 agent-os로 implicit routing될 수 있다. ChatGPT는 설치된 Skill이 주 진입점이며, GitHub만 연결된 일반 채팅을 writable project state로 간주하지 않는다.

## 프로젝트 초기화 / 마이그레이션

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
bash /path/to/agent-os/scripts/init.sh --update /path/to/project
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
| "agent-os 초기화/업데이트" | `agent-os-init` / Claude에서는 `/agent-os:init` |
| "콜드 메모리 정리" | `agent-os-archive` / Claude에서는 `/agent-os:archive` |

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
