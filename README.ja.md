# agent-os

**言語:** [English](README.md) | [한국어](README.ko.md) | 日本語

レガシー/曖昧なコードベース向けの **ホスト非依存エージェント運用システム**。Claude Code、Codex、ChatGPTで同じプロジェクト記憶を共有する。

agent-os の本体は特定モデルではなく `.agent-os/` にある。タスク・エラー・ADR・Source of Truth・ランキング・メモリ保守の仕組みは一つだけ持ち、Claude/Codex/ChatGPT は薄いアダプタから同じ情報を読む。

> **運用方法:** [運用ガイド](docs/GUIDE.ja.md) · 背景: [CONCEPT](docs/CONCEPT.ja.md)

## コア構造

- **Foundation**: canonical プロトコルは一つ。Claude Code は root `CLAUDE.md`、Codex は同じ内容の `AGENTS.md` を読む。
- **Source of Truth**: `.agent-os/docs/`。コードが ground truth。文書と違えばコードを確認して文書を直す。
- **共有 Skills**: `agent-os`, `agent-os-init`, `agent-os-archive`, `task-scan`, `error-check`, `error-log`。
- **Validation**: `.agent-os/prompts/eval/` の known-answer セットで規則の有効性を測る。

## ホスト対応

| ホスト | エントリ | 継続ガイダンス | 書き込み |
|---|---|---|---|
| Claude Code | `.claude-plugin/`, `/agent-os:init`, `/agent-os:archive` | `CLAUDE.md` | local full mode |
| Codex | インストール済み Skill/plugin, `$agent-os` | `AGENTS.md` | Codex/local full mode |
| ChatGPT | インストール済み Skill (`agent-os` 等) | Skill が基本入口。repo の `AGENTS.md` 自動読込を前提にしない | 接続ツール次第。通常の GitHub app は read-only |

Skills は製品名ではなく **実際の capability** でモードを選ぶ。shell+write があれば full mode、repository write のみなら repository mode、read-only なら prior task/error/known-risk の調査と具体的な変更案まで行い、実際に書いたとは主張しない。

## インストール

公開リポジトリ: **https://github.com/blackstrawberry/agent-os**

### Claude Code — プラグインインストール

Claude Code にそのまま貼り付ける:

```text
/plugin marketplace add blackstrawberry/agent-os
/plugin install agent-os@agent-os
/agent-os:init
```

`blackstrawberry/agent-os` は Claude Code が公式に対応している GitHub の `owner/repo` 省略記法。GitHub repository では `https://github.com/...git` の完全 URL は **必須ではない**。GitHub 以外の Git server などでは完全な Git URL を指定できる。

開発 checkout を直接ロードする場合:

```sh
git clone https://github.com/blackstrawberry/agent-os.git
claude --plugin-dir "$(pwd)/agent-os"
```

### Codex — GitHub Skill インストール

Codex の組み込み `$skill-installer` は GitHub 上の Skill ディレクトリ URL を直接インストールできる。最小構成として agent-os の入口だけ入れる場合は Codex に次を貼り付ける。

```text
$skill-installer install https://github.com/blackstrawberry/agent-os/tree/main/skills/agent-os
```

インストール後に Codex を再起動する。初期化済み project を開けば通常の依頼でも routing され、明示呼び出しもできる。

```text
$agent-os この repo を変更する前に関連 task、ADR、known risks、過去 error を確認して
```

**新規 project** では Skill を入れただけで `.agent-os/` scaffold が作られるわけではない。公開 repo を一度 clone して installer を実行する。

```sh
git clone https://github.com/blackstrawberry/agent-os.git ~/.local/share/agent-os
bash ~/.local/share/agent-os/scripts/init.sh /absolute/path/to/your/project
```

既存 agent-os project の更新:

```sh
git -C ~/.local/share/agent-os pull --ff-only
bash ~/.local/share/agent-os/scripts/init.sh --update /absolute/path/to/your/project
```

これで `.agent-os/`、root `CLAUDE.md`、root `AGENTS.md` が作成/更新される。Codex は project の `AGENTS.md` を自動的に読み、インストールした `agent-os` Skill は再利用可能な routing/運用入口になる。

Codex の Plugins 画面や workspace marketplace で **agent-os** が利用できる環境なら、そこから plugin 全体をインストールしてもよい。上記 GitHub Skill 方式は public repo から今すぐ使える portable な経路。

### ChatGPT — Skill インストール

ChatGPT の Skills 画面で upload が使えるアカウントなら、公開 repo を取得して **`skills/agent-os/` フォルダ一つ**を Skill として upload する。

- Repository: https://github.com/blackstrawberry/agent-os
- ZIP: https://github.com/blackstrawberry/agent-os/archive/refs/heads/main.zip
- Upload folder: `skills/agent-os/`

workspace 管理型の配布では、権限を持つ管理者が `https://github.com/blackstrawberry/agent-os` の GitHub marketplace を import し、GitHub と同期できる。実際の menu/権限は workspace と product surface に依存する。

インストール後は通常の依頼でも agent-os に implicit routing されうる。ChatGPT はインストール済み Skill が主入口で、GitHub 接続だけの通常チャットを writable project state とはみなさない。

## プロジェクト初期化 / 移行

```sh
bash /path/to/agent-os/scripts/init.sh [--no-eval] /path/to/project
bash /path/to/agent-os/scripts/init.sh --update /path/to/project
```

installer は `.agent-os/` を作り、**同じ protocol block** を root `CLAUDE.md` と `AGENTS.md` に入れる。`--update` は marker 外のユーザーテキストを保持する。旧 Claude-only install では欠けた `AGENTS.md` を追加する。marker が壊れていれば片方だけ更新された状態を残さず中断する。

初期化後:

1. `git config core.hooksPath .agent-os/scripts/hooks`
2. 実際の repo scan から `.agent-os/docs/` を作る
3. 実際に起きた失敗から eval set を作る
4. project 用語を `.agent-os/vocab.txt` に追加する

## 日常運用

| こう言えば | 動くもの |
|---|---|
| 「この repo で agent-os を使って」 | `agent-os` |
| 「タスク化 / 前にやった?」 | `task-scan` |
| 「このミス前にもあった?」 | `error-check` |
| 「今のミスを記録」 | `error-log` |
| 「agent-os を初期化/更新」 | `agent-os-init` / Claude では `/agent-os:init` |
| 「cold memory を整理」 | `agent-os-archive` / Claude では `/agent-os:archive` |

作業は規模で分ける。trivial は即処理、local は過去エラー確認、broad のみ known-risks + prior task/ADR + error history を先に読む。

## 構造

```text
agent-os/
├── .agents/plugins/marketplace.json
├── .claude-plugin/
├── .codex-plugin/plugin.json
├── skills/{agent-os,agent-os-init,agent-os-archive,task-scan,error-check,error-log}/
├── commands/                  # Claude compatibility adapter
├── hooks/hooks.json
├── scripts/
├── templates/
│   ├── AGENT_PROTOCOL.section.md
│   ├── CLAUDE.section.md
│   └── AGENTS.section.md
└── docs/
```

lab repository の root `CLAUDE.md`/`AGENTS.md` は dogfooding 用 PRIVATE 状態。公開 `agent-os` には template/adapter だけを出す。

## 検証

```sh
sh scripts/host-adapter-test.sh
```

protocol drift、Claude/OpenAI manifest の name/version drift、Skill metadata、fresh init、Claude-only migration、marker 外テキスト保持、malformed marker の fail-closed を検査する。OS/awk/locale 差は既存 `portability-test.sh` が担当。

## ライセンス

MIT — [LICENSE](LICENSE)
