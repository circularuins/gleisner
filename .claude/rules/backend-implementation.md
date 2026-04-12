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

### nullable フィールドのクリアパターン

**GraphQL の updateXxx mutation で nullable フィールドを「クリア（null に戻す）」する場合、以下のパターンに統一すること。**

GraphQL では `undefined`（変数に含めない）= 変更なし、`null`（明示送信）= クリア、という区別がある。Dart のフロントエンドから null を送信するために、フィールドの種類ごとに以下のパターンを使う：

```
【テキストフィールド（title, body 等）】
フロントエンド: 常に送信。空文字列 = クリアの意図
Provider: if (title != null) 'title': title.isEmpty ? null : title
バックエンド: args.title !== undefined → null で DB クリア

【非テキスト nullable フィールド（duration, thumbnailUrl, eventAt 等）】
フロントエンド: clearXxx フラグで明示。例: duration: value, clearDuration: true
Provider: if (value != null) 'field': value / if (clearField) 'field': null
バックエンド: args.field !== undefined → null で DB クリア
⚠ 相互排他チェック: if (value != null && clearField) { debugPrint(...); return null; }
```

**⚠ nullable フィールドを新規追加する場合、`clearXxx` フラグも同時に追加すること。** テキストフィールド（空文字列 = クリア）以外の全ての nullable フィールドに適用する。`if (value != null)` だけでは null を送信するパスがなく、既存値をクリアできない。

PR #142 の教訓: 空文字列経由で null を送ろうとすると `new Date('')` = Invalid Date が DB に入るリスクがある。日時フィールドには空文字列パターンを使わず、明示的な clear フラグを使うこと。

PR #173 の教訓: `duration`/`thumbnailUrl` に clearXxx がなく、3回の Critical 指摘を経て追加。新規 nullable フィールド追加時は初めから clearXxx を設計すること。

### 複合 mutation はトランザクション必須

**複数テーブルに書き込む mutation は `db.transaction()` で包むこと。** 後からロールバック処理を追加するアプローチは CASCADE 漏れ・孤児データのリスクがある。

```typescript
// ❌ 非トランザクション + 手動ロールバック — artists 等が CASCADE されない
const [{ id }] = await db.insert(users).values({ ... }).returning({ id: users.id });
const [claimed] = await db.update(invites).set({ usedBy: id }).where(...).returning(...);
if (!claimed) {
  await db.delete(users).where(eq(users.id, id)); // artists は残る
  throw new GraphQLError("...");
}

// ✅ トランザクション — 失敗時は全て自動ロールバック
const user = await db.transaction(async (tx) => {
  const [{ id }] = await tx.insert(users).values({ ... }).returning({ id: users.id });
  const [claimed] = await tx.update(invites).set({ usedBy: id }).where(...).returning(...);
  if (!claimed) throw new GraphQLError("...");
  return user;
});
```

該当パターン: signup + invite claim、将来の決済系 mutation 等。

### カスタム Scalar 追加チェックリスト

**⚠ GraphQL カスタム Scalar を追加する場合、以下を同時に実装すること:**

1. **`serialize`** — DB → クライアントへの出力変換
2. **`parseValue`** — 変数渡し（`$metadata: JSON`）の入力検証。**フロントエンドの主要経路**
3. **`parseLiteral`** — インラインリテラル（`metadata: { key: "val" }`）の入力検証

`parseValue` と `parseLiteral` の**両方にバリデーション**（深度制限、サイズ制限等）を実装すること。`parseLiteral` だけにバリデーションを入れても、変数渡しでは呼ばれないため本番でバイパスされる。

### CLI ツール（scripts/）のバイパス明示

**CLI ツールが API のビジネスルール（上限チェック、認証等）をバイパスする場合、理由をコメントで明示すること。**

```typescript
// ✅ バイパスの意図を明記
// admin-setup bypasses MAX_INVITES_PER_USER intentionally (CLI tool, not API)
async function generateInvites(db, createdBy) { ... }
```

将来のメンテナが「バグでは？」と疑わないように、「なぜバイパスが妥当か」を1行で説明する。

### R2/S3 presigned URL の注意事項

**`PutObjectCommand` の `ContentLength` は「上限」ではなく「正確なバイト数」の宣言。**

presigned URL に含まれる `Content-Length` は署名対象であり、クライアントが送信するファイルサイズと一致しなければ R2/S3 がリクエストを拒否する。「maxSize を渡せば上限制限になる」という誤解に注意。

```typescript
// ❌ maxSize を渡しても上限制限にならない — 実サイズと不一致で常にエラー
const command = new PutObjectCommand({
  ContentLength: limits.maxSize,
});

// ✅ クライアントから実サイズを受け取り、上限チェック後に渡す
if (contentLength > limits.maxSize) throw new R2ValidationError("...");
const command = new PutObjectCommand({
  ContentLength: contentLength,
});
```

### メディアタイプ別 URL バリデーション

**`mediaUrl` のバリデーションはメディアタイプによって使い分けること。**

- **image / video / audio**: `validateMediaUrl`（R2 ドメイン限定）
- **link**: `validateUrl`（任意の http/https URL）

PR #136 で全メディアタイプに `validateMediaUrl` を適用してしまい、link タイプの外部 URL 投稿ができなくなった。

```typescript
// ✅ createPost: args.mediaType で分岐
if (args.mediaType === "link") {
  validateUrl(args.mediaUrl);
} else {
  validateMediaUrl(args.mediaUrl);
}

// ✅ updatePost: 既存の post.mediaType も考慮
const effectiveType = (args.mediaType as string | undefined) ?? post.mediaType;
if (effectiveType === "link") {
  validateUrl(args.mediaUrl);
} else {
  validateMediaUrl(args.mediaUrl);
}
```

### 外部 SDK エラーのクライアント露出防止

**外部 SDK（AWS SDK、AI API 等）のエラーメッセージをクライアントにそのまま返さないこと。** バケット名、エンドポイント、認証情報の断片が含まれうる。

カスタムエラークラスで「クライアントに安全なエラー」と「内部エラー」を分離し、`instanceof` で判定する。文字列前方一致（`startsWith`）での分岐はメッセージ変更時にサイレントに壊れるため禁止。

```typescript
// ❌ 内部エラーをそのまま露出
throw new GraphQLError(err.message);

// ❌ 文字列前方一致 — メッセージ変更で壊れる
const message = err.message.startsWith("Content type ") ? err.message : "Failed";

// ✅ カスタムエラークラスで安全な境界を作る
if (err instanceof R2ValidationError) {
  throw new GraphQLError(err.message); // 安全なメッセージのみ
}
console.error("internal error:", err);
throw new GraphQLError("Failed to generate upload URL");
```

### テスト

- 共通ヘルパーは `src/graphql/__tests__/helpers.ts` に集約。新規テストファイルではこれを import
- 各テストファイルの `beforeEach` で `TRUNCATE users CASCADE` を実行
- **⚠ テスト実行後は seed データが消える。** 動作確認前に `./scripts/seed-test-data.sh` を再実行すること

### テストモックにビジネスロジックを再実装しない

**外部サービスのモックは固定値返却に留め、バリデーションロジックの検証は単体テストに委ねること。**

モック内に許可リスト・サイズ上限等のロジックを再実装すると、本体を変更してもモックが追従せず、テストが実態と乖離したまま通過する。定数は本体から `export` して共有する。

```typescript
// ❌ モック内にロジックを再実装 — 本体と乖離するリスク
vi.mock("../../storage/r2.js", () => ({
  generateUploadUrl: vi.fn(async (...) => {
    const allowed = { avatars: ["image/jpeg", ...] }; // ← r2.ts と二重管理
    if (!allowed[category].includes(contentType)) throw ...;
  }),
}));

// ✅ 定数は本体から import + モックは固定値返却
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("...")>();
  return {
    ...actual, // ALLOWED_CONTENT_TYPES, UPLOAD_LIMITS 等はそのまま
    generateUploadUrl: vi.fn(async () => ({
      uploadUrl: "https://test/upload", publicUrl: "https://test/file", key: "test",
    })),
  };
});
```

### 外部 URL フェッチの SSRF 対策

**バックエンドから外部 URL にリクエストを送る場合（OGP 取得等）、以下の SSRF 対策を必ず実施すること。**

```typescript
// 1. DNS 解決 → 全 IP がプライベートでないことを検証
await resolveAndValidate(hostname);
// 2. 元の hostname で fetch（IP 直接接続は TLS SNI を壊す）
const response = await fetch(url, { redirect: "manual" });
// 3. リダイレクト先も同じ検証を適用
```

チェックリスト:
- [ ] プライベート IP 拒否: IPv4（10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x）+ IPv6（::1, fc00::/7, fe80::/10, ::ffff:mapped）
- [ ] タイムアウト設定（5秒推奨）
- [ ] リダイレクト手動追跡（各ホップで IP 検証、最大 3 回）
- [ ] レスポンスサイズ制限（1MB 推奨、`</head>` で打ち切り可）
- [ ] **IP 直接接続は使わない** — TLS SNI が壊れ CDN/vhost で証明書不一致エラーになる
- [ ] TOCTOU リスク（DNS resolve → fetch 間のギャップ）はコメントで明記し許容判断を記録

PR #186 の教訓: IP 直接接続で DNS rebinding を防ごうとしたが TLS SNI 破壊 → hostname ベースに戻す往復が発生。

### Drizzle マイグレーションの型変更時の USING 句

**`pnpm db:generate` は `ALTER COLUMN SET DATA TYPE` を生成するが、`USING` 句は自動追加されない。** 暗黙キャスト不可な型変更（text → jsonb 等）では手動で `USING` 句を追記すること。

```sql
-- ❌ 自動生成のまま — 既存データでエラー
ALTER TABLE "posts" ALTER COLUMN "body" SET DATA TYPE jsonb;

-- ✅ USING 句を手動追記
ALTER TABLE "posts" ALTER COLUMN "body" SET DATA TYPE jsonb USING to_jsonb(body);
```

チェック手順:
1. `pnpm db:generate` 実行
2. 生成された SQL ファイルを Read して `SET DATA TYPE` を検索
3. 暗黙キャスト不可な変更には `USING` 句を追記
4. テスト環境で `pnpm db:migrate` を実行して成功を確認

PR #186 の教訓: text → jsonb の自動生成 SQL にUSING 句がなく、レビューで Critical 指摘。

### 新規クエリ追加時のインデックス

**WHERE 句で使われるカラムの組み合わせに対し、同じ PR 内でインデックスを追加すること。** 「テーブルが小さいから後で」は3回連続でレビュー指摘されて Critical に昇格する。

```typescript
// ❌ クエリだけ追加してインデックスを忘れる
const [{ count }] = await db
  .select({ count: sql`count(*)::int` })
  .from(posts)
  .where(and(eq(posts.authorId, userId), sql`${posts.ogFetchedAt} > ...`));

// ✅ Drizzle スキーマにインデックスを同時追加
export const posts = pgTable("posts", { ... }, (table) => [
  index("posts_author_og_fetched_idx").on(table.authorId, table.ogFetchedAt),
]);
```

PR #186 の教訓: OGP レートリミットと URL 再利用クエリにインデックスがなく、3回のレビューで Critical に昇格。初回で追加していれば2回分のレビューサイクルを節約できた。

### updatePost のフィールド間制約（effective value パターン）

**`updatePost` でフィールド間に制約がある場合、`args` の値だけでなく既存 `post` の値も組み合わせてバリデーションすること。** `args.field != null` だけでガードすると、関連フィールドだけ変更して制約対象フィールドを省略したケースで穴が生まれる。

```typescript
// ❌ args のみチェック — mediaType 変更 + duration 省略で既存値が新制限に違反
if (args.duration != null) {
  validateDuration(args.duration, effectiveType);
}

// ✅ effective value で既存値も再チェック
const effectiveDuration = args.duration ?? (post.duration as number | null);
if (effectiveDuration != null) {
  validateDuration(effectiveDuration, effectiveType);
}
```

該当パターン: duration × mediaType、将来の fileSize × mediaType 等、フィールド間に依存関係がある全ケース。

PR #195 の教訓: `args.duration != null` ガードだけでは text(120s) → video 変更時に 60s 制限をバイパスできた。

### バリデーションロジックの重複排除

**createPost / updatePost で同一のバリデーションロジックを書かないこと。** `validators.ts` にヘルパー関数を抽出し、両 mutation から呼び出す。

既存パターン: `validatePostVisibility`, `validateMediaUrl`, `validateDuration` 等が `validators.ts` に集約済み。新しいバリデーションを追加する場合も同様にヘルパーとして定義する。

### seed データとバリデーション制限の同期

**バリデーション制限（duration 上限、ファイルサイズ上限等）を変更した場合、`scripts/seed-test-data.sh` と `scripts/seed-discover-data.sh` の該当データも同時に更新すること。**

seed スクリプトの `create_post` は `> /dev/null` でエラーを握り潰すため、制限違反の投稿が無言で失敗する。失敗した投稿を参照する connection 作成も連鎖的に全滅する。

チェックリスト:
- [ ] 動画 duration 上限を変更した場合 → seed の全 video 投稿の duration を確認
- [ ] 音声 duration 上限を変更した場合 → seed の全 audio 投稿の duration を確認
- [ ] mediaUrl バリデーションを変更した場合 → seed の MEDIA_URL 構築ロジックを確認
- [ ] 新しい必須フィールドを追加した場合 → seed の `create_post` にフィールドを追加

PR #197 の教訓: PR #195 で動画60秒/音声300秒制限を追加したが seed データ未更新 → 12件の投稿が無言で失敗 → 17件の connection が全滅。

### MediaType enum 値の追加/変更チェックリスト

**⚠ MediaType の enum 値を追加・変更・削除する場合、以下を同時に更新すること:**

バックエンド:
1. `src/db/schema/post.ts` の `mediaTypeEnum` 配列
2. `src/graphql/types/post.ts` の `MediaTypeEnum` + `PostShape` の `mediaType` 型
3. `src/graphql/types/post.ts` の `createPost` バリデーション（型固有の制約）
4. `src/graphql/types/post.ts` の `updatePost` バリデーション（**createPost と同等の制約を漏れなく**）
5. `src/auth/signing.ts` の `computeContentHash`（型固有フィールドがある場合）
6. `src/graphql/__tests__/helpers.ts` の `CREATE_POST_MUTATION` 文字列（新引数追加時）
7. `src/graphql/__tests__/post.test.ts` の全テストで旧 enum 値を新値に置換
8. マイグレーション SQL（既存データの変換 + enum 再作成）
9. `scripts/seed-test-data.sh` + `scripts/seed-discover-data.sh` の投稿データ

フロントエンド:
10. `lib/models/post.dart` の `MediaType` enum + `_parseMediaType` + backward compat
11. `lib/graphql/queries/post.dart` の `postFields`（型固有フィールド追加時）
12. `lib/graphql/mutations/post.dart` の `createPostMutation` / `updatePostMutation`（新引数）
13. 全 switch expression（`dart analyze` で exhaustive check エラーとして検出可能）
14. `create_post_screen.dart` の型選択 UI + フォーム分岐
15. `edit_post_screen.dart` のフォーム分岐
16. `node_card.dart` のノード表示分岐
17. `post_detail_sheet.dart` のメディアエリア + コンテンツセクション分岐

PR #202 の教訓: text → thought + article の分割で 20箇所以上の同時更新が必要だった。switch exhaustive check のおかげでフロントエンドのコンパイルエラーは検出できたが、バックエンドのバリデーション漏れは3回のレビューで段階的に発見。

### updatePost のバリデーションは createPost と完全同等にする

**createPost に型固有のバリデーションを追加した場合、updatePost にも同じバリデーションを effective value パターンで追加すること。**

「effective value パターン」とは、`args` の値だけでなく既存の `post` の値も組み合わせてバリデーションすること。mediaType を変更する場合、変更後の型の制約を既存データにも適用する必要がある。

```typescript
// ❌ args のみチェック — mediaType 変更時に既存データをバイパス
if (args.mediaType === "thought") {
  if (args.title != null) throw ...;  // 既存の title は見ていない
}

// ✅ effective value で既存値も再チェック
const effectiveMediaType = args.mediaType ?? post.mediaType;
if (effectiveMediaType === "thought") {
  const effectiveTitle = args.title !== undefined ? args.title : post.title;
  if (effectiveTitle != null && effectiveTitle.trim() !== "") throw ...;
}
```

対象: mediaType 固有のバリデーション、フィールド間の cross-check（externalPublish × visibility 等）。

PR #202 の教訓: createPost に thought の制約を追加 → updatePost に忘れ → effective value も漏れ → 3回のレビューで段階的に修正。

### テスト helpers の mutation 文字列は引数追加時に必ず更新

**GraphQL mutation/query に新しい引数を追加した場合、`src/graphql/__tests__/helpers.ts` の対応する mutation 文字列にも同じ引数を追加すること。**

helpers の mutation 文字列に引数がないと、テストで変数として渡しても GraphQL が無視する（`undefined` として resolver に届く）。結果、バリデーションテストが空振りして通過してしまう。

```typescript
// ❌ helpers に bodyFormat がない → テストで bodyFormat: "delta" を渡しても無視される
const CREATE_POST_MUTATION = `
  mutation($trackId: String!, $mediaType: MediaType!, $body: String) {
    createPost(trackId: $trackId, mediaType: $mediaType, body: $body) { id }
  }
`;

// ✅ 新引数を追加
const CREATE_POST_MUTATION = `
  mutation($trackId: String!, $mediaType: MediaType!, $body: String, $bodyFormat: String) {
    createPost(trackId: $trackId, mediaType: $mediaType, body: $body, bodyFormat: $bodyFormat) { id }
  }
`;
```

PR #202 の教訓: `bodyFormat` と `externalPublish` を helpers に追加し忘れ、thought のバリデーションテストが空振り。インライン mutation で通ったことで原因が判明。
