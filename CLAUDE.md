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

## ADR 駆動開発

**新機能の計画・実装を始める前に、必ず `docs/decisions/` と `docs/ideas/` の関連ドキュメントを読むこと。**

- ADR/Idea に設計済みの機能を独自に再設計してはいけない
- プランニング時は「この機能に関連する ADR/Idea は何か」を先にリストアップする
- **実装中の仕様判断でも ADR を再確認する**。「この設定は固定か可変か」「誰が変更できるか」等の判断を ADR に照らして行うこと（PR #119 教訓: artist visibility を一律固定にしたが、ADR 019 は「guardian が制御可能」だった）
- 特に以下の ADR は複数機能の土台であり、常に参照すること:
  - **ADR 008**: アーティストモード / ファンモード（モード判定、FAB 制御、編集 UI）
  - **ADR 009**: Discover タブ（アーティスト選択 → タイムライン遷移）
  - **ADR 013**: プロファイルとアーティストページ（Tune In、Follow、アバターレール、アーティスト登録フロー）

## Phase 移行互換性チェック（PR #117/119 の教訓）

**DB カラム追加・データモデル変更時に、将来の Phase で詰まないか確認すること。**

Phase 0 でユーザーが作成したデータが、Phase 1+ の機能追加時に特別な移行作業（admin 操作、DB 直接編集）なしで使えることを保証する。

チェックリスト:
- [ ] **新しいカラムは将来 required になりうるか？** → 初めから収集するか、nullable のまま後から入力を求める UI フローを設計する
- [ ] **既存ユーザーに null が残った場合、将来の機能が動作不能にならないか？**（例: `birth_year_month` が null → 年齢ティアが計算不能）
- [ ] **暗号鍵・署名チェーンに影響する変更か？** → 鍵ペアは正しく生成・暗号化保存し、将来の復号・鍵ローテーションパスを確保する
- [ ] **アカウント種別の矛盾が発生しうるか？**（例: self-managed なのに child 年齢 → Tier 不整合）→ バリデーションで防止する

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
flutter analyze       # 静的解析（flutter_lints）
dart format lib test  # Dart フォーマッタ
flutter gen-l10n      # ARB → AppLocalizations 再生成（文字列追加時に必須）
```

### テストデータ投入

```bash
./scripts/seed-test-data.sh           # デフォルト: localhost:4000
./scripts/seed-test-data.sh <api_url> # カスタム URL
```

seeduser（`seed@test.com` / `password123`）+ 6トラック + 32投稿（全メディアタイプ、2週間に分散）+ 20ジャンル + 4追加アーティスト + Tune In/Follow 関係を投入する。
バックエンドが起動済みであること。既にユーザーが存在する場合はログインしてデータを追加する。

> `seed-test-data.sh` は内部で `seed-discover-data.sh` を自動実行する。個別実行は不要。

**⚠ `pnpm test` 実行後は seed データが消える。** テストの `beforeEach` で `TRUNCATE users CASCADE` が実行されるため、テスト後に実機確認する場合は seed スクリプトを再実行すること。

### mise tasks（代替コマンド）

[mise](https://mise.jdx.dev/) がインストール済みであれば、上記の手動コマンドの代わりにタスクを使用できる。タスクは依存関係を自動解決する（例: `mise run test` は自動的に `build` を先行実行）。

```bash
mise run <タスク名>    # プロジェクトルートまたは backend/frontend ディレクトリから実行
mise tasks             # 利用可能なタスク一覧を表示
```

[mise monorepo](https://mise.jdx.dev/tasks/monorepo.html#monorepo-tasks) を有効化しているため、下記のコマンドは [monorepo task syntax](https://mise.jdx.dev/tasks/monorepo.html#task-path-syntax) 指定も可能

#### バックエンドタスク（`cd backend` で実行）

| タスク | 実行内容 | 自動依存 |
|--------|----------|---------|
| `start_dev` | 開発サーバー起動（`pnpm dev`） | `start_db` |
| `start_db` | PostgreSQL 起動（`docker compose up -d --wait`） | — |
| `stop_db` | PostgreSQL 停止 | — |
| `build` | TypeScript ビルド | — |
| `lint` | ESLint + Prettier 自動修正（`pnpm format` + `pnpm lint:fix`） | — |
| `test` | インテグレーションテスト | `build` |
| `seed_dev` | スキーマを DB に反映（`db:push`） | `build` |
| `seed_init_dev` | Discover 用データ投入（4アーティスト・20ジャンル） | — |
| `setup_new_local` | 初回セットアップ: `.env` コピー → DB 起動 → seed | — |
| `clean_cache_build` | `node_modules` / `dist` を削除 | — |
| `clean_docker` | Docker コンテナ・イメージ・ボリュームを全削除 | — |

#### フロントエンドタスク（`cd frontend` で実行）

| タスク | 実行内容 | 自動依存 |
|--------|----------|---------|
| `pub_get` | `flutter pub get` | — |
| `lint` | フォーマット + 静的解析 | `pub_get` |
| `run_web` | `flutter run` | — |
| `build` | `flutter build web` | `clean` |
| `test` | `flutter test` | — |
| `clean` | `flutter clean` | — |

### ⚠ `db:push` の注意事項

`db:push` はカラム追加時にテーブルを再作成する場合があり、**既存データが消失する**。
テストデータが蓄積している開発 DB では `db:generate` + `db:migrate` を使うか、事前に `pg_dump` でバックアップすること。

### Docker

```bash
docker compose up -d   # PostgreSQL 起動
docker compose down    # PostgreSQL 停止
```

## 実装ルール

バックエンド・フロントエンドの詳細な実装ルールは `.claude/rules/` に分離（自動読み込み）。

- `.claude/rules/backend-implementation.md` — UserType 分離、contentHash、認可チェック等
- `.claude/rules/frontend-implementation.md` — Provider 層ルール、Post フィールド追加チェックリスト等

## Git ワークフロー

**main ブランチへの直接 push は GitHub リポジトリルールで禁止。** 必ずブランチ → PR → マージのフローで作業すること。

- コミット前にブランチを切る: `git checkout -b feature-name`
- main で作業してしまった場合: `git checkout -b feature-name` で現在の変更をブランチに移す

## PR 前チェック（Gleisner 固有）

yatima ルートの共通チェック（ビルド・リンター・テスト・diff 確認）に加え、以下を実行:

```bash
# バックエンド
cd backend && pnpm build && pnpm lint && pnpm format:check && pnpm test

# フロントエンド
cd frontend && dart analyze lib/ && dart format --set-exit-if-changed . && flutter test
```

**`pnpm format:check` を忘れない。** `sed` 等でテストファイルを手動編集した後は特に注意。
