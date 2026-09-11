# agent-os의 핵심 아이디어

**언어:** [English](CONCEPT.md) | 한국어 | [日本語](CONCEPT.ja.md)

> agent-os가 *왜* 이런 구조인지, 그리고 내 프로젝트에 맞는지 판단하고 싶다면 읽는 문서.

## 문제

크고 오래됐거나 애매성이 높은 코드베이스에서 AI 에이전트는 의도를 잃기 쉽다. 세션마다 같은 맥락을 다시 만들고, 이미 했던 실수를 반복하고, 오래된 문서를 믿다가 오히려 잘못된 방향으로 간다.

대부분의 병목은 모델의 지능이 아니라 **새 요청을 올바른 프로젝트 지식에 연결하는 지속 가능한 구조의 부재**다.

과거 대화나 커밋을 전부 쌓아두는 것만으로는 해결되지 않는다. agent-os는 대신 다음을 구조화해서 저장한다: 프로젝트의 검증된 사실, 과거 결정, 이전 실패, 반복되는 위험, 그리고 새 작업 전에 관련 정보만 제한적으로 꺼내는 방법.

## 모델: 4층 구조

```text
Foundation / adapters   canonical protocol + CLAUDE.md / AGENTS.md / installed Skills
Source of Truth          .agent-os/docs/
Skills                   skills/
Validation               .agent-os/prompts/eval/
```

### 1. Foundation / host adapters

AI 제품마다 별도 정책을 두는 게 아니라 **하나의 운영 프로토콜**을 둔다.

`templates/AGENT_PROTOCOL.section.md`가 canonical protocol source다. Claude Code는 root `CLAUDE.md`, Codex는 root `AGENTS.md`를 통해 같은 프로토콜을 받는다. ChatGPT는 저장소의 `AGENTS.md`가 자동 로드된다고 가정하지 않기 때문에 설치된 `agent-os` Skill이 주 진입점이다.

어댑터는 일부러 얇게 유지한다. 제품별 로딩 규칙은 바뀔 수 있지만 프로젝트 메모리는 바뀌지 않아야 하기 때문이다.

### 2. Source of Truth

`.agent-os/docs/`에는 검증된 프로젝트 지식이 들어간다: 아키텍처, 컨벤션, known risks, ADR 등이다. 다만 ground truth는 여전히 코드다. 코드와 docs가 다르면 코드를 신뢰하고, writable change 안에서 docs를 같이 고친다.

`07_known-risks.md`는 특별하다. 개별 error 문서가 “한 번 무슨 일이 있었는가”를 기록한다면, known-risks는 반복되거나 중요한 교훈을 “앞으로 지켜야 할 규칙”으로 승격한다.

### 3. Shared Skills

`skills/`는 Claude Code, Codex, ChatGPT 및 호환 가능한 다른 host에서 함께 쓴다. 현재 agent-os는 6개 Skill을 제공한다.

- `agent-os` — 메인 프로토콜/라우터
- `agent-os-init` — agent-os 초기화/업데이트
- `agent-os-archive` — cold-memory archive preview/apply
- `task-scan` — 관련 과거 작업/결정 검색
- `error-check` — 과거 실수/known risk 검색
- `error-log` — 새 실수 기록 또는 recurrence 갱신

Skill은 제품 이름이 아니라 **실제 capability**를 기준으로 동작을 고른다. shell + write가 가능하면 scripts와 전체 lifecycle을 사용하고, repository tool만 있으면 그 도구로 읽고 쓰며, read-only host에서는 조사와 정확한 변경안만 만들고 commit/push를 했다고 주장하지 않는다.

### 4. Validation

`.agent-os/prompts/eval/`은 offline known-answer 검증층이다. 규칙이나 retrieval 로직을 바꿀 때 프로젝트에서 실제로 발생했던 실패를 기준으로 나아졌는지 확인한다. 테스트할 수 없는 규칙은 결국 prompt의 죽은 무게가 된다.

## agent-os가 설치하고 배포하는 것

프로젝트에 agent-os를 초기화하면 다음이 생긴다.

- `.agent-os/prompts/tasks/` 및 `completed/` — 구조화된 task memory
- `.agent-os/prompts/errors/` — incident / recurrence memory
- `.agent-os/docs/` 및 `.agent-os/docs/adr/` — source of truth와 의사결정 기록
- `.agent-os/vocab.txt` — 프로젝트/도메인/다국어 별칭
- `.agent-os/scripts/` — ranking, indexing, lint, health, compaction, portability 도구
- `.agent-os/scripts/hooks/pre-commit` — opt-in mechanical gate
- root `CLAUDE.md`, `AGENTS.md` — 같은 프로토콜의 동기화된 host view

배포 저장소에는 host adapter 자체도 포함된다.

- `.claude-plugin/` — Claude Code 패키징
- `.codex-plugin/` — OpenAI/Codex 패키징
- `.agents/plugins/marketplace.json` — OpenAI marketplace metadata
- `skills/` — 위 6개 shared Skills
- `commands/` — init/archive 등의 Claude compatibility commands
- `hooks/hooks.json` — convention으로 발견되는 session hook
- `templates/` — canonical protocol 및 scaffold templates
- `scripts/host-adapter-test.sh` — cross-host distribution fixture

private 개발 저장소는 추가로 자기 자신을 dogfood하기 위한 `.agent-os/`, root `CLAUDE.md`, root `AGENTS.md`를 가진다. 이 세 경로는 private이고 public 배포물에 들어가면 안 된다.

## 작업 프로토콜

모든 일을 같은 절차로 밀어 넣지 않고 작업 크기를 나눈다.

- **Trivial** — 바로 처리
- **Local** — 보통 관련 error/known risk만 먼저 확인
- **Broad** — known risks, 관련 task/ADR/error를 확인하고 실제 코드를 검증한 뒤 구현, docs 동기화, 검증 후 task closeout

핵심은 **bounded retrieval**이다. 메모리 전체를 컨텍스트에 던지는 것이 아니다.

shell-capable mode에서는 `rank.sh`가 생성된 index를 점수화하고 상위 몇 개만 연다. repository mode에서는 frontmatter/search를 사용한다. 저장소가 unindexed라 code search가 애매한 0건을 반환할 수 있으면, directory/frontmatter fallback으로 제한적으로 탐색해서 “기록 없음”으로 잘못 결론내리지 않는다.

## 메모리: recall보다 ranking

`.agent-os/prompts/index.jsonl`은 task/error/ADR의 구조화된 카탈로그다. `rank.sh`는 query term, vocab alias, file path, recurrence 등 신호를 사용해 후보의 순서를 정한다.

중요한 이유는 retrieval 문제가 대개 “못 찾음”보다 **“찾았는데 너무 많이 나옴”**이기 때문이다. 관련 후보 50건을 찾았는데 정답이 37번째면 실질적으로 실패다.

`vocab.txt`는 문서를 전부 재태깅하지 않고 **query를 확장**한다. 한국어/일본어/영어, 제품명, 레거시 이름, 약어 등을 하나의 개념으로 연결할 수 있다.

## Error는 예방 규칙으로 승격된다

error 문서는 root cause, 관련 파일, recurrence, severity, fix를 기록한다. 같은 root cause가 다시 발생하면 새 문서를 만들지 않고 기존 문서의 recurrence를 올린다. 그래야 “같은 문제가 여러 번 발생했다”는 사실이 보인다.

교훈은 다음처럼 위로 승격되어야 한다.

```text
incident -> recurring error -> known risk / mechanical gate
```

목표는 문서를 끝없이 쌓는 것이 아니라, 반복되는 재발견 비용을 더 싼 예방 메커니즘으로 바꾸는 것이다.

## Bounded memory와 compaction

오래됐다고 자동으로 cold가 되는 것은 아니다. completed/resolved 문서 중에서도 unreferenced, unpinned, 충분히 비활성인 것만 compaction 후보가 된다.

`agent-os-health.sh`는 stale index, cold candidate, 오래 열린 task, over-pinning, 승격되지 않은 recurrence, prompt budget 문제를 보고한다. `agent-os-archive`는 적용 전에 preview한다. 조용히 자동 삭제하는 구조가 아니다.

active memory에서 내려가도 전문은 git history에서 복구 가능하다.

## 왜 host-neutral core인가

Claude Code, Codex, ChatGPT는 로딩/실행 방식이 다르다.

- Claude Code는 `CLAUDE.md`와 Claude plugin command가 자연스럽다.
- Codex는 `AGENTS.md`와 Skills가 자연스럽다.
- ChatGPT는 installed Skills가 주 진입점이고, 환경에 따라 read-only repository access부터 더 풍부한 write capability까지 달라질 수 있다.

하지만 이 차이는 **adapter 차이**지 프로젝트 메모리를 fork할 이유가 아니다.

`.agent-os/`와 `skills/`를 공유하면 어떤 agent가 작업했든 task 1개, error 1개, ADR 1개, durable lesson 1개만 존재한다. 이 장기 구조 결정은 ADR-0004에 기록되어 있다.

## Distribution correctness도 기능의 일부다

이 프로젝트는 과거에 gate가 존재하지만 실제로 실행되지 않았거나, convention hook을 manifest에서 중복 선언해 plugin 전체가 로드 실패한 적이 있다. 그래서 cross-host 호환도 기계적으로 검증한다.

- canonical protocol / Claude / AGENTS drift
- fresh init / update preservation
- malformed-marker negative fixture
- Skill metadata
- Claude/OpenAI manifest name/version sync
- convention-hook duplicate
- public release private-path leak

green 결과만으로는 충분하지 않다. 일부러 깨뜨린 fixture가 실제로 실패해야 gate가 살아 있다고 본다.

## 설계 원칙

1. **Code is ground truth; docs are source of truth.** 코드가 문서와 다르면 문서를 고친다.
2. **Frontmatter가 메모리를 scannable하게 만든다.** 산문 전체보다 구조 필드가 싸다.
3. **먼저 rank하고 적은 수만 연다.** recall이 많다고 retrieval이 좋은 게 아니다.
4. **에이전트가 자기 실수를 기록한다.** 같은 root cause의 recurrence가 보여야 한다.
5. **지속되는 교훈은 승격한다.** incident는 known risk나 gate가 되어야 한다.
6. **Product-name-first가 아니라 capability-first.** 실제 read/write/execute 능력을 기준으로 행동한다.
7. **One core, thin adapters.** Claude/OpenAI용 별도 메모리 fork를 만들지 않는다.
8. **Gate는 실제 실행됐음을 증명해야 한다.** positive-only 검증은 불충분하다.
9. **Memory는 bounded하다.** cold material은 archive하지만 복구 가능성은 남긴다.
10. **프로토콜과 Skill도 유지보수 대상이다.** 규칙을 계속 덧붙이기보다 오래된 규칙을 교체/제거한다.

## 왜 일반화되는가

이 메모리 모델은 특정 언어나 프레임워크에 묶이지 않는다. 컨텍스트를 잃을 만큼 크거나, 함정이 쌓일 만큼 오래됐거나, 같은 실수의 비용이 큰 저장소라면 verified source of truth, structured task/error memory, bounded retrieval, mechanical sync의 이점을 얻을 수 있다.

agent-os는 또 하나의 모델 전용 memory service가 아니다. **서로 다른 agent가 같은 검증된 프로젝트 메모리를 공유하게 만드는 repository-local operating discipline**이다.

## Credit

raw history보다 structured procedural knowledge가 중요하다는 관점은 Anthropic의 reusable agent Skills 관련 글에서 일부 영감을 받았다. agent-os는 그 아이디어를 repository 작업에 적용하되 memory와 operating protocol은 특정 host에 종속되지 않도록 설계한다.