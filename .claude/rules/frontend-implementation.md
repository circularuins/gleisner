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

### 表示ウィジェットにナビゲーションを混ぜない

**再利用可能なウィジェット（Hero、Card、Layout 等）の中で `context.go()` / `context.push()` を直接呼ばないこと。** ナビゲーション決定は Screen/Page レベルで行い、子ウィジェットには `VoidCallback` で渡す。

- ✅ `AuthLayout(onTryIt: () => context.go('/@seeduser'))` → Screen がルーティングを決定
- ❌ ウィジェット内部で `context.go('/some-route')` をハードコード

これにより テスタビリティ（GoRouter 不要でテスト可能）・再利用性（異なる画面で別の遷移先を指定可能）が保たれる。

### サーバーエラーメッセージを UI に露出しない

**`catch` ブロックや GraphQL エラー分岐で `e.toString()` や `result.exception?.graphqlErrors.firstOrNull?.message` をそのまま UI に表示しないこと。** サーバーの内部実装詳細（テーブル名、制約名、スタックトレース）がユーザーに漏れるリスクがある。

- ✅ `debugPrint('[Context] error: $e');` でログ + `'Something went wrong. Please try again.'` を UI に表示
- ❌ `setState(() { _error = e.toString(); })` で生エラーを表示
- ❌ `_error = result.exception?.graphqlErrors.firstOrNull?.message` でサーバーメッセージを直接表示

### 「自分のアーティスト情報」と「閲覧中のアーティスト」を混同しない

**`timelineProvider.artist` は現在閲覧中のアーティストを返す。ファンモードでは他人のデータになる。**
「自分がアーティストか」「自分のアーティスト名は何か」の判定には必ず `myArtistProvider` を使うこと。

- ✅ `ref.watch(myArtistProvider)` — Profile 画面での表示、`isSelf` 判定、`_ownArtistUsername` の取得
- ❌ `ref.watch(timelineProvider).artist` — ファンモードでは他人のデータが入る

これを誤ると、ファンユーザーに他人のアーティスト情報が表示される、`isSelf` 判定が常に true になる等のバグが発生する。

### ファンモードの UI 制御（mutation UI の出し分け）

**ファンモードでは mutation UI（connections, constellation naming）を非表示、リアクションは常に有効。**

制御方法: detail sheet や node card のコールバックを null で渡し、受け側で null チェックして UI を出し分ける。

```dart
// Screen 側（_openDetailSheet）
onCreateConnection: isOwn ? (src, tgt) => notifier.createConnection(src, tgt) : null,
onToggleReaction: (id, emoji) => notifier.toggleReaction(id, emoji), // 常に有効
```

```dart
// Widget 側（post_detail_sheet.dart）
if (widget.onCreateConnection != null)
  GestureDetector(onTap: _addConnection, child: Text('Link post')),
```

新しい mutation UI を追加する場合、**必ず null チェックによる出し分けを実装すること**。

### build() 内で「一度だけ消費する値」を扱わない

**`ref.watch` + `addPostFrameCallback` で Provider の値を消費すると、rebuild のたびに多重発火する。**
一度だけ消費する通知的な値（`pendingArtistProvider` 等）は `ref.listenManual` を `initState` で設定する。

```dart
// ❌ build() 内 — rebuild のたびに発火
final pending = ref.watch(pendingProvider);
if (pending != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) { ... });
}

// ✅ initState で一度だけ設定
ref.listenManual(pendingProvider, (prev, next) {
  if (next != null) {
    ref.read(pendingProvider.notifier).clear();
    _handlePending(next);
  }
});
```

### シングルトン Provider の状態汚染防止

**複数画面で同じ `NotifierProvider` を使い回す場合、前の画面のデータが次の画面で一瞬表示される。** `load` メソッドの冒頭で state を完全リセットし、`FetchPolicy.networkOnly` でキャッシュも回避する。

```dart
// ✅ loadX の冒頭で完全リセット
Future<void> loadX(String id) async {
  state = const XState(isLoading: true); // 前のデータを完全クリア
  final result = await _client.query(QueryOptions(
    document: gql(query),
    variables: {'id': id},
    fetchPolicy: FetchPolicy.networkOnly, // キャッシュからの stale データ排除
  ));
  ...
}
```

`FamilyNotifier` は Riverpod 3.x で使用不可のため、state リセット方式が標準パターン。

### ウィジェットのオーバーレイ位置合わせ

**`localToGlobal` でオーバーレイの位置を計算しない。** Scaffold/AppBar/SafeArea のオフセットが累積してズレる。代わりに `CompositedTransformTarget` + `CompositedTransformFollower`（Flutter の Tooltip と同じ仕組み）を使う。

```dart
// ✅ LayerLink でターゲットとフォロワーを接続
final _link = LayerLink();

// ターゲット（位置の基準となるウィジェット）
CompositedTransformTarget(
  link: _link,
  child: MyButton(...),
)

// フォロワー（ターゲットに追従するオーバーレイ）
CompositedTransformFollower(
  link: _link,
  offset: Offset(-12, -170), // ターゲットからの相対オフセット
  child: MyTooltip(...),
)
```

```dart
// ❌ localToGlobal は Scaffold 内のウィジェットで座標がズレる
final pos = renderBox.localToGlobal(Offset.zero); // AppBar 分ズレる
```

### 非同期ロード Provider の isLoaded ガード

**ストレージから非同期ロードする Provider は、ロード完了前のデフォルト値で UI が誤動作する。** `isLoaded` フラグで「まだ読み込み中」と「空」を区別する。

```dart
// ✅ ロード完了を区別する State
class SettingsState {
  final Map<String, String> values;
  final bool isLoaded;
  const SettingsState({this.values = const {}, this.isLoaded = false});
}

// UI 側: isLoaded が false の間は表示を抑制
if (state.isLoaded && !state.values.containsKey('seen')) {
  showTutorial();
}
```

```dart
// ❌ 空のデフォルト値とロード未完了を区別できない
Set<String> build() {
  _loadFromStorage(); // await していない
  return {};          // ロード前もロード後も同じ空集合
}
```

### チュートリアル実装ガイドライン

**新しいチュートリアルを追加する際は、以下のパターンに従うこと。**

1. **ID 登録**: `TutorialIds` に定数を追加（`static const firstTuneIn = 'first_tune_in';`）
2. **表示条件**: `build()` 内で `tutorialState.isLoaded && !tutorialState.seen.contains(id)` + 画面固有の条件
3. **ターゲット**: FAB 等のターゲットを `CompositedTransformTarget` + `LayerLink` で wrap
4. **オーバーレイ**: `TutorialSpotlight` を `Stack` + `Positioned.fill` で画面に重ねる
5. **dismiss**: タップで `markSeen(id)` + `setState(() => _showTutorial = false)`
6. **ログアウト**: `tutorialProvider.reset()` + `invalidate` で次ユーザーにリセット

設計原則:
- コンテキスト型（機能を初めて使うタイミングで表示）
- 1つずつ（同時に複数表示しない）
- 短いコピー（メッセージ < 140文字）
- タップで dismiss（ブロッキングしない）
- ブランド整合（星座/宇宙メタファー）
- 永続化（`FlutterSecureStorage` で1回だけ表示）

### Mutation 後の一覧データ反映（GraphQL キャッシュ問題）

**mutation でデータを変更した後、影響を受ける一覧クエリが最新データを返すようにすること。** GraphQL クライアントのデフォルト `FetchPolicy` はキャッシュ優先のため、mutation 後もキャッシュから stale データが返される。

```dart
// ❌ invalidate だけでは Notifier が再取得しない場合がある
ref.invalidate(discoverProvider);

// ✅ 明示的に再取得を呼ぶ
ref.read(discoverProvider.notifier).loadInitial();
```

一覧クエリ側でも `FetchPolicy.networkOnly` を設定して、キャッシュをバイパスする:

```dart
// ✅ mutation の影響を受ける一覧クエリには networkOnly
QueryOptions(
  document: gql(discoverArtistsQuery),
  fetchPolicy: FetchPolicy.networkOnly,
)
```

該当パターン: visibility 変更後の Discover リロード、投稿編集後のタイムライン更新、プロフィール編集後の再取得。

### リスト state の更新は新しいインスタンスで

**`setState` でリストを更新する場合、`.add()` / `.removeWhere()` ではなく新しいリストインスタンスを作ること。** 同じ参照のまま中身だけ変えると、Flutter がリストの変更を検知できず再描画をスキップする。

```dart
// ❌ ミュータブル操作 — setState しても再描画されない場合がある
setState(() {
  _items.add(newItem);
});

// ✅ 新しいリストを作る
setState(() {
  _items = [..._items, newItem];
});

// ✅ 削除も同様
setState(() {
  _items = _items.where((i) => i.id != targetId).toList();
});
```

### Bottom sheet 内の楽観的更新（グラフ双方向同期）

**`showModalBottomSheet` で渡したデータ（`widget.allPosts` 等）はシートが閉じるまで不変。** シート内で楽観的にローカル state を更新する場合、以下に注意:

1. ローカル state の変更は現在の Widget の `setState` で反映できる
2. ただし `widget.allPosts` 内の**他のオブジェクト**は古いまま
3. グラフ構造（connection 等）は双方向なので、ソース側を更新したらターゲット側も同期が必要
4. 「ローカル state で差し替えた allPosts ビュー」を計算するヘルパー getter が必要

例: connection 追加時、`_outgoingConnections` に追加するだけでは `findConstellation` がターゲット投稿の `incomingConnections` を見て不整合になる。`_allPostsWithLocalConnections` のようなヘルパーで双方向の整合性を保つ。

### ログアウト時のプロバイダー invalidate

**ログアウト処理では `graphqlClientProvider` だけでなく、ユーザー固有の状態を持つ全プロバイダーを invalidate すること。**

```dart
await ref.read(authProvider.notifier).logout();
ref.invalidate(graphqlClientProvider);
ref.invalidate(timelineProvider);
ref.invalidate(myArtistProvider);
ref.invalidate(tuneInProvider);
ref.invalidate(discoverProvider);
```

invalidate を忘れると、次にログインしたユーザーに前ユーザーのデータが表示される。

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

### ビジュアル差別化は「動き」で表現する（Motion over shape）

**同種の UI 要素を視覚的に区別する場合、形状のバリエーションではなく動きのバリエーションを優先すること。**（ADR 024）

- ❌ 線の形状を変える（zigzag, helix, arrowhead 等）→ ノイジーになり constellation の美しさを壊す
- ✅ 動きのパラメータを変える（速度カーブ、方向、ドット数、脈動）→ 視覚的に静かだが発見可能

PR #89 で synapse の形状バリエーションを6回試行し全て revert した教訓に基づく。

### enum 導入時の全経路一括変更

**`String` リテラルを `enum` に置き換える場合、以下を原子的に（1コミットで）変更すること。**

1. `enum` 定義を追加（モデル層: `models/post.dart` 等）
2. `grep` で全出現箇所を洗い出し（lib/ と test/ の両方）
3. public API（Provider のメソッドシグネチャ、callback 型定義）を変更
4. private メソッド・内部変数を変更
5. GraphQL 送信箇所で `.name` に変換（境界のみ String）
6. テストヘルパー・テストデータの型を変更
7. `dart analyze` でエラーゼロを確認

途中で止めると、レビューのたびに「まだ String が残っている」と指摘される（PR #89 で3回のレビューを要した教訓）。

### CustomPainter フィールド追加チェックリスト

**⚠ CustomPainter にフィールドを追加する場合、以下を同時に更新すること:**

1. コンストラクタにパラメータ追加
2. `shouldRepaint` の比較条件に追加（**忘れると描画更新が欠落する**）
3. 該当フィールドのテストを `shouldRepaint` テストグループに追加

### Mutation 後の re-fetch には networkOnly が必須

**mutation でデータが変わった後の Provider `load()` は `FetchPolicy.networkOnly` を使うこと。**

GraphQL クライアントのデフォルト `FetchPolicy` は `cacheFirst`。mutation 前のレスポンス（例: `myArtist: null`）がキャッシュされていると、mutation 後に `load()` しても**キャッシュから stale データが返る**。

```dart
// ❌ cacheFirst（デフォルト） — mutation 後も古い null を返す
final result = await _client.query(
  QueryOptions(document: gql(myArtistQuery)),
);

// ✅ networkOnly — 必ずサーバーから最新データを取得
final result = await _client.query(
  QueryOptions(
    document: gql(myArtistQuery),
    fetchPolicy: FetchPolicy.networkOnly,
  ),
);
```

PR #112 で6回の修正試行の末にデバッグログで判明した教訓。`timelineProvider` は最初から `networkOnly` だったが `myArtistProvider` は未設定で、アーティスト登録後に FAB が表示されなかった。

### StatefulShellRoute タブ間の listenManual 制限

**`ref.listenManual` は StatefulShellRoute の異なるタブ間で通知が届かない場合がある。**

GoRouter の `StatefulShellRoute` はタブごとに独立した Widget ツリーを保持する。Profile タブで Provider の state を変更しても、Timeline タブの `listenManual` に通知が届かないことがある。

**対処法**: タブをまたぐ state 変更後に遷移する場合、遷移先の画面に依存するデータを**遷移元で明示的に await してからナビゲーション**する。

```dart
// ✅ Profile から Timeline に遷移する前にデータを準備
await ref.read(myArtistProvider.notifier).load();
await ref.read(timelineProvider.notifier).loadArtist(username);
if (!context.mounted) return;
context.go('/timeline');
```

listener に頼らず、遷移元の責任でデータを揃えるパターン。

**JWT 差し替え後も同様。** `guardianProvider.switchToChild` / `switchBackToGuardian` で JWT を書き換えた後、`invalidate` だけではタブのデータが更新されない。`invalidate` + 明示的な `load()` の両方が必要。

```dart
// ✅ JWT switch 後のリロードパターン
ref.invalidate(myArtistProvider);
ref.invalidate(timelineProvider);
ref.invalidate(discoverProvider);
// invalidate だけでは不十分 — 明示的に再取得
await ref.read(myArtistProvider.notifier).load();
ref.read(discoverProvider.notifier).loadInitial();
```

### User を返す GraphQL クエリのフィールド同期（PR #119 の教訓）

**`User` を返す新しい GraphQL クエリ/ミューテーションを定義する場合、`User.fromJson` の required フィールドを全て含めること。**

`_userFields`（`lib/graphql/queries/auth.dart`）のようなフィールド定数を使うか、個別にフィールドをリストする場合は `User.fromJson` のコンストラクタを確認する。

```dart
// ❌ 一部フィールドだけリスト — fromJson でキャストエラー（ローディングが永遠に終わらない）
const myChildrenQuery = r'''
  query MyChildren {
    myChildren { id username displayName createdAt }
  }
''';

// ✅ フィールド定数を使って漏れを防止
const _childUserFields = '''
  id did email username displayName bio avatarUrl
  profileVisibility publicKey birthYearMonth isChildAccount
  createdAt updatedAt
''';
const myChildrenQuery = '''
  query MyChildren { myChildren { $_childUserFields } }
''';
```

該当パターン: `myChildren`, `switchToChild`, `switchBackToGuardian` 等、`User` 型を返す全クエリ。
