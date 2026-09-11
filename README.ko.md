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

| 호스트 | 진입점 | 지속 지침 | mutation capability |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | 로컬 full mode |
| Codex | 설치된 Skill/plugin, `$agent-os` | `AGENTS.md` | Codex/local full mode |
| ChatGPT Native | 현재 surface에서 설치 가능한 plugin/Skill | plugin/Skill | 실제 expose된 action + authorization에 따라 다름 |
| ChatGPT Project compatibility | `chatgpt/agent-os-chatgpt.md` + Project instructions | Project 파일/지침 | 연결된 도구/action에 따라 다름; Project 자체는 shell runtime이 아님 |

Skills는 제품명이 아니라 **실제 capability**로 모드를 고른다. GitHub나 다른 app이 연결됐다는 사실만으로 read/write를 추정하지 않는다. 현재 surface가 expose하고 사용자가 authorization된 action만 사용한다. 성공한 write action이 없으면 exact task/error/patch를 준비할 수는 있어도 실제 repo가 바뀌었다고 말하지 않는다.

## 설치

공개 저장소: **https://github.com/blackstrawberry/agent-os**

먼저 **호스트**, ChatGPT라면 **사용 목적(intent) → 실제 capability** 순서로 고른다. 플랜명은 참고 정보일 뿐 설치 라우터의 source of truth가 아니다.

### Claude Code — 플러그인 설치

Claude Code에 아래를 그대로 붙여넣는다.

```text
/plugin marketplace add blackstrawberry/agent-os
/plugin install agent-os@agent-os
/agent-os:init
```

`blackstrawberry/agent-os`는 Claude Code가 지원하는 GitHub `owner/repo` 단축형이다.

개발 checkout 직접 로드:

```sh
git clone https://github.com/blackstrawberry/agent-os.git
claude --plugin-dir "$(pwd)/agent-os"
```

첫 smoke:

```text
이 repo를 바꾸기 전에 agent-os로 관련 과거 기록과 known risks를 확인해줘.
```

### Codex — GitHub Skill 설치

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

설치 후 Codex를 재시작한다. 초기화된 프로젝트에서는 자연어 요청 또는 명시 호출이 가능하다.

```text
$agent-os 이 repo를 수정하기 전에 관련 task, ADR, known risks, 과거 error를 확인해줘
```

**새 프로젝트**는 Skill만 설치한다고 `.agent-os/`가 생기지 않는다.

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

기존 프로젝트 업데이트:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

Codex는 초기화된 repo의 root `AGENTS.md`를 자동으로 읽는다.

### ChatGPT — 개인 사용 (`나만 사용`)

현재 계정에서 **실제로 가능한 첫 경로**를 사용한다.

1. **Plugin Directory** — agent-os가 실제 목록에 있고 Install action이 보일 때만 설치한다. Directory가 보인다는 이유만으로 agent-os 설치 가능성을 가정하지 않는다.
2. **Native Skills** — `Plugins -> Skills -> Create -> Upload from your computer`가 보이면 canonical `skills/agent-os/` Skill을 해당 surface가 받는 형식으로 설치한다. Native Skill upload는 현재 eligible 관리형 workspace 사용자 중심으로 문서화되어 있으므로 availability는 계정/workspace/surface에 따라 달라질 수 있다.
3. **ChatGPT Project compatibility** — 위 native 경로가 없고 Projects가 있으면:
   - 새 ChatGPT Project 생성
   - 공개 repo의 **`chatgpt/agent-os-chatgpt.md`** 업로드
   - **`chatgpt/PROJECT_INSTRUCTIONS.md`** 내용을 Project instructions에 복사
   - 필요하면 GitHub/app을 연결하되 실제 expose된 action을 확인한 뒤 read/write 여부를 판단
4. **Projects도 없음** — 현재 surface는 unsupported. 설치된 것처럼 흉내 내지 않는다.

Project compatibility는 Native Skill보다 의도적으로 작다. 초기 profile은 `agent-os`, `task-scan`, `error-check`, `error-log`만 포함한다. `agent-os-init`/`agent-os-archive`는 Project 자체가 shell/hooks/local scripts를 제공하지 않으므로 포함하지 않는다.

첫 Project smoke:

```text
이 broad 요청에 agent-os를 사용해줘. known risks와 가장 관련 높은 task/ADR/error부터 확인하고, 검색 0건이 indexing 문제인지 불명확하면 directory/frontmatter fallback을 사용해. authorized write action이 실제 성공하지 않았다면 repo를 수정했다고 말하지 마.
```

### ChatGPT — workspace/team 배포

팀에 배포하려는 목적이라면 개인 설치보다 **관리자 배포 intent를 먼저** 본다.

권한 있는 workspace admin이고 `Workspace settings -> Plugins -> Add -> Import marketplace`가 보이면:

1. Source: `https://github.com/blackstrawberry/agent-os`
2. repository root의 `.agents/plugins/marketplace.json`을 쓰므로 Path는 비운다.
3. marketplace import 후 installation policy와 필요한 app/action 권한을 workspace에서 설정한다.
4. GitHub sync는 plugin content를 배포할 뿐 provider 계정 접근권한이나 write permission을 자동 부여하지 않는다.

Import marketplace가 없거나 admin이 아니라면 workspace policy가 실제 허용하는 Native Skill/plugin/Project 경로만 사용한다. 모두 없으면 unsupported다.

현재 확인한 OpenAI 문서:
- Skills: https://help.openai.com/en/articles/20001066-skills-in-chatgpt
- Plugins: https://help.openai.com/en/articles/20001256-plugins-in-chatgpt-and-codex
- GitHub marketplace import: https://help.openai.com/en/articles/20001504-importing-and-syncing-plugin-marketplaces-from-github
- Projects: https://help.openai.com/en/articles/10169521-projects-in-chatgpt

제품 UI와 정책은 바뀔 수 있으므로 플랜명을 hard-code하지 않고 실제 capability를 확인한다.

## 프로젝트 초기화 / 마이그레이션

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
bash /path/to/agent-os/scripts/init.sh --update /path/to/project
```

설치기는 `.agent-os/`를 만들고 같은 프로토콜 블록을 루트 `CLAUDE.md`와 `AGENTS.md`에 넣는다. `--update`는 marker 밖 사용자 텍스트를 보존한다. 기존 Claude-only 설치에서는 빠진 `AGENTS.md`를 생성한다. marker가 깨져 있으면 partial write 전에 중단한다.

초기화 후:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. 실제 repo 스캔으로 `.agent-os/docs/` 작성
3. 실제 실패 사례로 eval set 작성
4. 프로젝트 용어를 `.agent-os/vocab.txt`에 추가

## 일상 운영

| 이렇게 말하면 | 동작 |
|---|---|
| "이 repo에서 agent-os 써줘" | `agent-os` |
| "태스크로 정리 / 전에 했나?" | `task-scan` |
| "이 실수 전에 했나?" | `error-check` |
| "방금 실수 기록" | `error-log` |
| "agent-os 초기화/업데이트" | `agent-os-init` / Claude에서는 `/agent-os:init`; local capability 필요 |
| "콜드 메모리 정리" | `agent-os-archive` / Claude에서는 `/agent-os:archive`; local capability 필요 |

작업은 크기로 나눈다. trivial은 바로 처리, local은 과거 에러 확인, broad만 known-risks + prior task/ADR + error history를 먼저 읽는다.

## 구조

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/
├── .codex-plugin/plugin.json
├── chatgpt/
│   ├── agent-os-chatgpt.md              # generated, ready-to-upload
│   └── PROJECT_INSTRUCTIONS.md          # generated, ready-to-copy
├── skills/{agent-os,agent-os-init,agent-os-archive,task-scan,error-check,error-log}/
├── commands/                            # Claude 호환 어댑터
├── hooks/hooks.json
├── scripts/{build-chatgpt-project.sh,chatgpt-project-test.sh,...}
├── templates/chatgpt/{profile.txt,BUNDLE_HEADER.md,PROJECT_INSTRUCTIONS.md}
└── docs/
```

lab 저장소의 root `CLAUDE.md`/`AGENTS.md`와 `.agent-os/`는 dogfooding용 PRIVATE 상태다. 공개 `agent-os`에는 분류된 CORE와 generated `chatgpt/` artifact만 배포한다.

## 검증

```sh
sh scripts/host-adapter-test.sh
sh scripts/chatgpt-project-test.sh
```

`host-adapter-test.sh`는 Task 26의 Claude/Codex baseline을 유지한다. `chatgpt-project-test.sh`는 Project allowlist, deterministic build, tracked artifact drift, public provenance, size budget, private lab 누출, capability guardrail, missing-Skill fail-closed를 검사한다. OS/awk/locale 차이는 `portability-test.sh`가 담당한다.

## 라이선스

MIT — [LICENSE](LICENSE)
