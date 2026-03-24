## フロントエンド実装ルール

### デザイントークンの使用

**新しい色・フォントサイズ・余白・角丸を使う場合、`lib/theme/gleisner_tokens.dart` に定義してから参照すること。**

- `Color(0xFF...)` のハードコードは禁止。トークン定数を使う
- 新しい値が必要な場合はトークンファイルに追加してからウィジェットで使う
- 既存トークンで近い値がある場合はそちらを使う（微妙な差のバリエーションを増やさない）

### データ操作・ビジネスロジックは Provider/Notifier 層で

**Widget 層から GraphQL クライアントを直接操作しない。** データの取得・変更・楽観的更新ロジックは必ず Provider/Notifier 経由で行う。

- ✅ `TimelineNotifier.toggleReaction(postId, emoji)` → Widget はコールバックで呼ぶだけ
- ❌ Widget 内で `client.mutate()` を直接実行
- ❌ Widget 内でリアクションのカウント計算やソートなどのビジネスロジックを実行

Widget が必要とするのはコールバック（`onToggleReaction`, `onReactionsChanged` 等）のみ。
楽観的更新（API 成功後のローカル状態更新）も Notifier 内で完結させる。
これにより テスト容易性・保守性・関心の分離 が保たれる。

### ボトムシートからボトムシートを開く場合

**`onSelected` コールバック内で `Navigator.pop(context, value)` を呼ばないこと。** picker 系ウィジェット（`RelatedPostPicker` 等）は内部で `Navigator.pop(context)` を呼ぶため、外から追加で pop すると二重 pop になり、親のボトムシートまで閉じてしまう。

```dart
// ❌ 二重 pop — picker 内部の pop + この pop で 2 回閉じる
onSelected: (post) => Navigator.pop(context, post),

// ✅ ローカル変数で受け取り、picker の pop に任せる
Post? selected;
await showModalBottomSheet<void>(
  builder: (_) => RelatedPostPicker(
    onSelected: (post) { selected = post; },
  ),
);
```

### Post フィールド追加チェックリスト

**⚠ Post にフィールドを追加する場合、以下を同時に更新すること:**
1. `frontend/lib/models/post.dart` の `Post` クラス — フィールド定義 + コンストラクタ + `fromJson`
2. `frontend/lib/providers/timeline_provider.dart` の `updatePostReactions` — 手動コピー箇所に追加
3. `frontend/lib/providers/timeline_provider.dart` の `_copyPostWith` — コピーヘルパーに追加
4. `frontend/lib/providers/create_post_provider.dart` の `submit` — Post 再構築箇所（接続追加時等）
