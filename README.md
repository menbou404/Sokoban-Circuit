# 倉庫番 × 論理回路パズル Codex用マークダウン一式

このフォルダは、CodexにGodot 4.x用の最小試作品を自動実装させるための指示書セットです。

目的は、AND回路やOR回路のようなブロックを押して配置し、信号をランプへ通す倉庫番型パズルを作ることです。

この資料では、ゲームとして守るべき仕様だけを固定します。ファイル構造、クラス構成、シーン構成、描画方法、実装順序の細部はCodexに任せます。

## Codexへの最初の依頼文

リポジトリのルートにこのフォルダ内のMarkdownファイルを置いたうえで、Codexに次のように依頼してください。

```text
このリポジトリにあるMarkdown仕様書をすべて読んでください。
Godot 4.xとGDScriptで、倉庫番 × 論理回路パズルの最小試作品を実装してください。
ファイル構造、クラス構成、シーン構成はあなたが判断してください。
ただし、GAME_SPEC.md、RULES.md、ACCEPTANCE_TESTS.md、AGENTS.mdに書かれた制約と完了条件は守ってください。
外部アセットと外部プラグインは使わないでください。
実装後に、作成したファイル一覧、実行手順、未対応事項を報告してください。
```

## 収録ファイル

- `AGENTS.md`: Codex向けの作業ルール
- `docs/GAME_SPEC.md`: ゲーム仕様
- `docs/RULES.md`: 移動、ブロック、回路の詳細ルール
- `docs/LEVEL_FORMAT.md`: ステージ文字列の形式
- `docs/ACCEPTANCE_TESTS.md`: 完了条件と確認項目
- `docs/IMPLEMENTATION_FREEDOM.md`: Codexに任せる設計範囲
- `docs/DEBUG_AND_QA.md`: デバッグ表示と品質確認
- `prompts/01_full_build.md`: 一括実装用プロンプト
- `prompts/02_incremental_build.md`: 段階実装用プロンプト
- `prompts/03_fix_and_verify.md`: 修正・検証用プロンプト

## 使い方

最初は `prompts/01_full_build.md` の内容をCodexへ渡してください。

一括実装で崩れる場合は、`prompts/02_incremental_build.md` の順番で小さく実装させてください。

実装後に挙動が怪しい場合は、`prompts/03_fix_and_verify.md` を使って検証と修正を依頼してください。
