# agent-os

**言語:** [English](README.md) | [한국어](README.ko.md) | 日本語

レガシー/曖昧なコードベースのための **エージェント運用システム** — Claude Code プラグイン。

大規模・古い・雑然としたコードベースでは、AIエージェントの意図がぶれる: 確認せず推測し、過去のミスを繰り返し、ドキュメントを陳腐化させる。agent-os はモデルではなく **構造** を直す。プロジェクトに唯一の真実(Source of Truth)、スキャン可能なタスク/エラー記憶、自己点検スキル、強制同期フックを与え — *ループを踏んだとき*にエージェントが時間とともに **より正確** になり得るようにする。自動保証ではなく、人がループに残る規律のスキャフォルドだ。

> **使い方:** **[運用ガイド](docs/GUIDE.ja.md)** — human-in-the-loop ループ(セットアップ -> タスク -> 確認 -> 実行 -> 自己改善 -> 繰り返し)。まずここから。
>
> 全体の背景は **[docs/CONCEPT.ja.md](docs/CONCEPT.ja.md)**。アイデアを理解・採用するなら一読を。

## コアアイデア(要約)
agent-os が借りた発想(Anthropic の*スキル*構築の記事): 過去データを増やしても精度はほぼ上がらず、精度を押し上げるのは **構造化された手続き知識(=スキル)** だ。agent-os はこの発想を日常のコーディング作業に軽量に適用した — まだ未計測の — 4層構造である。実際の効果は Validation 層で自分で測定する。

- **Foundation** (`CLAUDE.md`): すべてのリクエストが従う作業プロトコル(ルーター)。
- **Source of Truth** (`.agent-os/docs/`): 実スキャンで書いた検証済みのシステム記述。コードと異なればコードを確認のうえ docs を直す。
- **Skills**: ルーター3種 — `task-scan`(関連する過去作業の発見)、`error-check`(ミスの再発防止)、`error-log`(エージェントが自らミスを記録)。
- **Validation** (`.agent-os/prompts/eval/`): 正解が明確な評価セットで、変更が改善かを数値で確認。

## 提供機能
- **スキル**(自動ルーティング): `task-scan`, `error-check`, `error-log`
- **コマンド**: `/agent-os:init [--no-eval]` — `.agent-os/`(prompts・docs・scripts・Validation 評価セット) + ルート `CLAUDE.md` プロトコル節を生成(ルートを汚さず、既存ファイルは上書きしない); `--no-eval` で評価セットを除外
- **強制同期**(opt-in): frontmatter 欠落でコミットをブロック + コード変更に docs 更新が無ければ警告する `pre-commit` フック
- **メモリの上限管理**: 生成インデックス `.agent-os/prompts/index.jsonl`(N個ではなく1ファイルをスキャン) + `/agent-os:archive` — **コールドな文書のみ**アーカイブ(完了・無参照・未ピン・古い; 単なる古さではない)。全文は git に保存。メモリが閾値を超えると**セッション開始時に compact 通知**を自動表示

## インストール
```
/plugin marketplace add /absolute/path/to/agent-os-plugin
/plugin install agent-os@agent-os
```
開発用に直接ロード(セッション限定): `claude --plugin-dir /absolute/path/to/agent-os-plugin`
GitHub プッシュ後: `/plugin marketplace add <owner>/<repo>`

## 使い方
```
/agent-os:init             # 構造をスキャフォルド (評価セット Validation を含む)
/agent-os:init --no-eval   # 評価セット(Validation)を除外
```
スキャフォルド後:
1. `git config core.hooksPath .agent-os/scripts/hooks` — 強制同期フックを有効化
2. 初回の全体スキャンで `.agent-os/docs/` をプロジェクトの Source of Truth として埋める(スキャフォルドは索引の骨組みのみ生成)
3. 以降すべてのリクエスト: `task-scan → docs → error-check → 実行 → error-log → 同期`

## チューニング
閾値はハードコードではなく**コンテキストウィンドウから導出**。`AGENT_OS_CONTEXT_TOKENS` をモデルのウィンドウに設定すれば、`AGENT_OS_MAX_ACTIVE`(既定 `CONTEXT_TOKENS/1000`)・`AGENT_OS_COMPACT_NUDGE`(既定 `MAX/4`)が連動してスケールする。根拠は [docs/CONCEPT.ja.md](docs/CONCEPT.ja.md) を参照。

## 言語ポリシー
スキル・コマンド・テンプレート・スクリプトは **英語のみ**(プロンプト/運用用)。README のみ翻訳する。ドキュメントは **検証済みの事実のみ** を記し、秘密値を docs/prompts にコピーしない。

## ライセンス
MIT — [LICENSE](LICENSE)。
