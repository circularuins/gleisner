# review

目的:
変更差分を、バグ・回帰・設計逸脱の観点でレビューする。

前提:
- レビューの主眼は不具合、回帰、テスト不足、設計逸脱の特定
- 指摘は重要度順に並べる
- 概要は Findings の後に簡潔に述べる

確認観点:
- 根本原因を修正しているか
- フロントエンド: Provider/Notifier 層の責務分離、Riverpod パターン遵守
- バックエンド: Hono + Drizzle のレイヤー分離、GraphQL 型定義の整合性
- 認証、認可、機密情報露出の問題がないか
- contentHash / signature の整合性
- 変更箇所に必要なテストがあるか

必要に応じて使う資料:
- `.codex/prompts/reviewers/*.md`
- `.claude/rules/backend-implementation.md`
- `.claude/rules/frontend-implementation.md`
- `git diff main...HEAD`

出力:
- Findings
- 未確認事項
- 残リスク
