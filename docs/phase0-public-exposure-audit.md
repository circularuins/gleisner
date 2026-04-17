# Phase 0 Public Exposure Audit

> 最終更新: 2026-04-17
> 対象: Phase 0 リリース直前の「未ログインで何が見えるか」の確認

Phase 0 の戦略（Idea 022）は**「家族数名のライフログ + 閲覧のみ一般公開」**。
したがって `/@username` や `/discover` を未ログインで閲覧できること自体は意図的な仕様。
本監査の目的は、その前提のもとで **想定外の情報が漏れていないか** を確認すること。

## スコープ

- フロントエンド: Flutter Web SPA (Cloudflare Pages)
- バックエンド: Hono API (Railway)
- クローラー対策: `/robots.txt` + `<meta name="robots">` + OGP レスポンスの `X-Robots-Tag`（本 PR で導入）

## 1. フロントエンド公開ルート（Flutter GoRouter）

`frontend/lib/router.dart` の `redirect` ロジックで、未ログインでもアクセス可能なパスは以下:

| パス | 画面 | 露出内容 |
|------|------|---------|
| `/splash` | SplashScreen | ブランド表示のみ |
| `/login` | LoginScreen | ログインフォーム |
| `/signup` | SignupScreen | 新規登録フォーム（`?invite=` クエリ受け付け） |
| `/about` | AboutScreen | 運営者・連絡先・外部送信開示（Idea 022 Required） |
| `/discover` | DiscoverScreen | 公開アーティスト一覧（`profileVisibility = 'public'` のみ） |
| `/@:username` | PublicTimelineScreen | 公開アーティストのタイムライン（`profileVisibility = 'public'` のみ） |
| `/onboarding` | OnboardingScreen | サインアップ後フロー（認証必須だが redirect 経路として allow） |

**備考**:
- `/@:username` の `username` は正規表現 `^[a-zA-Z0-9_]{1,39}$` で厳格バリデーション済み（SSRF / オープンリダイレクト対策）
- `/discover` は PR #215 で意図的に未ログイン解放（Phase 0 の「閲覧のみ公開」戦略の一環）

## 2. バックエンド公開エンドポイント（Hono）

`backend/src/index.ts` で `authMiddleware` は全ルートに適用されるが、**失敗しても通す（soft auth）** 仕様。resolver 層で `ctx.authUser` を見て認可する。

| エンドポイント | 認証 | 露出内容 |
|--------------|------|---------|
| `GET /health` | 不要 | `{ status: "ok" / "error", db: "connected" / "disconnected" }`。内部 IP やバージョン情報なし |
| `GET /ogp/:atUsername` | 不要 | 公開アーティストの `displayName` / `bio` / `tagline` / `avatarUrl` / 正規 URL。OGP/Twitter Card 用 HTML。本 PR で `<meta name="robots" content="noindex,...">` + `X-Robots-Tag` ヘッダーを追加 |
| `GET/POST /graphql` | soft | resolver 層で個別認可 |

## 3. GraphQL 未認証クエリ面

`ctx.authUser` が `null` でも実行可能なクエリ一覧と、返却フィールド（公開データのみ）:

| クエリ | 返却対象 | 認可条件 |
|--------|---------|---------|
| `featuredArtist` | フィーチャー済み公開アーティスト 1 件 | `profileVisibility = 'public'` |
| `artist(username)` | 指定アーティスト | `checkArtistAccess()` で `public` のみ通過、private は `null` 返却 |
| `discoverArtists` | 公開アーティスト一覧（検索・ジャンル・ランキング） | `profileVisibility = 'public'` のみ |
| `genres` | ジャンル一覧（マスタデータ） | 制限なし（マスタのため OK） |
| `post(id)` / `posts` / `artistPosts` | 公開投稿（`visibility = 'public'`） | 認可フィルタ経路で private は除外 |
| `reactions(postId)` | 公開投稿のリアクション | 投稿の visibility に準拠 |
| `comments(postId)` | — | **Phase 0 では schema から除外済み（PR #219）** |

### 未認証で得られる付帯情報

- `tunedInCount`（そのアーティストの Tune In 数）
- `followersCount`（フォロワー数）
- `avatarUrl`、`bio`、`tagline`、`displayName`
- 公開投稿のリアクション・メディア URL

**Phase 0 戦略判断**: これらは Phase 0 の「閲覧のみ公開」の意図どおり。`robots.txt + noindex + X-Robots-Tag` でクローラー経由のスケール露出を防ぐ方針。

## 4. クローラー対策（本 PR で導入）

### 防御層

| 層 | 対策 | ファイル |
|----|------|---------|
| 静的 SPA | `frontend/web/robots.txt` で `Disallow: /` + LLM クローラー個別明示 | 新規作成 |
| 静的 SPA | `frontend/web/index.html` の `<meta name="robots" content="noindex,nofollow,noarchive,nosnippet">` | 編集 |
| OGP HTML | `<meta name="robots" content="noindex,...">` + `X-Robots-Tag` HTTP ヘッダー | `backend/src/routes/ogp.ts` |
| ネットワーク層 | Cloudflare Bot Fight Mode（Free tier）+ WAF rate limiting | Preflight メモリ参照（手動設定） |

### 対応しないもの（判断と根拠）

- **未認証 GraphQL フィールドレベルの隠蔽（tunedInCount 等）**: `/discover` のランキング順が壊れる。防御多重化より robots.txt + noindex の方針を優先
- **成人サインアップ時の `profileVisibility` デフォルトを `private` に変更**: `/discover` が空になり Phase 0 の「閲覧のみ公開」戦略と矛盾
- **`frontend/functions/[[path]].ts` の bot 検出を `/@username` 以外にも拡張**: `/manifest.json` や `/icons/*` の露出は低影響。Cloudflare Bot Fight Mode で対応

## 5. 既知の留意点

- `manifest.json` / `icons/*` / `flutter_bootstrap.js` は Cloudflare Pages の静的配信レイヤーから直接返されるため、SPA の `<meta name="robots">` は当たらない。`robots.txt` で `Disallow: /` を指定しているため well-behaved なクローラーはアクセスしない想定だが、Bot Fight Mode で多層防御
- OGP レスポンスは `Cache-Control: public, max-age=300` で Cloudflare CDN にキャッシュされる。Phase 1 リバート時はキャッシュパージが必要（`docs/phase1-revert-checklist.md` 参照）
- GraphQL introspection は本番で `useDisableIntrospection` プラグインにより無効化済み（`backend/src/graphql/index.ts`）

## 6. 関連 ADR / Idea

- **Idea 022**: Phase 0 Pre-launch Checklist（戦略の土台）
- **ADR 022**: 電気通信事業法届出（Phase 0 は不要扱い）
- **ADR 019**: Age Policy（未成年者データ保護）— 本監査と直接競合なし
- **ADR 020**: Security Architecture — Phase 1 Immediate/Short-term タスクは別スコープ

## 7. Phase 1 リバート時の参考

クロール拒否・露出監査に関する Phase 0 マーカーを `grep -rn PHASE_0_REVERT: gleisner/` で一括検出可能。手順は `docs/phase1-revert-checklist.md` を参照。
