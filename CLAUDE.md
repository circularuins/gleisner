# CLAUDE.md — Gleisner

このファイルは Claude Code 固有の指針です。**プロジェクト共通指針は `AGENTS.md` に集約**しているため、まずそちらを参照してください。

@AGENTS.md

---

以下は **Claude Code 固有** の補足です。Codex CLI など他ツールには適用されません。

## `.claude/rules/` の path-scoped 自動読み込み

バックエンド・フロントエンドの詳細な実装ルールは `.claude/rules/` に **path-scoped** で配置されている（[公式仕様](https://code.claude.com/docs/en/memory#path-specific-rules)）。Claude Code は該当パスのファイルを Read した時にのみ自動でコンテキストに注入する。

- `.claude/rules/backend-implementation.md` — `backend/**/*.{ts,sql}` 系を Read した時に load
- `.claude/rules/frontend-implementation.md` — `frontend/**/*.dart` 系を Read した時に load

> **既知の制限**: **Read 時のみ rule が発火する**（[#23478](https://github.com/anthropics/claude-code/issues/23478)）。新規ファイルを Write で作成する場合は、関連する既存ファイルを先に Read しておくか、必要に応じて手動で rules ファイルを参照すること。
