# agent-os

**言語:** [English](README.md) | [한국어](README.ko.md) | 日本語

レガシー/曖昧なコードベース向けの **ホスト非依存エージェント運用システム**。Claude Code、Codex、ChatGPT で同じプロジェクト記憶を共有する。

agent-os の本体は特定モデルではなく `.agent-os/` にある。Task・Error・ADR・Source of Truth・ランキング・メモリ保守の仕組みは一つだけ持ち、Claude/Codex/ChatGPT は薄いアダプタから同じ情報を読む。

> **運用方法:** [運用ガイド](docs/GUIDE.ja.md) · 背景: [CONCEPT](docs/CONCEPT.ja.md)

## コア構造

- **Foundation**: canonical プロトコルは一つ。Claude Code は root `CLAUDE.md`、Codex は同じ内容の `AGENTS.md` を読む。
- **Source of Truth**: `.agent-os/docs/`。コードが ground truth。文書と違えばコードを確認して文書を直す。
- **共有 Skills**: `agent-os`, `agent-os-init`, `agent-os-archive`, `task-scan`, `error-check`, `error-log`。
- **Validation**: `.agent-os/prompts/eval/` の known-answer セットで規則の有効性を測る。

## ホスト対応

| ホスト | エントリ | 継続ガイダンス | mutation capability |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | local full mode |
| Codex | インストール済み Skill/plugin, `$agent-os` | `AGENTS.md` | Codex/local full mode |
| ChatGPT Native | 現在の surface でインストール可能な plugin/Skill | plugin/Skill | 実際に expose された action + authorization 次第 |
| ChatGPT Project compatibility | `chatgpt/agent-os-chatgpt.md` + Project instructions | Project files/instructions | 接続ツール/action 次第。Project 自体は shell runtime ではない |

Skills は製品名ではなく **実際の capability** でモードを選ぶ。GitHub や他の app が接続されているという事実だけで read/write を推測しない。現在の surface が expose し、現在のユーザーに authorization された action だけを使う。成功した write action が無ければ、正確な Task/Error/patch 案は作れても repository を実際に変更したとは主張しない。

## インストール

公開リポジトリ: **https://github.com/blackstrawberry/agent-os**

まず **host** を選び、ChatGPT の場合は **利用目的 (intent) → 実際の capability** の順に選ぶ。プラン名は参考情報であり、インストールルーターの source of truth ではない。

### Claude Code — plugin install

Claude Code にそのまま貼り付ける:

```text
/plugin marketplace add blackstrawberry/agent-os
/plugin install agent-os@agent-os
/agent-os:init
```

`blackstrawberry/agent-os` は Claude Code が対応する GitHub `owner/repo` 省略記法。

開発 checkout を直接ロードする場合:

```sh
git clone https://github.com/blackstrawberry/agent-os.git
claude --plugin-dir "$(pwd)/agent-os"
```

最初の smoke:

```text
この repo を変更する前に agent-os で関連する過去記録と known risks を確認して。
```

### Codex — GitHub Skill install

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

インストール後に Codex を再起動する。初期化済み project では通常依頼または明示呼び出しが可能。

```text
$agent-os この repo を変更する前に関連 task、ADR、known risks、過去 error を確認して
```

**新規 project** は Skill を入れただけでは `.agent-os/` が作成されない。

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

既存 project の更新:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

Codex は初期化された repo の root `AGENTS.md` を自動的に読む。

### ChatGPT — 個人利用 (`Just me`)

現在のアカウントで **実際に使える最初の経路**を選ぶ。

1. **Plugin Directory** — agent-os が実際に一覧にあり、Install action が表示される場合だけインストールする。Directory が見えるだけで agent-os が利用可能だとは仮定しない。
2. **Native Skills** — `Plugins -> Skills -> Create -> Upload from your computer` が表示されるなら canonical `skills/agent-os/` Skill を、その surface が受け付ける形式でインストールする。Native Skill upload は現在 eligible な managed workspace を中心に提供されるため、availability は account/workspace/surface により変わり得る。
3. **ChatGPT Project compatibility** — 上記 native 経路が無く Projects が使える場合:
   - 新しい ChatGPT Project を作る
   - public repo の **`chatgpt/agent-os-chatgpt.md`** を upload
   - **`chatgpt/PROJECT_INSTRUCTIONS.md`** の内容を Project instructions にコピー
   - 必要なら GitHub/app を接続するが、read/write は実際に expose された action を確認して判断する
4. **Projects も無い** — 現在の surface は unsupported。インストール済みのように装わない。

Project compatibility は Native Skill より意図的に小さい。初期 profile は `agent-os`, `task-scan`, `error-check`, `error-log` のみ。`agent-os-init` / `agent-os-archive` は Project 自体が shell/hooks/local scripts を提供しないため含めない。

最初の Project smoke:

```text
この broad request に agent-os を使って。known risks と最も関連する task/ADR/error を先に確認し、検索 0 件が indexing 問題か不明なら directory/frontmatter fallback を使って。authorized write action が実際に成功していない限り repo を変更したとは言わないで。
```

### ChatGPT — workspace/team 配布

チームへ配布する目的なら、個人インストールより先に **workspace admin の distribution intent** を確認する。

権限のある workspace admin で `Workspace settings -> Plugins -> Add -> Import marketplace` が表示される場合:

1. Source: `https://github.com/blackstrawberry/agent-os`
2. repository root の `.agents/plugins/marketplace.json` を使うため Path は空にする。
3. marketplace import 後、installation policy と必要な app/action 権限を workspace 側で設定する。
4. GitHub sync は plugin content を配布するだけで、provider account access や write permission を自動付与しない。

Import marketplace が無い、または admin でない場合は workspace policy が実際に許可する Native Skill/plugin/Project 経路だけを使う。すべて無ければ unsupported。

現在確認している OpenAI docs:
- Skills: https://help.openai.com/en/articles/20001066-skills-in-chatgpt
- Plugins: https://help.openai.com/en/articles/20001256-plugins-in-chatgpt-and-codex
- GitHub marketplace import: https://help.openai.com/en/articles/20001504-importing-and-syncing-plugin-marketplaces-from-github
- Projects: https://help.openai.com/en/articles/10169521-projects-in-chatgpt

製品 UI や policy は変わり得るため、プラン名を hard-code せず実際の capability を確認する。

## プロジェクト初期化 / 移行

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
bash /path/to/agent-os/scripts/init.sh --update /path/to/project
```

installer は `.agent-os/` を作り、同じ protocol block を root `CLAUDE.md` と `AGENTS.md` に入れる。`--update` は marker 外のユーザーテキストを保持する。旧 Claude-only install では欠けた `AGENTS.md` を追加する。marker が壊れていれば partial write 前に中断する。

初期化後:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. 実 repo scan から `.agent-os/docs/` を作る
3. 実際に起きた失敗から eval set を作る
4. project 用語を `.agent-os/vocab.txt` に追加する

## 日常運用

| こう言えば | 動くもの |
|---|---|
| 「この repo で agent-os を使って」 | `agent-os` |
| 「タスク化 / 前にやった?」 | `task-scan` |
| 「このミス前にもあった?」 | `error-check` |
| 「今のミスを記録」 | `error-log` |
| 「agent-os を初期化/更新」 | `agent-os-init` / Claude では `/agent-os:init`; local capability が必要 |
| 「cold memory を整理」 | `agent-os-archive` / Claude では `/agent-os:archive`; local capability が必要 |

作業は規模で分ける。trivial は即処理、local は過去 error を確認、broad のみ known-risks + prior task/ADR + error history を先に読む。

## 構造

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/
├── .codex-plugin/plugin.json
├── chatgpt/
│   ├── agent-os-chatgpt.md              # generated, ready-to-upload
│   └── PROJECT_INSTRUCTIONS.md          # generated, ready-to-copy
├── skills/{agent-os,agent-os-init,agent-os-archive,task-scan,error-check,error-log}/
├── commands/                            # Claude compatibility adapter
├── hooks/hooks.json
├── scripts/{build-chatgpt-project.sh,chatgpt-project-test.sh,...}
├── templates/chatgpt/{profile.txt,BUNDLE_HEADER.md,PROJECT_INSTRUCTIONS.md}
└── docs/
```

lab repository の root `CLAUDE.md`/`AGENTS.md` と `.agent-os/` は dogfooding 用 PRIVATE 状態。公開 `agent-os` には分類済み CORE と generated `chatgpt/` artifact だけを配布する。

## 検証

```sh
sh scripts/host-adapter-test.sh
sh scripts/chatgpt-project-test.sh
```

`host-adapter-test.sh` は Task 26 の Claude/Codex baseline を維持する。`chatgpt-project-test.sh` は Project allowlist、deterministic build、tracked artifact drift、public provenance、size budget、private lab leakage、capability guardrail、missing-Skill fail-closed を検査する。OS/awk/locale 差は `portability-test.sh` が担当。

## ライセンス

MIT — [LICENSE](LICENSE)
