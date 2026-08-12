# agent-os

**언어:** [English](README.md) | 한국어 | [日本語](README.ja.md)

레거시/모호한 코드베이스를 위한 **에이전트 운영 체계** — Claude Code 플러그인.

크거나 오래된 코드베이스에서 AI 에이전트는 의도가 샌다: 확인 대신 추측하고, 과거 실수를 반복하고, 문서를 노후화시킨다. agent-os는 모델이 아니라 **구조**를 고친다. 프로젝트에 단일 진실(Source of Truth), 스캔 가능한 태스크/에러 메모리, 자가 점검 스킬, 강제 동기화 훅을 부여해 — *루프를 따랐을 때* 에이전트가 시간이 갈수록 **더 정확**해질 수 있게 한다. 자동 보장이 아니라 사람이 루프에 남는 규율 스캐폴드다.

> **사용법:** **[운영 가이드](docs/GUIDE.ko.md)** — human-in-the-loop 루프(셋업 -> 태스크 -> 리뷰 -> 수행 -> 자체개선 -> 반복). 여기서 시작.
>
> 전체 배경은 **[docs/CONCEPT.ko.md](docs/CONCEPT.ko.md)**. 아이디어를 이해·수용하려면 읽어볼 것.

## 핵심 아이디어 (요약)
agent-os가 빌려온 발상(Anthropic의 *스킬* 구축 글): 과거 데이터를 더 줘도 정확도는 거의 안 오르고, 정확도를 끌어올리는 건 **구조화된 절차 지식(=스킬)** 이다. agent-os는 이 발상을 일상 코딩 작업에 가볍게 적용한 — 아직 측정되지 않은 — 4층 구조다. 실제 효과는 Validation 층으로 직접 측정한다.

- **Foundation** (`CLAUDE.md`): 모든 요청이 따르는 작업 프로토콜(라우터).
- **Source of Truth** (`.agent-os/docs/`): 실제 스캔으로 작성한, 검증된 시스템 설명. 코드와 다르면 코드 확인 후 docs를 고친다.
- **Skills**: 라우터 스킬 3종 — `task-scan`(관련 과거 작업 찾기), `error-check`(실수 재발 방지), `error-log`(에이전트가 스스로 실수 기록).
- **Validation** (`.agent-os/prompts/eval/`): 정답이 명확한 평가셋으로 변경이 개선인지 수치 확인.

## 제공 기능
- **스킬**(자동 라우팅): `task-scan`, `error-check`, `error-log`
- **커맨드**: `/agent-os:init [--no-eval]` — `.agent-os/`(prompts·docs·scripts·Validation 평가셋) + 루트 `CLAUDE.md` 프로토콜 섹션 생성(루트 안 더럽힘, 기존 파일 안 덮음); `--no-eval`로 평가셋 제외
- **강제 동기화**(opt-in): frontmatter 누락 시 커밋 차단 + 코드 변경에 docs 미갱신 시 경고하는 `pre-commit` 훅
- **메모리 바운딩**: 생성 인덱스 `.agent-os/prompts/index.jsonl`(N개 대신 1파일 스캔) + `/agent-os:archive` — **콜드 문서만** 아카이브(완료·무참조·미고정·오래됨; 단순 나이 아님). 전문은 git 보존. 메모리가 임계를 넘으면 **세션 시작 시 compact 알림** 자동 표시

## 설치
```
/plugin marketplace add /absolute/path/to/agent-os-plugin
/plugin install agent-os@agent-os
```
개발용 직접 로드(세션 한정): `claude --plugin-dir /absolute/path/to/agent-os-plugin`
GitHub 푸시 후: `/plugin marketplace add <owner>/<repo>`

## 사용
```
/agent-os:init             # 구조 스캐폴드 (평가셋 Validation 포함)
/agent-os:init --no-eval   # 평가셋(Validation) 제외
```
스캐폴드 후:
1. `git config core.hooksPath .agent-os/scripts/hooks` — 강제 동기화 훅 활성화
2. 초회 전체 스캔으로 `.agent-os/docs/` 를 프로젝트 Source of Truth 로 채움(스캐폴드는 색인 스켈레톤만 생성)
3. 이후 모든 요청: `task-scan → docs → error-check → 실행 → error-log → 동기화`

## 튜닝
임계값은 하드코딩이 아니라 **컨텍스트 윈도우에서 도출**. `AGENT_OS_CONTEXT_TOKENS`를 모델 윈도우로 지정하면 `AGENT_OS_MAX_ACTIVE`(기본 `CONTEXT_TOKENS/1000`)·`AGENT_OS_COMPACT_NUDGE`(기본 `MAX/4`)가 따라 스케일. 근거는 [docs/CONCEPT.ko.md](docs/CONCEPT.ko.md) 참조.

## 언어 정책
스킬·커맨드·템플릿·스크립트는 **영어 전용**(프롬프트/운영용). README만 번역한다. 문서는 **검증된 사실만** 기록하고, 비밀값은 docs/prompts에 복사하지 않는다.

## 라이선스
MIT — [LICENSE](LICENSE).
