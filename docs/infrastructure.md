# Infrastructure — Phase 0 Manual Setup

Gleisner Phase 0 のインフラは全て手動設定で運用する（Issue #152 の判断: 1人体制では IaC のオーバーヘッドが見合わないため、Phase 1 で OpenTofu 化を検討）。

このドキュメントは、本番環境を**ゼロから再構築**できることを目的として、手動設定の全項目を記録する。シークレット値そのものは記載せず、取得手順と設定方法のみを書く。

> ⚠ 本ドキュメントは「現状の手動設定の記録」であって、自動化されたデプロイ手順ではない。各項目は対応する dashboard / CLI で実行する。

---

## 1. 必要な外部アカウント

| サービス | 用途 | プラン |
|----------|------|--------|
| Cloudflare | R2 / Pages / DNS / WAF | Free |
| Railway | Backend + PostgreSQL | Hobby |
| Gmail | 連絡先 (`gleisner.app@gmail.com`) | Free |
| GitHub | ソースコードホスティング | Free |

ドメイン `gleisner.app` は Cloudflare Registrar で取得済み。

---

## 2. Cloudflare R2 (Media Storage)

### 2.1 バケット構成

| 環境 | バケット名 | 公開 URL |
|------|-----------|---------|
| 開発 | `gleisner-media-dev` | （開発のみ） |
| 本番 | `gleisner-media` | `https://media.gleisner.app` |

**バケット作成**: Cloudflare dashboard → R2 → Create bucket。場所は `Automatic`（or 東京）。

### 2.2 CORS Policy

R2 dashboard → 該当バケット → Settings → CORS Policy:

```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT"],
    "AllowedHeaders": ["Content-Type"],
    "MaxAgeSeconds": 3600
  }
]
```

- `PUT`: presigned URL へのアップロード
- `GET`: `Image.network` での画像表示
- AllowedOrigins を `*` にしている理由: Flutter Web の dev port が動的なため。Phase 1 で `https://gleisner.app` に絞る

### 2.3 カスタムドメイン + Transform Rules

`media.gleisner.app` を本番バケットの公開ドメインに設定（R2 → Settings → Public access → Custom Domains）。

カスタムドメイン経由では R2 の CORS が効かない場合があるため、Cloudflare → Rules → Transform Rules → Modify Response Header で以下を追加:

```
If: Hostname equals "media.gleisner.app"
Then: Set static
  Header: Access-Control-Allow-Origin
  Value:  *
```

### 2.4 API トークン

R2 dashboard → Manage R2 API Tokens → Create API Token:

- Permissions: **Object Read & Write**
- Specify buckets: `gleisner-media` のみ（最小権限）
- TTL: 任意（更新サイクルの目安は 1 年）

発行された `Access Key ID` / `Secret Access Key` / Account ID は Railway 環境変数に設定（§5）。

---

## 3. Cloudflare Pages (Frontend Hosting)

### 3.1 Pages プロジェクト

- リポジトリ: `gleisner/gleisner` (GitHub) を connect
- Build command: `cd frontend && flutter build web --release`
- Build output directory: `frontend/build/web`
- Root directory: `/`
- Environment variables: なし（API URL は build 時に inline せずビルド成果物の `index.html` で `<meta>` 等から差し込む方式を取っていれば不要）

### 3.2 カスタムドメイン

`gleisner.app` および `www.gleisner.app` を Pages プロジェクトに設定（Pages → Custom domains）。

### 3.3 Pages Functions (OGP プロキシ)

`frontend/functions/` にある Cloudflare Pages Functions が `/@:username` の SNS ボット UA を検出し、Hono バックエンドの OGP HTML エンドポイントにプロキシする。

詳細: `docs/phase0-public-exposure-audit.md` の「OGP プロキシ経路」セクションを参照。

---

## 4. Cloudflare Security (Phase 0 Crawler 対策)

Phase 0 はクローズドベータのため、検索エンジン・LLM クローラーからの index を拒否する。

### 4.1 Bot Fight Mode

Cloudflare → Security → Bots → Bot Fight Mode: **ON** (Free tier)

> Pro tier 移行時は **Super Bot Fight Mode** を検討。

### 4.2 WAF Rate Limiting

Cloudflare → Security → WAF → Rate Limiting Rules → Create rule:

| 項目 | 値 |
|------|---|
| Rule name | `graphql-non-browser-rate-limit` |
| If | `URI Path equals "/graphql"` AND `User Agent does not contain "Mozilla"` |
| Then | Block |
| Rate | 10 requests / 1 minute / IP |

R2 CORS Transform Rules と競合しないことを Cloudflare の rule order で確認。

### 4.3 robots.txt / noindex

実装済み（コード側）:
- `frontend/web/robots.txt` — `Disallow: /`
- `frontend/web/index.html` の `<meta name="robots" content="noindex,nofollow,...">`
- バックエンドの全レスポンスに `X-Robots-Tag: noindex, nofollow, noarchive, nosnippet`
- OGP プロキシも `X-Robots-Tag` ヘッダーを保全（PR #224 の教訓）

Phase 1 解除手順: `docs/phase1-revert-checklist.md` を参照。

---

## 5. Railway (Backend + PostgreSQL)

### 5.1 サービス構成

| サービス | 内容 |
|----------|------|
| Backend | Node.js (Hono) — `gleisner/backend` |
| PostgreSQL | Railway 内蔵 Postgres 16 |

### 5.2 環境変数

Railway dashboard → Backend service → Variables:

| 変数 | 値の取得元 | 備考 |
|------|----------|------|
| `DATABASE_URL` | Railway PostgreSQL から自動 inject | `${{Postgres.DATABASE_URL}}` |
| `JWT_PRIVATE_KEY` | §6.1 で生成 | Ed25519 PKCS#8 PEM、改行は `\n` |
| `JWT_PUBLIC_KEY` | §6.1 で生成 | Ed25519 SPKI PEM、改行は `\n` |
| `CORS_ORIGIN` | `https://gleisner.app` | 本番のみ。Flutter Web のドメインと一致 |
| `REQUIRE_INVITE` | `true` | Phase 0 はクローズドベータ |
| `R2_ACCOUNT_ID` | Cloudflare R2 dashboard | |
| `R2_ACCESS_KEY_ID` | §2.4 で発行 | |
| `R2_SECRET_ACCESS_KEY` | §2.4 で発行 | |
| `R2_BUCKET_NAME` | `gleisner-media` | デフォルトは `gleisner-media`（dev は `gleisner-media-dev`） |
| `R2_PUBLIC_URL` | `https://media.gleisner.app` | 末尾スラッシュなし |
| `NODE_ENV` | `production` | |
| `PORT` | （Railway 自動設定） | アプリが `process.env.PORT` を読む |

> ⚠ JWT 鍵は **dev と prod で必ず別物**にする。dev の鍵で発行した token が prod で通ってはならない。

### 5.3 自動バックアップ

Railway → PostgreSQL service → Backups → Schedule daily backups: **ON**

リリース直前に「最新の自動バックアップが取れているか」を dashboard で確認。

復旧テスト（Phase 0 リリース後早期に実施推奨）:
1. 開発環境で `pg_dump` を取得 → restore して seed が再現されること
2. Railway の backup snapshot をローカルに pull できることを `railway` CLI で確認

---

## 6. Backend Initial Setup

本番 DB に対して、リリース前に**1度だけ**実行する操作。

### 6.1 JWT Ed25519 鍵ペアの生成

```bash
cd backend
pnpm tsx scripts/generate-jwt-keys.ts
```

出力された `JWT_PRIVATE_KEY=...` と `JWT_PUBLIC_KEY=...` の 2 行を Railway 環境変数にコピー。改行は `\n` リテラルで保持される。

### 6.2 DB マイグレーション実行

```bash
railway run --service backend pnpm db:migrate
```

> ⚠ 本番では `db:push` を**使わない**。テーブル再作成でデータが消える可能性がある。Drizzle の migration ファイル経由で適用する。
> （参照: `project_gleisner_migration_policy.md`）

### 6.3 admin:setup（管理者 + 招待コード生成）

```bash
railway run --service backend pnpm admin:setup \
  --email gleisner.app@gmail.com \
  --username <admin-username> \
  --password <strong-password> \
  --display-name <admin-display-name>
```

実行後:
- `users` テーブルに admin アカウントが作成される
- `invites` テーブルに 5 件の招待コードが生成される（Phase 0 ファミリー配布用）
- 標準出力に招待コードが表示されるので**控えておく**（後から再表示できない）

### 6.4 REQUIRE_INVITE の有効化

§5.2 の `REQUIRE_INVITE=true` が設定されていることを確認 → Backend を再起動（Railway → Deployments → Redeploy）。

これ以降、招待コードなしでは `signup` mutation が `Invite required` で拒否される。

---

## 7. リリース後検証

### 7.1 デプロイ検証スクリプト

```bash
./scripts/verify-phase0-deploy.sh https://gleisner.app
```

確認項目（全 pass が必須）:
1. robots.txt が `Disallow: /` を返す
2. SPA `index.html` に `<meta name="robots" content="noindex">`
3. `X-Robots-Tag: noindex, nofollow, noarchive, nosnippet` 全レスポンスに付与
4. Twitterbot UA で `/@<seed>` が OGP HTML を返す（Pages Function プロキシ動作）
5. `/discover` が通常 UA で SPA を返し、bot UA で OGP に切り替わらない（中間ルーティング正常）

手動確認項目（スクリプトが指示する）:
6. Cloudflare Bot Fight Mode が ON
7. OGP プレビュー
   - Twitter Card Validator: <https://cards-dev.twitter.com/validator>
   - Facebook Debugger: <https://developers.facebook.com/tools/debug/>

### 7.2 EXIF 除去動作確認

GPS / カメラ情報付きのテスト画像を作成 → 本番にアップロード → R2 からダウンロードしてメタデータが除去されていることを確認:

```bash
# テスト画像生成（GPS 座標を埋め込む）
exiftool -GPSLatitude=35.6762 -GPSLongitude=139.6503 sample.jpg

# Flutter Web から投稿 → R2 からダウンロード
curl -O https://media.gleisner.app/<uploaded-key>

# メタデータが残っていないことを確認
exiftool downloaded.jpg
# → GPS / カメラ情報が表示されないこと
```

PR #231 でフロント側の sanitization は実装済みだが、本番経路でも再確認する（CDN キャッシュ・Transform Rules 経由でも除去されていること）。

### 7.3 開発バケットのクリア（任意）

開発中に `gleisner-media-dev` に溜まった orphan ファイルは Cloudflare dashboard から全削除可。本番には影響しない。

---

## 8. 連絡・サポート

- 運営連絡先: `gleisner.app@gmail.com`
- About ページ: `/about`（フッターに連絡先 + 外部送信開示を表示）

---

## 9. Phase 1 への移行で見直す項目

- [ ] CORS の `AllowedOrigins` を `*` から `https://gleisner.app` 等に絞る
- [ ] WAF Rate Limiting の閾値を一般公開向けに調整（10 req/min → より緩く）
- [ ] Bot Fight Mode を Super Bot Fight Mode に昇格（Pro tier 必要）
- [ ] OpenTofu/Terraform で Cloudflare + Railway を IaC 化（Issue #152 の Phase 1 計画）
- [ ] Phase 1 解除チェックリスト: `docs/phase1-revert-checklist.md`

---

## 関連ドキュメント

- `docs/phase0-roadmap.md` — Phase 0 タスク一覧と進捗
- `docs/phase0-public-exposure-audit.md` — 公開経路の監査
- `docs/phase1-revert-checklist.md` — Phase 1 移行時の対策反転手順
- `docs/decisions/` — Architecture Decision Records
- Issue #152 — IaC 評価とこのドキュメントの位置づけ

---

*最終更新: 2026-04-26 (Issue #152 対応として作成)*
