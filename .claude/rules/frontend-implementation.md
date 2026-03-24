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

### Riverpod 3.x Notifier パターン

**新しい Notifier を作成する場合、以下のパターンに従うこと。**

- `DisposableNotifier` mixin を使用（`lib/providers/disposable_notifier.dart`）
- `build()` 内では `ref.watch` のみ使用（`ref.read` は非推奨）
- `build()` 冒頭で `initDisposable()` を呼び、async コールバック内で `if (disposed) return;` チェック
- DI が必要な依存（`FlutterSecureStorage` 等）は専用 Provider を作成してテストで override 可能にする

```dart
class FooNotifier extends Notifier<FooState> with DisposableNotifier {
  late GraphQLClient _client;

  @override
  FooState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const FooState();
  }
}
final fooProvider = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
```

**テストは `ProviderContainer` + `overrides` パターンを使用。** Notifier の直接インスタンス化は禁止。

```dart
final container = ProviderContainer(overrides: [
  graphqlClientProvider.overrideWithValue(mockClient),
]);
addTearDown(container.dispose);
final notifier = container.read(fooProvider.notifier);
```

### パブリック画面用 Notifier の設計原則

**未認証ユーザー向けの画面（`/@username` 等）に使う Notifier は、バックエンド mutation メソッドを持たせないこと。**

- ✅ `loadArtist`, `toggleTrack`, `computeLayout`, `showConstellation`（読み取り + ローカル UI 状態）
- ❌ `createTrack`, `toggleReaction`, `createConnection`（バックエンド mutation）
- バックエンドの 401 で弾かれるとはいえ、防御的設計として Notifier レベルで分離する
- `autoDispose` を使用して画面離脱時に状態をクリーンアップする

### パブリックルート追加時のセキュリティチェックリスト

**未認証アクセスを許可するルートを追加する場合、以下を確認すること。**

1. **認証バイパスの範囲**: `startsWith` ではなく正規表現完全一致で判定（`/@user/admin` 等のサブパスが通過しないように）
2. **入力バリデーション**: ルートパラメータを GraphQL 変数に渡す前にサニタイズ（`^[a-zA-Z0-9_]{1,39}$` 等）
3. **dispose 後の例外**: `autoDispose` + `addPostFrameCallback` の組み合わせで unmount 後に `ref.read` が呼ばれないよう `context.mounted` ガードを入れる
4. **RegExp の定数化**: `redirect()` 内で毎回生成せず、トップレベル定数にする

### Post フィールド追加チェックリスト

**⚠ Post にフィールドを追加する場合、以下を同時に更新すること:**
1. `frontend/lib/models/post.dart` の `Post` クラス — フィールド定義 + コンストラクタ + `fromJson`
2. `frontend/lib/providers/timeline_provider.dart` の `updatePostReactions` — 手動コピー箇所に追加
3. `frontend/lib/providers/timeline_provider.dart` の `_copyPostWith` — コピーヘルパーに追加
4. `frontend/lib/providers/create_post_provider.dart` の `submit` — Post 再構築箇所（接続追加時等）
