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

### ADR 運用ルール

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

## バックエンド実装ルール

### UserType vs PublicUserType

| 型 | 用途 | 含まれるフィールド |
|----|------|-------------------|
| `UserType` | `me` クエリ、`signup`/`login` の AuthPayload | id, did, email, username, displayName, bio, avatarUrl, publicKey, createdAt, updatedAt |
| `PublicUserType` | 公開クエリ（post author, reaction user, comment user, follow, tune-in） | id, did, username, displayName, bio, avatarUrl, createdAt |

- **新しい公開フィールドを追加する場合**: `PublicUserType` と `publicUserColumns` の両方を更新
- **DB クエリ**: `UserType` は `userColumns`、`PublicUserType` は `publicUserColumns` を使用。`select()` で全カラム取得は禁止（passwordHash 等が漏洩するため）

### contentHash / signature

- Post 作成・更新時に `contentHash`（SHA-256）を自動計算。対象: `JSON.stringify({ title, body, mediaUrl, mediaType, importance, duration })`
- `layoutX`/`layoutY` はプレゼンテーション用のため contentHash に含めない
- `signature`（Ed25519）はクライアントからのオプショナル引数。提供された場合は author の publicKey で検証
- 署名付き投稿のコンテンツ更新時は新しい署名が必須（署名の無断消去を防止）

**⚠ Post にコンテンツフィールドを追加する場合、以下の 3 箇所を同時に更新すること:**
1. `src/auth/signing.ts` の `computeContentHash` — ハッシュ計算対象に追加
2. `src/graphql/types/post.ts` の `contentChanged` 判定 — updatePost で変更検知に追加
3. `src/graphql/types/post.ts` の `newHash` 計算 — updatePost の既存値フォールバックに追加

### 認可チェック（認証ガード）の追加

**⚠ GraphQL フィールドに認証を追加する場合、以下の箇所を全て確認すること:**
1. **PostType 等のオブジェクトフィールド** — `builder.objectFields()` 内の resolve に `ctx.authUser` チェック
2. **トップレベルクエリ** — `builder.queryFields()` 内の同名クエリにも同じチェック（別経路でアクセス可能）
3. **テストファイル** — 該当クエリを呼ぶ全テストに認証トークンを渡す（`reaction.test.ts`, `public-user.test.ts` 等、複数ファイルに散在しうる）

### テスト

- 共通ヘルパーは `src/graphql/__tests__/helpers.ts` に集約。新規テストファイルではこれを import
- 各テストファイルの `beforeEach` で `TRUNCATE users CASCADE` を実行

## PR 前チェック（Gleisner 固有）

yatima ルートの共通チェック（ビルド・リンター・テスト・diff 確認）に加え、以下を実行:

```bash
# バックエンド
cd backend && pnpm build && pnpm lint && pnpm format:check && pnpm test

# フロントエンド
cd frontend && dart analyze lib/ && dart format --set-exit-if-changed . && flutter test
```

**`pnpm format:check` を忘れない。** `sed` 等でテストファイルを手動編集した後は特に注意。

## フロントエンド実装ルール

### データ操作は Provider/Notifier 層で

**Widget 層から GraphQL クライアントを直接操作しない。** データの取得・変更は必ず Provider/Notifier 経由で行う。

- ✅ `TimelineNotifier.toggleReaction(postId, emoji)` → Widget はコールバックで呼ぶだけ
- ❌ Widget 内で `client.mutate()` を直接実行

Widget が必要とするのはコールバック（`onToggleReaction`, `onReactionsChanged` 等）のみ。
これにより テスト容易性・保守性・関心の分離 が保たれる。
