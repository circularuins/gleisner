# CLAUDE.md — Gleisner

このファイルは Gleisner 固有の Claude Code 設定です。
yatima ルートの CLAUDE.md（設計思想・共通ワークフロー）を継承した上で、本ファイルの技術スタック固有ルールが追加適用されます。

## プロジェクト概要

Gleisner は、アーティストの多面的な活動を **DAW 型マルチトラック・タイムライン**で発信する分散型プラットフォーム。

- 物理世界のクリエイティブ活動とデジタルプレゼンスを橋渡しする
- ユーザー（アーティスト）がデータとアイデンティティを自ら所有する
- 理不尽な BAN やプラットフォーム依存からの解放

### 命名の由来

Greg Egan "Diaspora" の **Gleisner robots**（物理世界とデジタル世界の橋渡し役）に由来。
詳細: `docs/decisions/002-naming-gleisner.md`

## 技術スタック

> **Status: Accepted** — ADR 015 で選定済み。

| レイヤー | 技術 | 備考 |
|----------|------|------|
| Frontend | Flutter 3.x (Dart) | Web first (CanvasKit)、後に iOS/Android 追加 |
| Backend | TypeScript + Hono | Node.js ランタイム（MVP） |
| Database | PostgreSQL 16 + Drizzle ORM | 型安全クエリ、Drizzle Kit でマイグレーション |
| API | GraphQL (yoga + pothos) | WebSocket Subscriptions でリアルタイム |
| Auth | JWT + Ed25519 鍵ペア | DID 互換（ADR 014） |
| Media | Cloudflare R2 | S3 互換、エグレス無料 |
| AI | Claude API (Haiku) | タイトル自動生成 |
| Hosting | Cloudflare Pages + Railway | フロント: Pages / バックエンド+DB: Railway |

## アーキテクチャ

- **API ファースト設計**: バックエンドとフロントエンドは完全分離。API を介してのみ通信する。
- **モノレポ構成**: `backend/` と `frontend/` が同居。

## 意思決定ドキュメント

`docs/decisions/` に ADR（Architecture Decision Records）を蓄積する。

- 新規 ADR は連番で追加: `NNN-slug.md`
- 既存 ADR の変更は「Superseded by」で新 ADR を参照
- フォーマット: タイトル / ステータス / コンテキスト / 決定 / 結果

## 開発コマンド

### 初回セットアップ

```bash
./scripts/dev-setup.sh
```

### 日常の開発

```bash
# バックエンド開発サーバー起動（PostgreSQL も自動起動）
./scripts/dev-start.sh

# フロントエンド開発（別ターミナル）
cd frontend && flutter run -d chrome
```

> **CORS 注意**: Flutter Web のポートは毎回変わるため、バックエンドは `CORS_ORIGIN=*` で起動する必要がある。
> `dev-start.sh` を使わず手動で起動する場合: `CORS_ORIGIN="*" pnpm dev`
> バックエンドのコード変更（スキーマ追加等）後はサーバー再起動が必要。

### バックエンド個別コマンド

```bash
cd backend
pnpm dev              # 開発サーバー（hot reload）
pnpm build            # TypeScript ビルド
pnpm lint             # ESLint 実行
pnpm lint:fix         # ESLint 自動修正
pnpm format           # Prettier でフォーマット
pnpm format:check     # フォーマットチェック（CI 用）
pnpm db:push          # スキーマをDBに反映（開発用）⚠ 下記注意
pnpm db:generate      # マイグレーションファイル生成
pnpm db:migrate       # マイグレーション実行
pnpm db:studio        # Drizzle Studio（DB GUI）
```

### フロントエンド個別コマンド

```bash
cd frontend
dart analyze           # 静的解析（flutter_lints）
dart format .          # Dart フォーマッタ
```

### テストデータ投入

```bash
./scripts/seed-test-data.sh           # デフォルト: localhost:4000
./scripts/seed-test-data.sh <api_url> # カスタム URL
```

seeduser（`seed@test.com` / `password123`）+ 6トラック + 32投稿（全メディアタイプ、2週間に分散）を投入する。
バックエンドが起動済みであること。既にユーザーが存在する場合はログインしてデータを追加する。

### ⚠ `db:push` の注意事項

`db:push` はカラム追加時にテーブルを再作成する場合があり、**既存データが消失する**。
テストデータが蓄積している開発 DB では `db:generate` + `db:migrate` を使うか、事前に `pg_dump` でバックアップすること。

### Docker

```bash
docker compose up -d   # PostgreSQL 起動
docker compose down    # PostgreSQL 停止
```

## 実装ルール

バックエンド・フロントエンドの詳細な実装ルールは `.claude/rules/` に分離。

@.claude/rules/backend-implementation.md
@.claude/rules/frontend-implementation.md

## PR 前チェック（Gleisner 固有）

yatima ルートの共通チェック（ビルド・リンター・テスト・diff 確認）に加え、以下を実行:

```bash
# バックエンド
cd backend && pnpm build && pnpm lint && pnpm format:check && pnpm test

# フロントエンド
cd frontend && dart analyze lib/ && dart format --set-exit-if-changed . && flutter test
```

**`pnpm format:check` を忘れない。** `sed` 等でテストファイルを手動編集した後は特に注意。
