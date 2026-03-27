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

### 認可フィルタの全経路統一

**同じデータに到達する全クエリ/リゾルバに同一の認可条件を適用すること。** 1つのクエリにフィルタを追加したら、同じデータを返す他の経路も漏れなく更新する。

例: 投稿一覧に `visibility` フィルタを追加する場合、以下の全経路を確認:
- `posts`（trackId 指定）
- `artistPosts`（artistId 指定）
- `ArtistType.recentPosts`（フィールドリゾルバ）
- `TrackType.posts`（フィールドリゾルバ）
- `post`（単体取得）

**owner の `isSelf` 分岐も統一する。** `posts` で owner が draft を見れるなら `artistPosts` でも同様にすること。非対称な認可条件はセキュリティホールになる。

### 共通ヘルパー抽出時の分岐網羅性

**認可チェックを共通ヘルパーに抽出する場合、返り値の「拒否」ケースで必ず early return すること。** 三項演算子で分岐すると拒否ケースが else に落ちて漏洩する。

```typescript
// ❌ 三項演算子 — accessible: false が public フィルタに落ちる
const filter = access.accessible && access.isSelf
  ? undefined
  : eq(posts.visibility, "public"); // ← false でもここに来る

// ✅ early return で拒否を明示
if (!access.accessible) return [];
const filter = access.isSelf ? undefined : eq(posts.visibility, "public");
```

### 件数上限付き INSERT は SELECT FOR UPDATE + トランザクション

**「COUNT で件数チェック → INSERT」パターンには必ず行ロックを使うこと。** READ COMMITTED では並列トランザクションが同時に COUNT を通過し、上限を超えて INSERT される（TOCTOU）。

```typescript
// ❌ トランザクションなし — 並列リクエストで上限突破
const existing = await db.select().from(table).where(eq(table.parentId, id));
if (existing.length >= MAX) throw new GraphQLError("Limit exceeded");
await db.insert(table).values({ ... });

// ✅ SELECT FOR UPDATE で親行をロック → COUNT → INSERT を原子化
await db.transaction(async (tx) => {
  await tx.execute(sql`SELECT 1 FROM parent_table WHERE id = ${id} FOR UPDATE`);
  const existing = await tx.select().from(table).where(eq(table.parentId, id));
  if (existing.length >= MAX) throw new GraphQLError("Limit exceeded");
  await tx.insert(table).values({ ... });
});
```

該当箇所: `addArtistGenre`（5件上限）、今後 `createTrack`（10件上限）にも適用すべき。

### N+1 クエリの解消パターン

**子リゾルバが親ごとに個別 SELECT を発行する N+1 は、JOIN + プリフェッチで解消する。**

2 つのパターンがあるが、**オブジェクト埋め込み**を推奨（context を汚さない）。

```typescript
// ✅ 推奨: オブジェクト埋め込み（ArtistGenreType パターン）
// 親リゾルバで JOIN して _genre を付与
builder.objectFields(ArtistType, (t) => ({
  genres: t.field({
    resolve: async (artist) => {
      const rows = await db.select({ ..., genre: genres })
        .from(artistGenres)
        .innerJoin(genres, eq(artistGenres.genreId, genres.id))
        .where(eq(artistGenres.artistId, artist.id));
      return rows.map((r) => ({ ...r, _genre: r.genre }));
    },
  }),
}));
// 子リゾルバでプリフェッチ済みデータを返す
genre: t.field({
  resolve: async (ag) => {
    if (ag._genre) return ag._genre; // DB クエリなし
    // フォールバック（mutation 等のプリフェッチなしパス用）
    const [g] = await db.select().from(genres).where(eq(genres.id, ag.genreId)).limit(1);
    return g;
  },
}),
```

```typescript
// ✅ 代替: コンテキストキャッシュ（tuneInArtistCache パターン）
// 親リゾルバで JOIN → ctx.cache に格納
ctx.tuneInArtistCache = new Map();
for (const row of rows) ctx.tuneInArtistCache.set(row.artistId, row.artist);
// 子リゾルバで cache から取得
const cached = ctx.tuneInArtistCache?.get(id);
if (cached) return cached;
```

該当箇所: `ArtistGenreType.genre`（埋め込み）、`TuneInType.artist`（キャッシュ）。

### Drizzle ORM: nullable カラムでの eq() 型エラー

**nullable カラム（`NOT NULL` なし）に対して `eq()` を使うと TypeScript の型エラーになる。** `sql` テンプレートを使うこと。

```typescript
// ❌ nullable カラムでは型エラー
.where(eq(posts.trackId, trackId))

// ✅ sql テンプレートで回避
.where(sql`${posts.trackId} = ${trackId}`)
```

`innerJoin` の ON 句でも同様。Drizzle の `eq()` は non-null カラム前提の型定義。

### スキーマ変更チェックリスト

**⚠ DB カラムの nullable 化・onDelete 変更・カラム削除を行う場合、以下を同時に修正すること:**

1. **Drizzle スキーマ** — `src/db/schema/*.ts` のカラム定義
2. **GraphQL 型定義** — `objectRef<{ ... }>` の TypeScript 型を nullable に変更（例: `trackId: string` → `string | null`）
3. **GraphQL resolver** — 該当カラムを参照する全 resolver で null チェック追加
4. **クエリの `eq()` 呼び出し** — nullable カラムでは `sql` テンプレートに切り替え
5. **認可ロジック** — nullable になった FK を経由する認可チェックが null 時にバイパスされないか確認
6. **マイグレーション** — `pnpm db:generate` + `pnpm db:migrate`（または `db:push`）

### テスト

- 共通ヘルパーは `src/graphql/__tests__/helpers.ts` に集約。新規テストファイルではこれを import
- 各テストファイルの `beforeEach` で `TRUNCATE users CASCADE` を実行
- **⚠ テスト実行後は seed データが消える。** 動作確認前に `./scripts/seed-test-data.sh` を再実行すること
