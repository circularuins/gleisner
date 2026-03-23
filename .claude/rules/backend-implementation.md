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

### GraphQL フィールドの追加（フロントエンド → バックエンド整合性）

**フロントエンドの GraphQL クエリ/フラグメントにフィールドを追加する前に、バックエンドの GraphQL 型定義で当該フィールドが expose されているか確認すること。**

- Drizzle スキーマの DB カラムと GraphQL 型のフィールドは自動マッピングされない
- 例: `connections` テーブルに `sourceId` カラムがあっても、`ConnectionObjectType` で `t.exposeID("sourceId")` していなければ GraphQL から取得できない
- 不一致があるとフロントエンド側で `Cannot query field` エラーが出て全クエリが失敗する

### 認可チェック（認証ガード）の追加

**⚠ GraphQL フィールドに認証を追加する場合、以下の箇所を全て確認すること:**
1. **PostType 等のオブジェクトフィールド** — `builder.objectFields()` 内の resolve に `ctx.authUser` チェック
2. **トップレベルクエリ** — `builder.queryFields()` 内の同名クエリにも同じチェック（別経路でアクセス可能）
3. **テストファイル** — 該当クエリを呼ぶ全テストに認証トークンを渡す（`reaction.test.ts`, `public-user.test.ts` 等、複数ファイルに散在しうる）

### テスト

- 共通ヘルパーは `src/graphql/__tests__/helpers.ts` に集約。新規テストファイルではこれを import
- 各テストファイルの `beforeEach` で `TRUNCATE users CASCADE` を実行
- **⚠ テスト実行後は seed データが消える。** 動作確認前に `./scripts/seed-test-data.sh` を再実行すること
