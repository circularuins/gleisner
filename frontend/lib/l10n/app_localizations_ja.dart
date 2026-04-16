// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Gleisner';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get close => '閉じる';

  @override
  String get add => '追加';

  @override
  String get create => '作成';

  @override
  String get next => '次へ';

  @override
  String get finish => '完了';

  @override
  String get confirm => '確認';

  @override
  String get retry => '再試行';

  @override
  String get loading => '読み込み中...';

  @override
  String get remove => '削除';

  @override
  String get register => '登録';

  @override
  String get navTimeline => 'タイムライン';

  @override
  String get navDiscover => 'ディスカバー';

  @override
  String get navProfile => 'プロフィール';

  @override
  String actingAsChild(String childName) {
    return '$childName として操作中';
  }

  @override
  String get exitChildMode => '戻る';

  @override
  String get signIn => 'ログイン';

  @override
  String get signUp => '新規登録';

  @override
  String get login => 'ログイン';

  @override
  String get loginSubtitle => 'アカウントにログイン';

  @override
  String get signupSubtitle => 'アカウントを作成';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get confirmPassword => 'パスワード確認';

  @override
  String get displayName => '表示名';

  @override
  String get displayNameHint => '表示したい名前';

  @override
  String get username => 'ユーザー名';

  @override
  String get birthYearMonth => '生年月';

  @override
  String get year => '年';

  @override
  String get month => '月';

  @override
  String get inviteCode => '招待コード';

  @override
  String get inviteCodeHint => '招待コードを入力';

  @override
  String get createAccount => 'アカウント作成';

  @override
  String get alreadyHaveAccount => 'アカウントをお持ちですか？ログイン';

  @override
  String get noAccount => 'アカウントをお持ちでないですか？新規登録';

  @override
  String get pleaseConfirmPassword => 'パスワードを再入力してください';

  @override
  String get passwordsDoNotMatch => 'パスワードが一致しません';

  @override
  String get emailRequired => 'メールアドレスは必須です';

  @override
  String get invalidEmailFormat => 'メールアドレスの形式が正しくありません';

  @override
  String get usernameRequired => 'ユーザー名は必須です';

  @override
  String get usernameFormat => '英数字・アンダースコア（2〜30文字）';

  @override
  String get passwordRequired => 'パスワードは必須です';

  @override
  String get passwordMinLength => '8文字以上で入力してください';

  @override
  String fieldRequired(String fieldName) {
    return '$fieldNameは必須です';
  }

  @override
  String get invalidInviteCode => '招待コードの形式が正しくありません';

  @override
  String get welcomeToGleisner => 'Gleisner へようこそ';

  @override
  String get yourCreativeUniverseAwaits => 'あなただけの創作空間が、ここに。';

  @override
  String get personalAccountTitle => 'パーソナルアカウント';

  @override
  String get personalAccountDesc =>
      'アーティストを発見し、トラックをフォローし、タイムラインを作りましょう。Gleisner でのあなたの個人アイデンティティです。';

  @override
  String get artistUpgradeTitle => '+ アーティストアップグレード';

  @override
  String get artistUpgradeDesc =>
      'アーティストページを作成し、トラックを設定し、作品を発信しましょう。登録後いつでもアップグレードできます。';

  @override
  String get getStarted => 'はじめる';

  @override
  String welcomeUser(String displayName) {
    return 'ようこそ、$displayNameさん！';
  }

  @override
  String get accountReady => 'パーソナルアカウントの準備ができました。';

  @override
  String get featureTimeline => 'タイムライン';

  @override
  String get featureDiscover => 'アーティストを発見';

  @override
  String get featureTuneIn => 'アーティストをチューンイン';

  @override
  String get readyToShare => '作品を共有する準備はできましたか？';

  @override
  String get artistUpgradeExplain =>
      '今のアカウントはそのまま使えます。アーティストプロフィールは、創作活動専用の「もうひとつの顔」です。';

  @override
  String get becomeAnArtist => 'アーティストになる';

  @override
  String get exploreGleisner => 'Gleisner を探索する';

  @override
  String get profile => 'プロフィール';

  @override
  String joinedDate(String date) {
    return '$date に登録';
  }

  @override
  String tunedInCount(int count) {
    return '$count チューンイン';
  }

  @override
  String get artist => 'アーティスト';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count トラック',
    );
    return '$_temp0';
  }

  @override
  String get artistRegistration => 'アーティスト登録';

  @override
  String get yourMusicYourStory => 'あなたの音楽、あなたの物語。';

  @override
  String get returnToMyAccount => '自分のアカウントに戻る';

  @override
  String switchToChild(String childName) {
    return '$childName に切り替え';
  }

  @override
  String childAccountName(String childName) {
    return '$childName のアカウント';
  }

  @override
  String get logout => 'ログアウト';

  @override
  String get deleteAccount => 'アカウント削除';

  @override
  String get logoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get deleteAccountConfirmTitle => 'このアカウントを削除しますか？';

  @override
  String get cannotBeUndone => 'この操作は取り消せません。';

  @override
  String get enterPasswordToConfirm => '確認のためパスワードを入力してください';

  @override
  String get deleteAccountWarning => '以下のデータが完全に削除されます：';

  @override
  String get deleteAccountDetails =>
      '• アカウントとプロフィール\n• アーティストプロフィール（存在する場合）\n• すべての投稿、トラック、つながり\n• アップロードしたすべてのメディア（画像・動画・音声）\n• 管理下のすべての子アカウント\n　（アーティストプロフィールとメディアを含む）';

  @override
  String get deleteAccountFailed => 'アカウントの削除に失敗しました。パスワードを確認してください。';

  @override
  String get editProfile => 'プロフィール編集';

  @override
  String get tapToChange => 'タップして変更';

  @override
  String get bio => '自己紹介';

  @override
  String get profileVisibility => 'プロフィール公開設定';

  @override
  String get public => '公開';

  @override
  String get private => '非公開';

  @override
  String get privateLocked => '非公開（ロック中）';

  @override
  String get artistVisibilityPrivateDesc =>
      'アーティストページはディスカバーや検索に表示されません。既存のファンやダイレクトリンクからのみアクセスできます。';

  @override
  String get artistVisibilityPublicDesc =>
      'アーティストページはディスカバーや検索に表示されます。誰でもプロフィールを閲覧し、チューンインできます。';

  @override
  String get viewArtistPage => 'アーティストページを見る';

  @override
  String get addChildAccount => '子アカウント追加';

  @override
  String get aboutChildAccounts => '子アカウントについて';

  @override
  String get manageChildPresence => 'お子さまのクリエイティブな活動を管理';

  @override
  String get childAccountDescription =>
      '子アカウントでは、お子さまが保護者の管理のもとクリエイティブな活動を始められます。\n\n• プロフィールからいつでも自分のアカウントとお子さまのアカウントを切り替えられます\n• お子さまはアーティスト登録や投稿ができます\n• ユーザープロフィールはデフォルトで非公開です\n• アーティストページの公開/非公開は保護者が管理します';

  @override
  String get childAccountPrivateNote => '子アカウントのプロフィールはデフォルトで非公開であり、変更できません。';

  @override
  String get firstName => '名前';

  @override
  String get birthDate => '生年月日';

  @override
  String get passwordsMustMatch => 'パスワードが一致する必要があります';

  @override
  String get invalidPasswordMinimum => 'パスワードが無効です。8文字以上で入力してください。';

  @override
  String get yourCreativeJourney => 'あなたのクリエイティブ・ジャーニー';

  @override
  String wizardStepOf(int step) {
    return 'ステップ $step / 4';
  }

  @override
  String get learnMore => '詳しく見る';

  @override
  String get createArtistProfile => 'アーティストプロフィールを作成';

  @override
  String get artistUsername => 'アーティストユーザー名';

  @override
  String get chooseUniqueHandle => 'ユニークなハンドルを選択';

  @override
  String get yourProfessionalName => 'プロフェッショナルネーム';

  @override
  String get tagline => 'タグライン';

  @override
  String get oneLiners => '作品を一言で表現';

  @override
  String get location => '場所';

  @override
  String get whereYouCreate => '活動拠点';

  @override
  String get activeSinceYear => '活動開始年';

  @override
  String get yearYouStarted => '開始した年';

  @override
  String get genre => 'ジャンル';

  @override
  String get genres => 'ジャンル';

  @override
  String get dragToReorder => 'ドラッグで並べ替え';

  @override
  String get createOwnGenre => '独自のジャンルを作成...';

  @override
  String get selectTracksProfile => 'プロフィール用のトラックを選択';

  @override
  String get musicianTemplate => 'ミュージシャン';

  @override
  String get visualArtistTemplate => 'ビジュアルアーティスト';

  @override
  String get writerTemplate => 'ライター';

  @override
  String get filmmakerTemplate => '映像作家';

  @override
  String get youreAllSet => '準備完了！';

  @override
  String get artistProfileLive => 'アーティストプロフィールが公開されました。';

  @override
  String get viewYourTimeline => 'タイムラインを見る';

  @override
  String get startSharingPosts => '投稿を始める';

  @override
  String get skipForNow => 'スキップ';

  @override
  String get startSharingCreativeJourney => 'クリエイティブな旅を始めましょう';

  @override
  String get featureArtistPageTitle => 'アーティストページ';

  @override
  String get featureArtistPageDesc => '名前・アバター・カバー画像を持つ、あなた専用のクリエイター名刺。';

  @override
  String get featureTracksTitle => 'トラック';

  @override
  String get featureTracksDesc => '投稿をテーマごとに整理 — ミキサーのチャンネルのように。';

  @override
  String get featureBroadcastingTitle => 'ブロードキャスト';

  @override
  String get featureBroadcastingDesc =>
      'ファンがタイムラインをチューンインし、あなたの創作をリアルタイムで受け取ります。';

  @override
  String get whatAreTracks => 'トラックとは？';

  @override
  String get whatAreTracksDesc =>
      'トラックは、アーティストページ内のテーマ別チャンネルです。ファンは興味のあるトラックだけをフォローできます。\n\n例: ミュージシャンなら「演奏」「作曲」「日常」のように分けられます。';

  @override
  String get chooseTemplate => 'テンプレートを選択';

  @override
  String get yourTracks => 'あなたのトラック';

  @override
  String addTrackCount(int count) {
    return 'トラックを追加（$count/10）';
  }

  @override
  String get templateCustom => 'カスタム';

  @override
  String get newPost => '新規投稿';

  @override
  String get selectTrack => 'トラックを選択';

  @override
  String get contentType => 'コンテンツタイプ';

  @override
  String get mediaTypeThought => 'つぶやき';

  @override
  String get mediaTypeArticle => '記事';

  @override
  String get mediaTypeImage => '画像';

  @override
  String get mediaTypeVideo => '動画';

  @override
  String get mediaTypeAudio => '音声';

  @override
  String get mediaTypeLink => 'リンク';

  @override
  String get title => 'タイトル';

  @override
  String get body => '本文';

  @override
  String get visibility => '公開設定';

  @override
  String get draft => '下書き';

  @override
  String get connections => 'つながり';

  @override
  String get importance => '重要度';

  @override
  String get importanceLow => '低';

  @override
  String get importanceMedium => '中';

  @override
  String get importanceHigh => '高';

  @override
  String get post => '投稿';

  @override
  String get newTrack => '新規トラック';

  @override
  String get trackName => 'トラック名';

  @override
  String maxTracks(int max) {
    return '最大 $max トラック';
  }

  @override
  String get createTrackFirst => '先にトラックを作成してください';

  @override
  String maxCharacters(int max) {
    return '最大 $max 文字';
  }

  @override
  String get whatsOnYourMind => '何を考えていますか？';

  @override
  String get writeCaption => 'キャプションを書く...';

  @override
  String get addNote => 'メモを追加...';

  @override
  String get titleAutoFilled => 'タイトル（リンクから自動入力）';

  @override
  String get urlPlaceholder => 'https://';

  @override
  String get addLink => 'リンクを追加';

  @override
  String get addConstellation => 'コンステレーションを追加';

  @override
  String get eventDateOptional => 'イベント日時（任意）';

  @override
  String get uploadImageBeforePosting => '投稿前に画像をアップロードしてください';

  @override
  String get uploadFileBeforePosting => '投稿前にファイルをアップロードしてください';

  @override
  String get textRequired => 'テキストは必須です';

  @override
  String get imageRequired => '画像が1枚以上必要です';

  @override
  String get mediaFileRequired => 'このタイプにはメディアファイルが必要です';

  @override
  String get editPost => '投稿を編集';

  @override
  String get deletePostConfirm => '投稿を削除しますか？';

  @override
  String get tunedIn => 'チューンイン中';

  @override
  String get tuneIn => 'チューンイン';

  @override
  String get discoverMoreArtists => 'もっとアーティストを探す';

  @override
  String constellationPostCount(int count) {
    return 'コンステレーション · $count 投稿';
  }

  @override
  String get all => 'すべて';

  @override
  String get noPostsYet => 'まだ投稿がありません';

  @override
  String get yourTimeline => 'マイタイムライン';

  @override
  String get noPostsFromArtist => 'このアーティストの投稿はまだありません';

  @override
  String get discoverToFillTimeline => 'アーティストを見つけてチューンインしよう';

  @override
  String get tutorialFirstPostMessage => '最初の星をコンステレーションに加えよう';

  @override
  String get tutorialFirstPostSubtitle => '投稿のひとつひとつが、あなたの創作宇宙の光になります。';

  @override
  String get tapAnywhereToContinue => 'どこかをタップして続ける';

  @override
  String get artistBadge => 'アーティスト';

  @override
  String get tunedInBadge => 'チューンイン中';

  @override
  String constellationNamedPostCount(String name, int count) {
    return '$name · $count 投稿';
  }

  @override
  String get joinCreativeUniverse => 'クリエイティブな宇宙に参加しよう';

  @override
  String get searchArtists => 'アーティストを検索...';

  @override
  String get noArtistsFound => 'アーティストが見つかりません';

  @override
  String get failedToLoadArtists => 'アーティストの読み込みに失敗しました。再試行してください。';

  @override
  String get removeConstellationName => 'コンステレーション名を削除しますか？';

  @override
  String get failedRemoveConstellation => 'コンステレーションの削除に失敗しました。再試行してください。';

  @override
  String get failedDeletePost => '投稿の削除に失敗しました。再試行してください。';

  @override
  String get comments => 'コメント';

  @override
  String get comingSoon => '近日公開';

  @override
  String get linkPost => 'リンク投稿';

  @override
  String get viewPostExternal => '外部サイトで投稿を見る';

  @override
  String get reactions => 'リアクション';

  @override
  String get addReaction => 'リアクション追加';

  @override
  String get constellation => 'コンステレーション';

  @override
  String get nameConstellation => 'コンステレーション名を付ける';

  @override
  String get editPostTooltip => '投稿を編集';

  @override
  String get deletePostTooltip => '投稿を削除';

  @override
  String get about => '概要';

  @override
  String get aboutGleisner => 'Gleisner について';

  @override
  String get gleisnerLogoLabel => 'Gleisner ロゴ';

  @override
  String get aboutOperatorTitle => '運営者';

  @override
  String get aboutOperatorBody =>
      '本サービスは個人プロジェクトとして運営しています。\n連絡先: gleisner.app@gmail.com';

  @override
  String get aboutExternalTitle => '外部サービス（第三者へのデータ送信）';

  @override
  String get aboutExternalBody =>
      'Gleisner は以下の外部サービスを利用しています。通常の利用において、お客様のデータがこれらのサービスに送信される場合があります。\n\n1. Cloudflare（CDN、メディアストレージ）\n   - 目的: コンテンツ配信、画像・動画ホスティング\n   - データ: ページリクエスト、アップロードされたメディア\n\n2. Claude API（Anthropic）\n   - 目的: AI によるタイトル自動生成\n   - データ: 投稿コンテンツ（タイトル・本文）\n\n3. Railway\n   - 目的: アプリケーションホスティング、データベース\n   - データ: すべてのアプリケーションデータは Railway サーバーに保存されます';

  @override
  String get aboutDescription =>
      'Gleisner は、アーティストが多面的なクリエイティブ活動を DAW スタイルのマルチトラック・タイムラインで発信するためのプラットフォームです。\n\nGreg Egan の「ディアスポラ」に登場する Gleisner robots に由来 — 物理世界とデジタル世界を橋渡しする存在。';

  @override
  String get recentPosts => '最近の投稿';

  @override
  String get viewFullTimeline => 'タイムラインをすべて見る';

  @override
  String get untitled => '無題';

  @override
  String get editCover => 'カバーを編集';

  @override
  String get editAbout => '概要を編集';

  @override
  String get yearMustBe4Digits => '年は4桁で入力してください';

  @override
  String get editGenres => 'ジャンルを編集';

  @override
  String genresSelectedCount(int count) {
    return '$count/5 選択中';
  }

  @override
  String get current => '現在';

  @override
  String get available => '利用可能';

  @override
  String get manageTracks => 'トラック管理';

  @override
  String tracksCount(int count) {
    return '$count/10 トラック';
  }

  @override
  String get noTracksYet => 'トラックがありません。+をタップして追加してください。';

  @override
  String deleteTrackConfirm(String trackName) {
    return '$trackName を削除しますか？';
  }

  @override
  String get manageLinks => 'リンク管理';

  @override
  String get noLinksYet => 'リンクがありません。+をタップして追加してください。';

  @override
  String get linkCategoryMusic => '音楽';

  @override
  String get linkCategorySocial => 'SNS';

  @override
  String get linkCategoryVideo => '動画';

  @override
  String get linkCategoryWebsite => 'ウェブサイト';

  @override
  String get linkCategoryStore => 'ストア';

  @override
  String get linkCategoryOther => 'その他';

  @override
  String get platform => 'プラットフォーム';

  @override
  String get url => 'URL';

  @override
  String get invalidUrl => '無効なURL';

  @override
  String get milestoneCategoryAward => '受賞';

  @override
  String get milestoneCategoryRelease => 'リリース';

  @override
  String get milestoneCategoryEvent => 'イベント';

  @override
  String get milestoneCategoryAffiliation => '所属';

  @override
  String get milestoneCategoryEducation => '教育';

  @override
  String get milestoneCategoryOther => 'その他';

  @override
  String get deleteConfirmation => '削除しますか？';

  @override
  String get descriptionOptional => '説明（任意）';

  @override
  String get date => '日付';

  @override
  String get editMilestone => 'マイルストーンを編集';

  @override
  String milestonesCountOf(int count) {
    return '$count/200';
  }

  @override
  String get unassignedPosts => '未割り当て投稿';

  @override
  String get noUnassignedPosts => '未割り当ての投稿はありません';

  @override
  String get assignToTrack => 'トラックに割り当て';

  @override
  String get assign => '割り当て';

  @override
  String get failedAssignPost => '投稿の割り当てに失敗しました。再試行してください。';

  @override
  String get discover => 'ディスカバー';

  @override
  String get milestones => 'マイルストーン';

  @override
  String get links => 'リンク';

  @override
  String get artistHasntArrivedYet => 'このアーティストはまだ到着していません';

  @override
  String get starsStillAligning => '星たちはまだ整列中です。';

  @override
  String get goBack => '戻る';

  @override
  String get yourCreativeUniverse => '創作を、自分の手に。';

  @override
  String get ownCreativeIdentity => '作品も、名前も、あなたのもの';

  @override
  String get keepArtKeepControl => 'プラットフォームに依存しない、自分だけの発信拠点';

  @override
  String get mapYourJourney => '活動のすべてを、一つの場所に';

  @override
  String get multipleProjectsOnePlaceTitle => '音楽・映像・文章 — ジャンルを超えて記録できる';

  @override
  String get watchConnectionsEmerge => '作品どうしが、つながっていく';

  @override
  String get seeHowIdeasRelate => 'アイデアの関係性と進化を可視化する';

  @override
  String get tryItFirst => 'まず試してみる';

  @override
  String get noAccountNeeded => 'アカウント不要';

  @override
  String get formatting => '書式';

  @override
  String get hideFormatting => '書式を隠す';

  @override
  String get insertImage => '画像を挿入';

  @override
  String get heading => '見出し';

  @override
  String get bulletList => '箇条書き';

  @override
  String trackAlreadyExists(String name) {
    return 'トラック「$name」は既に存在します';
  }

  @override
  String get failedCreateTrack => 'トラックの作成に失敗しました';

  @override
  String get colorAutoAssigned => '色: 自動割り当て';

  @override
  String get replace => '置換';

  @override
  String get audioUploaded => '音声アップロード済み';

  @override
  String get linkToExistingPost => '既存の投稿にリンク';

  @override
  String get addAnotherConnection => '別の接続を追加';

  @override
  String get publishExternally => '外部に公開';

  @override
  String get publishExternallyDescription => '公開記事サイトで利用可能にする';

  @override
  String get linking => 'リンク中...';

  @override
  String get failedUpdatePost => '投稿の更新に失敗しました。再試行してください。';

  @override
  String get removeConstellationDescription =>
      '投稿は残りますが、コンステレーションのグループ化が解除されます。';

  @override
  String get view => '表示';

  @override
  String get quietNote => 'ささやかなメモ';

  @override
  String get heroMoment => 'ハイライト';
}
