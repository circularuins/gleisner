# ADR 020: Security Architecture and Threat Mitigation

## Status

Draft

## Context

Gleisner のバックエンドは Ed25519 鍵ペア + JWT (EdDSA) + scrypt による認証基盤の上に、GraphQL API (yoga + pothos) を構築している（ADR 014, 015, 016, 017）。MVP リリースに向け、コードベースのセキュリティレビューと業界ベストプラクティス調査を実施した結果、以下の脅威領域が特定された。

### 脅威モデル概要

| 脅威カテゴリ | 攻撃面 | 影響度 |
|-------------|--------|--------|
| 認証情報の漏洩 | JWT 秘密鍵のログ出力、秘密鍵のサーバー側平文処理 | Critical — 全ユーザーの ID が危殆化 |
| 認証バイパス | authMiddleware のサイレント失敗 | Critical — 未認証ユーザーが認証済みリソースにアクセス |
| DoS / リソース枯渇 | パスワード長無制限 + scrypt、GraphQL depth/complexity 無制限 | High — サーバー可用性の喪失 |
| 鍵管理 | サーバー側鍵生成、AES-GCM 暗号化のみの保護 | High — 自己主権の前提を損なう |
| API 乱用 | Rate limiting 未実装、GraphQL introspection 公開 | Medium — データスクレイピング、列挙攻撃 |

### レビュープロセスと信頼度評価

2つの独立した調査（コードベースレビュー + 業界調査）の結果を統合した。各指摘には信頼度スコア（0-100）を付与し、80未満の指摘は「検討事項」として分類した（誤検知リスクが高いため決定事項から除外）。

**信頼度 80 以上の指摘（決定事項に反映）: 5件**

| # | 指摘 | 信頼度 | カテゴリ |
|---|------|--------|----------|
| 1 | JWT 秘密鍵がログに平文出力 | 95 | 認証情報漏洩 |
| 2 | パスワード上限長バリデーションなし (scrypt DoS) | 90 | DoS |
| 3 | authMiddleware が認証失敗をサイレントに無視 | 92 | 認証バイパス |
| 4 | サーバー側で秘密鍵を生成・平文で扱う設計 | 88 | 鍵管理 |
| 5 | GraphQL に depth/complexity/rate limit なし | 85 | API 乱用 |

**信頼度 80 未満の指摘（検討事項として記録）: 2件**

| # | 指摘 | 信頼度 | 理由 |
|---|------|--------|------|
| 6 | UserType が publicKey を返却 | 78 | publicKey は公開情報として設計されている（ADR 016 で UserType に含める意図的決定）。ただし、publicKey の公開が将来の鍵ローテーション設計に影響する可能性はある |
| 7 | scrypt パラメータ N=16384 が低い | 75 | N=16384 (2^14) は OWASP 推奨の最低ラインを満たしている。N=32768 以上が望ましいとする見解もあるが、MVP のサーバースペックとのバランスが必要 |

### 業界動向（知識カットオフに依存する情報 — 信頼度 70 以下）

以下の統計・外部仕様の主張はモデルの知識に基づくものであり、客観的に検証されていない。参考情報として記録するが、実装判断前に公式ソースでの確認を推奨する。

| 主張 | 信頼度 | 検証方法 |
|------|--------|----------|
| AT Protocol の did:plc は rotationKeys + 72時間リカバリーウィンドウ | 70 | AT Protocol 公式ドキュメントで確認 |
| 2024年のアカウント乗っ取り: ユーザーの29%が被害経験 | 60 | 元調査レポートの特定・検証が必要 |
| AI駆動フィッシングが2025年初頭までに80%超 | 55 | 元調査レポートの特定・検証が必要 |
| Passkeys: 2025年で69%のユーザーが保有 | 60 | FIDO Alliance 等の公式統計で確認 |
| COPPA 2025年6月改正の詳細 | 65 | FTC 公式サイトで最新状況を確認（ADR 019 で別途追跡中） |
| GDPR 罰金: 2024年に$2.7B超 | 60 | GDPR Enforcement Tracker 等で確認 |

## Decision

### 1. 即時対応（MVP リリース前に修正必須）

これらは**データ漏洩・認証バイパスに直結する脆弱性**であり、リリース前の修正が必須。

#### 1.1 JWT 秘密鍵のログ出力を除去（信頼度95）

**問題**: JWT 署名に使用する秘密鍵が起動時やエラー時にログへ平文出力されている。ログ集約サービスへの転送、ログファイルのバックアップ等で秘密鍵が意図しない場所に永続化し、トークン偽造の攻撃面となる。

**対策**:
- 秘密鍵を含む変数のログ出力を全て除去
- 環境変数のダンプ処理がある場合、秘密鍵フィールドをマスク（`***`）
- ログ出力の静的解析ルール追加を検討（ESLint カスタムルール等）

**根拠**: 秘密鍵の漏洩は全ユーザーのセッション偽造を可能にし、影響範囲が最大。修正コストは最小（ログ行の削除）。

#### 1.2 authMiddleware のサイレント失敗を修正（信頼度92）

**問題**: 認証ミドルウェアが JWT 検証失敗時にエラーを投げず、`ctx.authUser = undefined` のまま次のミドルウェア/リゾルバに処理を渡している。リゾルバ側で `authUser` の null チェックが漏れた場合、未認証アクセスが成立する。

**対策**:
- 認証が必要なエンドポイントでは、ミドルウェアレベルで認証失敗時に明示的に `401 Unauthorized` 相当の GraphQLError を投げる
- 公開エンドポイント（認証オプショナル）は明示的にオプトインする設計に変更
- Pothos の `authScopes` プラグインまたは同等の宣言的認可メカニズムの導入を検討

**根拠**: 「デフォルト拒否」は認証設計の基本原則。現在の「デフォルト許可」設計は、新しいリゾルバ追加時にチェック漏れが発生しやすい。

#### 1.3 パスワード長の上限バリデーション追加（信頼度90）

**問題**: パスワードにバイト長の上限がないため、数MB のパスワードを送信して scrypt の計算を強制し、サーバーリソースを枯渇させる DoS 攻撃が可能。

**対策**:
- パスワードの最大長を **128文字**に制限（OWASP 推奨の72バイト制限より余裕を持たせるが、DoS を防止）
- バリデーションは scrypt 計算の**前**に実施
- フロントエンドでも同じ上限を適用（UX のため）

**根拠**: scrypt は意図的に計算コストが高いため、入力長の制限なしでは amplification attack が成立する。修正コストは最小。

### 2. 短期対応（ユーザー公開前に実装）

ユーザーデータの保護と基本的な API 防御。**公開前**に実装すべきだが、クローズドテスト中は許容可能。

#### 2.1 GraphQL の防御層追加（信頼度85）

**問題**: Query depth、complexity、rate limit が未設定。攻撃者が深いネストクエリやバッチクエリでサーバーを過負荷にできる。

**対策**:
- **Query depth limit**: 最大10階層（yoga の `depthLimit` プラグイン）
- **Query complexity limit**: フィールドごとにコストを定義し、クエリ合計コストに上限を設定
- **Rate limiting**: IP ベース + 認証ユーザーベースの二段階制限
  - 匿名: 60 req/min
  - 認証済み: 300 req/min
  - mutation 個別: signup/login は 10 req/min/IP
- **本番環境での introspection 無効化**

**根拠**: GraphQL は REST と異なり、単一エンドポイントで任意の深さ・幅のクエリを許容するため、防御層なしでは DoS 耐性がない。yoga エコシステムにプラグインが揃っており、実装コストは低い。

#### 2.2 サーバー側鍵管理の強化（信頼度88）

**問題**: Ed25519 秘密鍵をサーバー側で生成し、AES-GCM で暗号化して DB に保存している。暗号化キーの管理、メモリ上での平文処理など、攻撃面が広い。ADR 014 の自己主権思想との整合性も課題。

**対策（段階的）**:
1. **短期（ユーザー公開前）**: 秘密鍵の暗号化キーを環境変数から Cloud KMS（AWS KMS / GCP Cloud KMS / Cloudflare Workers KMS）に移行。メモリ上での秘密鍵の平文保持時間を最小化（使用直後のゼロクリア）
2. **中期**: クライアント側鍵生成への移行（WebCrypto API）。サーバーは公開鍵のみ保持
3. **長期**: Passkeys / WebAuthn 統合（ADR 014 Phase 2 と連動）

**根拠**: 現在のサーバー側鍵生成は MVP の開発速度を優先した設計（ADR 014 で「server-side for MVP」と明記）。公開前にはリスク緩和策を入れ、中長期でクライアント側鍵生成に移行する。

#### 2.3 Key derivation strengthening: scrypt → Argon2id

**Problem**: scrypt with `N=16384` (2^14) is used for both password hashing and encryption key derivation. OWASP 2024 recommends scrypt `N=65536` (2^16) minimum. Argon2id is now the recommended algorithm for new implementations (RFC 9106).

**Decision**:
- New accounts: use Argon2id with OWASP-recommended parameters
- Existing accounts: migrate on next login (re-hash when user provides correct password)
- Store algorithm version in a new `hashAlgorithm` column to support gradual migration

**Rationale**: The encrypted private key is the crown jewel. If the DB leaks, weak KDF + weak password = private key recovery in hours on modern GPUs.

#### 2.4 Two-factor authentication (TOTP + backup codes)

**Decision**:
- Implement TOTP (RFC 6238) as optional 2FA
- Generate 10 single-use backup codes at enrollment, stored as Argon2id hashes
- Show backup codes once at setup; prompt user to save offline
- Recovery flow: backup code → disable 2FA → re-enroll (no bypass of 2FA via email-only recovery)

**Rationale**: Account takeover in Gleisner is more damaging than in a typical SNS because the attacker gains cryptographic signing capability. TOTP is the minimum viable protection.

#### 2.5 GDPR minimum compliance

**Decision**:
- Implement account deletion endpoint (right to erasure) — cascade delete all user data
- Publish privacy policy documenting data collected, processing purposes, retention
- Add data export endpoint (right to portability) — JSON download of all user data

**Rationale**: GDPR applies to any service accessible from the EU. Non-compliance fines start at €10M. These are also good engineering practices regardless of legal obligation.

### 3. 中期対応（成長フェーズで実装）

ユーザー基盤の拡大に伴い必要になるセキュリティ強化。

#### 3.1 Passkeys / WebAuthn 対応

**対策**:
- WebAuthn を追加認証方式として実装（既存の email/password を置き換えるのではなく、追加オプション）
- 段階的ロールアウト: 設定画面で opt-in → デフォルト推奨 → 新規登録のデフォルト

**根拠**: 業界全体でパスワードレス認証への移行が進行中。Apple/Google/Microsoft がデフォルト化しており、ユーザーの利便性とセキュリティを同時に向上させる。ただし MVP では email/password で十分であり、ユーザー基盤拡大後の投資対効果が高い。

#### 3.2 Persisted Queries（GraphQL）

**対策**:
- クライアントが送信するクエリを事前登録制にし、任意のクエリ実行を防止
- 開発環境では全クエリ許可、本番環境では登録済みクエリのみ許可

**根拠**: depth/complexity limit だけでは防ぎきれない巧妙なクエリ攻撃を根本的に排除する。Flutter クライアントが固定されているため、persisted queries の導入は比較的容易。

#### 3.3 Recovery phrase (BIP39 mnemonic)

**Decision**: At signup, generate a 12-word BIP39 mnemonic that deterministically derives the Ed25519 key pair. Display once, prompt user to write down offline.

**Purpose**:
- If the server is compromised or goes offline, the user can recreate their key pair from the mnemonic alone
- Aligns with Diaspora principle: the user truly *owns* their identity, independent of any server
- Compatible with future client-side key generation (4.1)
- Migration: existing users can "claim" a mnemonic by verifying their password

#### 3.4 セキュリティ監査ログ

**対策**:
- 認証イベント（login/signup/logout/failure）、権限変更、管理操作のログを構造化形式で記録
- 異常パターン検出（同一IPからの大量ログイン失敗、アカウント列挙等）のアラート

**根拠**: インシデント対応と法的コンプライアンス（GDPR、COPPA — ADR 019 参照）の基盤。ユーザー数増加に伴いインシデント発生確率が上昇するため、成長フェーズでの導入が適切。

### 4. 長期対応（分散化フェーズで実装）

ADR 014 の分散化ロードマップと連動するセキュリティ強化。

#### 4.1 クライアント側鍵生成 + DID 自己主権化

**対策**:
- WebCrypto API でブラウザ/デバイス上で Ed25519 鍵ペアを生成
- サーバーは公開鍵のみ受け取り、秘密鍵には一切触れない
- BIP-39 リカバリーフレーズによる鍵バックアップ（ADR 014 Phase 2）
- AT Protocol の rotationKeys パターンの採用を検討（鍵の侵害時にリカバリーウィンドウ内で鍵をローテーション可能）

**根拠**: 自己主権アイデンティティの完全な実現には、サーバーが秘密鍵を一切保持しない設計が必要。ただし、WebCrypto の Ed25519 サポートのブラウザ互換性、リカバリーフレーズの UX 設計など、解決すべき課題が多く、分散化フェーズでの段階的移行が現実的。

#### 4.2 ゼロ知識証明ベースの年齢確認

**対策**:
- ADR 019 の年齢確認フローに ZK proof を統合し、生年月日を開示せずに年齢層を証明
- Guardian-Managed Account の DID 関係性を ZK proof で検証可能にする

**根拠**: プライバシー保護の究極形態だが、技術的成熟度と実装コストを考慮し、長期目標として位置づける。

### Child safety security requirements

Per Idea 012 (age policy) and ADR 019, if Gleisner allows users under 13:
- COPPA (revised June 2025) requires verifiable parental consent
- Child accounts need additional protection layers:
  - Default-private posts (Idea 014)
  - Guardian-managed account recovery (not self-service)
  - Restricted data collection (minimize PII)
  - No direct messaging without guardian approval
- The 2FA and recovery mechanisms above must accommodate guardian-delegated authentication from the start

### 検討事項（信頼度80未満 — 追加調査の上で判断）

#### C.1 UserType の publicKey 返却（信頼度78）

`publicKey` は ADR 016 で `UserType`（認証済みユーザー本人のみ閲覧可能）に含める意図的な設計判断がなされている。`PublicUserType` には含まれていないため、他者から見えることはない。

**追加検討ポイント**:
- 将来の鍵ローテーション実装時に、旧公開鍵の公開が問題にならないか
- クライアント側鍵生成に移行した際、publicKey の取り扱いを再評価

#### C.2 scrypt パラメータ N=16384（信頼度75）

N=16384 (2^14) は OWASP の最低推奨値を満たしているが、2026年時点のハードウェア性能を考慮すると N=32768 (2^15) 以上が望ましいとする意見もある。

**追加検討ポイント**:
- サーバーのメモリ・CPU 負荷への影響を計測（N を2倍にするとリソース消費も2倍）
- 並行して Argon2id への移行を評価（メモリハード関数としてより現代的）
- パスワード長上限（1.3で実施）により、N が低めでも DoS リスクは緩和される

## Consequences

### ポジティブ

- MVP リリース前に Critical な脆弱性（秘密鍵漏洩、認証バイパス、DoS）が解消される
- 段階的な実装により、セキュリティ投資と開発速度のバランスを維持できる
- ADR 014（分散化）、ADR 018（著作権）、ADR 019（年齢制限）との一貫した設計が実現される
- 鍵管理の段階的移行パスが明確になり、自己主権アイデンティティへの移行が計画的に進められる

### ネガティブ

- 即時対応項目は MVP スケジュールに影響する（ただし修正コストは小さい）
- GraphQL 防御層の追加により、開発中のクエリデバッグがやや煩雑になる（開発環境では緩和設定を適用）
- Cloud KMS 導入はインフラコストの増加を伴う（Railway 環境での選択肢を調査する必要あり）

### リスク受容

以下のリスクは現時点で受容し、該当フェーズで対処する:
- MVP 期間中はサーバー側鍵生成を継続（Cloud KMS で緩和）
- Passkeys 未対応（email/password + JWT で MVP は十分）
- Persisted queries 未導入（depth/complexity limit で初期は対応）

## Open Questions

| # | Topic | Notes |
|---|-------|-------|
| OQ-S01 | Cloud KMS の Railway 環境での実現方法 | Railway Secrets vs 外部 KMS サービスの比較が必要 |
| OQ-S02 | WebCrypto Ed25519 のブラウザサポート状況 | Flutter Web (CanvasKit) 環境での動作確認が必要 |
| OQ-S03 | scrypt → Argon2id 移行の影響 | 既存パスワードのマイグレーション戦略（次回ログイン時に再ハッシュ等） |
| OQ-S04 | Rate limiting の状態管理 | Redis 導入 vs メモリ内管理 vs Cloudflare WAF の比較 |
| OQ-S05 | AT Protocol rotationKeys パターンの Gleisner への適用可否 | did:plc の仕様詳細の検証が必要（業界調査の信頼度70） |

## Related

- ADR 014 — Decentralization Roadmap（DID、鍵管理、フェーズ定義）
- ADR 015 — Technology Stack（Ed25519、JWT、scrypt の選定根拠）
- ADR 016 — User Identity Privacy（UserType / PublicUserType 分離、publicKey の扱い）
- ADR 017 — Content Hash and Signature（contentHash、Ed25519 署名）
- ADR 018 — Copyright Protection（DID ベースの侵害追跡）
- ADR 019 — Age Policy（COPPA/GDPR コンプライアンス、データ最小化）

---

## レビュー集約レポート

### 総合評価

- **マージ可否**: 即時対応（1.1, 1.2, 1.3）の修正完了を条件にマージ可
- **必須修正事項**: JWT 秘密鍵のログ除去、authMiddleware のデフォルト拒否化、パスワード長上限の追加
- **品質評価**: 認証基盤の設計（Ed25519 + JWT + DID互換）は堅実。ただし実装レベルでのセキュリティハードニングが不足しており、MVP 公開前の対応が必須

### Critical（高重要度）

1. **JWT 秘密鍵のログ平文出力**（信頼度95）— 全ユーザーのセッション偽造が可能になるため即時修正。ログ行の削除のみで対応可能
2. **authMiddleware のサイレント失敗**（信頼度92）— 「デフォルト許可」設計は認証バイパスの温床。デフォルト拒否に反転
3. **パスワード長無制限による scrypt DoS**（信頼度90）— 128文字上限の追加。scrypt 計算前にバリデーション

### Important（中重要度）

1. **サーバー側秘密鍵の平文処理**（信頼度88）— Cloud KMS への暗号化キー移行 + メモリ上の平文保持時間最小化
2. **GraphQL 防御層の欠如**（信頼度85）— depth limit, complexity limit, rate limiting の追加

### Nice to have（低重要度）

1. **scrypt パラメータの強化**（信頼度75、検討事項）— N=32768 以上への引き上げまたは Argon2id 移行を評価
2. **UserType の publicKey 返却の再評価**（信頼度78、検討事項）— 鍵ローテーション設計時に再検討

---

信頼度不足により決定事項から検討事項へ分類: 2件
外部情報の検証不足により参考情報として記録: 6件
