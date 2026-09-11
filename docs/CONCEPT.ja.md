# agent-os の考え方

**Languages:** [English](CONCEPT.md) | [한국어](CONCEPT.ko.md) | 日本語

> agent-os が *なぜ* この構造なのか、そして自分のプロジェクトに合うかを判断したいときに読む文書です。

## 問題

大きい・古い・曖昧さの多いコードベースでは、AI エージェントは意図を失いやすくなります。セッションごとに同じ文脈を作り直し、以前と同じミスを繰り返し、古くなったドキュメントを信じて誤った方向へ進むことがあります。

多くの場合、ボトルネックはモデルの知能ではなく、**新しい依頼を正しいプロジェクト知識へつなぐ持続的な構造がないこと**です。

過去の会話やコミットを大量に残すだけでは解決しません。agent-os は代わりに、検証済みの事実、過去の意思決定、以前の失敗、継続的なリスク、そして新しい作業の前に関連情報だけを限定的に取り出す方法を構造化して保存します。

## モデル: 4 レイヤー

```text
Foundation / adapters   canonical protocol + CLAUDE.md / AGENTS.md / installed Skills
Source of Truth          .agent-os/docs/
Skills                   skills/
Validation               .agent-os/prompts/eval/
```

### 1. Foundation / host adapters

AI 製品ごとに別々のポリシーを持つのではなく、**1 つの運用プロトコル**を持ちます。

`templates/AGENT_PROTOCOL.section.md` が canonical protocol source です。Claude Code は root `CLAUDE.md`、Codex は root `AGENTS.md` を通じて同じプロトコルを受け取ります。ChatGPT ではリポジトリの `AGENTS.md` が自動で読み込まれるとは仮定しないため、インストール済みの `agent-os` Skill が主な入口になります。

アダプターは意図的に薄く保ちます。製品ごとの読み込み仕様は変わっても、プロジェクトメモリは変わるべきではないからです。

### 2. Source of Truth

`.agent-os/docs/` には検証済みのプロジェクト知識を置きます。アーキテクチャ、規約、known risks、ADR などです。ただし ground truth は常にコードです。コードと docs が矛盾した場合はコードを信頼し、書き込み可能な変更の中で docs も同時に直します。

`07_known-risks.md` は特別です。個別の error 文書が「一度何が起きたか」を記録するのに対し、known-risks は繰り返した、または重要な教訓を「今後守るべきルール」へ昇格させます。

### 3. Shared Skills

`skills/` は Claude Code、Codex、ChatGPT、および互換ホストで共有します。現在の agent-os は 6 つの Skill を提供します。

- `agent-os` — メインプロトコル / ルーター
- `agent-os-init` — agent-os の初期化 / 更新
- `agent-os-archive` — cold-memory archive の preview / apply
- `task-scan` — 関連する過去作業・意思決定の取得
- `error-check` — 過去のミス・known risk の取得
- `error-log` — 新しいミスの記録、または recurrence の更新

Skill は製品名ではなく **実際の capability** によって動作を選びます。shell + write が使えるなら scripts と完全な lifecycle を使い、repository tool だけならそのツールで読み書きし、read-only host では調査と正確な変更案だけを出して commit/push したと偽りません。

### 4. Validation

`.agent-os/prompts/eval/` は offline known-answer の検証レイヤーです。ルールや retrieval を変えるときは、実際にプロジェクトで起きた失敗を使って改善したかを確認します。テストできないルールは、最終的に prompt の死んだ重みになります。

## agent-os がインストール・配布するもの

プロジェクトに agent-os を初期化すると、次が作られます。

- `.agent-os/prompts/tasks/` と `completed/` — 構造化された task memory
- `.agent-os/prompts/errors/` — incident / recurrence memory
- `.agent-os/docs/` と `.agent-os/docs/adr/` — source of truth と意思決定記録
- `.agent-os/vocab.txt` — プロジェクト / ドメイン / 多言語エイリアス
- `.agent-os/scripts/` — ranking, indexing, lint, health, compaction, portability ツール
- `.agent-os/scripts/hooks/pre-commit` — opt-in mechanical gate
- root `CLAUDE.md`, `AGENTS.md` — 同じプロトコルの同期された host view

配布リポジトリには host adapter 自体も含まれます。

- `.claude-plugin/` — Claude Code パッケージング
- `.codex-plugin/` — OpenAI / Codex パッケージング
- `.agents/plugins/marketplace.json` — OpenAI marketplace metadata
- `skills/` — 上記 6 つの shared Skills
- `commands/` — init/archive などの Claude compatibility commands
- `hooks/hooks.json` — convention で発見される session hook
- `templates/` — canonical protocol と scaffold templates
- `scripts/host-adapter-test.sh` — cross-host distribution fixture

private 開発リポジトリには、さらに自己 dogfood 用の `.agent-os/`、root `CLAUDE.md`、root `AGENTS.md` があります。この 3 つは private であり、public 配布物へ漏れてはいけません。

## 作業プロトコル

すべての依頼を同じ儀式へ通すのではなく、作業サイズで分けます。

- **Trivial** — そのまま処理
- **Local** — 通常は関連する error / known risk だけ先に確認
- **Broad** — known risks、関連 task / ADR / error を確認し、実コードを検証してから実装、docs 同期、検証後に task closeout

重要なのは **bounded retrieval** です。メモリ全体をコンテキストへ投入することではありません。

shell-capable mode では `rank.sh` が生成済み index をスコアリングし、上位の少数だけを開きます。repository mode では frontmatter/search を使います。リポジトリが未インデックスなどの理由で code search が曖昧な 0 件を返す場合、directory/frontmatter fallback を使って限定的に探索し、「履歴がない」と誤判定しません。

## メモリ: recall より ranking

`.agent-os/prompts/index.jsonl` は task/error/ADR の構造化カタログです。`rank.sh` は query term、vocab alias、file path、recurrence などのシグナルから候補順を決めます。

重要なのは、retrieval の問題が「見つからない」より **「見つかりすぎる」** ことが多いからです。関連候補 50 件のうち正解が 37 番目なら、実質的には失敗です。

`vocab.txt` は文書を全部再タグ付けせず、**query を拡張**します。韓国語、日本語、英語、製品名、旧名称、略語を 1 つの概念へつなげられます。

## Error は予防ルールへ昇格する

error 文書には root cause、関連ファイル、recurrence、severity、fix を記録します。同じ root cause が再発した場合は別文書を作らず、既存文書の recurrence を上げます。そうすることで「同じ問題が何度も起きている」ことが見えるようになります。

教訓は次のように抽象度を上げます。

```text
incident -> recurring error -> known risk / mechanical gate
```

目的は文章を無限に増やすことではなく、繰り返す再発見コストを、より安い予防メカニズムへ変えることです。

## Bounded memory と compaction

古いだけでは cold とは見なしません。completed/resolved 文書のうち、unreferenced、unpinned、十分に非アクティブなものだけが compaction 候補になります。

`agent-os-health.sh` は stale index、cold candidate、長期間開いた task、over-pinning、未昇格 recurrence、prompt budget 問題を報告します。`agent-os-archive` は適用前に preview します。何かが黙って自動削除される設計ではありません。

active memory から下げても全文は git history から復元できます。

## なぜ host-neutral core なのか

Claude Code、Codex、ChatGPT は読み込み・実行方式が違います。

- Claude Code は `CLAUDE.md` と Claude plugin command が自然です。
- Codex は `AGENTS.md` と Skills が自然です。
- ChatGPT は installed Skills が主な入口で、環境によって read-only repository access からより豊富な write capability まで差があります。

しかしこれは **adapter の違い** であって、プロジェクトメモリを fork する理由ではありません。

`.agent-os/` と `skills/` を共有すれば、どの agent が作業しても task は 1 つ、error は 1 つ、ADR は 1 つ、durable lesson も 1 つです。この長期アーキテクチャ判断は ADR-0004 に記録されています。

## Distribution correctness も機能の一部

このプロジェクトでは過去に、gate が存在していても実際には走っていなかったり、convention hook を manifest に重複宣言して plugin 全体が load failure になったことがあります。そのため cross-host compatibility も機械的に検証します。

- canonical protocol / Claude / AGENTS drift
- fresh init / update preservation
- malformed-marker negative fixture
- Skill metadata
- Claude/OpenAI manifest name/version sync
- convention-hook duplicate
- public release private-path leak

green だけでは十分ではありません。意図的に壊した fixture が本当に失敗して初めて gate が生きていると判断します。

## 設計原則

1. **Code is ground truth; docs are source of truth.** コードと文書が違えば文書を直す。
2. **Frontmatter でメモリを scan 可能にする。** 全文より構造化フィールドの方が安い。
3. **まず rank し、少数だけ開く。** recall が多いことと retrieval が良いことは同じではない。
4. **エージェントが自分のミスを記録する。** 同じ root cause の recurrence を可視化する。
5. **継続する教訓は昇格する。** incident は known risk や gate になるべき。
6. **Product-name-first ではなく capability-first.** 実際に read/write/execute できる範囲で行動する。
7. **One core, thin adapters.** Claude/OpenAI 用に同じメモリを fork しない。
8. **Gate は実行された証拠を持つ。** positive-only 検証では不十分。
9. **Memory は bounded。** cold material は archive しても復元可能性を残す。
10. **プロトコルと Skill も保守対象。** ルールを足し続けず、古いルールを置換・削除する。

## なぜ一般化できるのか

このメモリモデルは特定の言語やフレームワークに依存しません。文脈を失うほど大きい、罠が蓄積するほど古い、または同じ失敗のコストが高いリポジトリなら、verified source of truth、structured task/error memory、bounded retrieval、mechanical sync の恩恵を受けられます。

agent-os は別のモデル専用 memory service ではありません。**異なる agent が同じ検証済みプロジェクトメモリを共有するための repository-local operating discipline** です。

## Credit

raw history より structured procedural knowledge が重要だという考え方は、Anthropic の reusable agent Skills に関する文章から一部着想を得ています。agent-os はその考え方を repository 作業へ適用しつつ、memory と operating protocol は特定 host に依存しないよう設計しています。