# Phase 0 Roadmap — Family Lifelog Launch

Phase 0 リリースまでのタスク一覧。随時更新し、進捗を追跡する。

## スコープ

- **利用形態**: 家族数名のライフログ + 閲覧のみ一般公開
- **ユーザー登録**: 家族のみ（招待式）
- **法的位置づけ**: 個人サイト/ポートフォリオ
- **参照**: Idea 022 (Pre-launch Checklist), ADR 015 (Tech Stack)

---

## 1. 機能実装（必須）

### 1.1 デスクトップ対応（Idea 030） — Phase 0 required
- [ ] タイムライン横スクロール化（デスクトップ/タブレット）
- [ ] サイドバーナビゲーション（ボトムバー → サイドレール）
- [ ] 詳細シート → サイドパネル化
- [ ] 投稿フォームのダイアログ/分割ペイン
- [ ] ブレークポイント戦略（mobile < 600px, tablet 600-1024px, desktop > 1024px）
- [ ] Discover/Profile のマルチカラムレイアウト
- 参照: `docs/ideas/030-responsive-layout-desktop-tablet.md`

### 1.2 メディア制限の強制（ADR 025）
- [x] 動画 1 分制限（Issue #144）— PR #195
- [x] 音声 5 分制限（Issue #145）— PR #195

### 1.3 セキュリティ即時対応（ADR 020 Immediate）
- [x] JWT secret key logging 削除
- [x] authMiddleware サイレント失敗修正
- [x] パスワード長上限 128 文字

### 1.4 マルチ画像カルーセル（Issue #139）
- [ ] DB スキーマ: post_media テーブル（1:N）追加、既存 mediaUrl からの移行
- [ ] 投稿フォーム: 複数画像選択・並べ替え UI
- [ ] タイムラインノード: カルーセル/グリッド表示
- [ ] 詳細シート: スワイプカルーセル + フルスクリーンビューア対応
- [ ] contentHash 計算の複数メディア対応

### 1.5 サイト表記（Idea 022 Required）
- [ ] フッターに運営者名・連絡先を記載
- [ ] 外部送信の簡易開示（Cloudflare, Claude API の使用明記）

---

## 2. 機能実装（推奨）

### 2.1 パフォーマンス
- [ ] N+1 author クエリ解消（Issue #180）

### 2.2 OGP 改善
- [ ] OGP 自動リフレッシュ（Issue #191 — 投稿後の遅延再取得）

### 2.3 EXIF メタデータ除去（Idea 022 Recommended）
- [ ] 写真アップロード時に GPS 座標等を自動除去（子どものプライバシー保護）

### 2.4 HEIC サポート改善
- [ ] HEIC 画像のブラウザ互換性改善（Issue #146）

---

## 3. リファクタリング・技術的負債

### 3.1 コード品質（次 PR のついでに対応可）
- [ ] _buildMediaPreview の create/edit 共通化（Issue #178）
- [ ] OGP update ヘルパー抽出（Issue #189）
- [ ] JPEG quality 定数化（Issue #179）
- [ ] _buildLinkFields の create/edit 共通化

### 3.2 テスト
- [ ] SSRF ガード / OGP フェッチャーのユニットテスト（Issue #188）
- [ ] TOCTOU レース条件の修正（Issue #116, #118）

---

## 4. インフラ・デプロイ（非コード）

### 4.1 必須
- [ ] HTTPS 有効確認（Cloudflare Pages + Railway）
- [ ] 本番環境の DB マイグレーション実行
- [ ] 本番 seed データ（家族アカウント + 初期トラック）
- [ ] ドメイン設定（gleisner.app → Cloudflare Pages）
- [ ] R2 CORS 本番設定

### 4.2 推奨
- [ ] ドメイン gleisner.app の取得確認
- [ ] Railway DB バックアップ設定確認
- [ ] ソーシャルアカウント確保（GitHub org, X 等）
- [ ] DB バックアップ復旧テスト

---

## 5. Phase 0 スコープ外（Phase 1+ に明示的に延期）

以下は Phase 0 では実施しない:

- ❌ Federation / Decentralization（ADR 014）
- ❌ 電気通信事業届出（Idea 022）
- ❌ 正式な利用規約・プライバシーポリシー
- ❌ COPPA / 児童保護ポリシー（ADR 019）
- ❌ YouTube/SoundCloud 埋め込みプレイヤー（Idea 024 Phase 3）
- ~~マルチ画像カルーセル（Issue #139）~~ → 1.4 に移動
- ❌ i18n / 日本語ローカライゼーション（Issue #151）
- ❌ サーバーサイド動画トランスコーディング（Issue #138）
- ❌ ストレージクォータ（Issue #137）
- ❌ 2FA / Passkeys（ADR 020）
- ❌ GraphQL rate limiting 本格版
- ❌ IaC（Issue #152）
- ❌ AI モデル移行（Issue #153）
- ❌ コンテンツモデレーション体制
- ❌ Guide ページ（Issue #150）

---

## 優先順序

| 順序 | カテゴリ | タスク | 規模 | 根拠 |
|------|----------|--------|------|------|
| **1** | セキュリティ | 1.3 ADR 020 即時対応 | 小 | 公開前に必須 |
| **2** | 機能 | 1.2 メディア制限（動画1分/音声5分） | 小 | ADR 025 要件 |
| **3** | 機能 | 1.1 デスクトップ対応 | **大** | Phase 0 required (Idea 030) |
| **4** | 機能 | 1.4 マルチ画像カルーセル | **大** | DB 変更は運用前に。家族ライフログの自然なユースケース |
| **5** | サイト表記 | 1.5 フッター・外部送信開示 | 小 | 法的最低要件 |
| **6** | 推奨 | 2.3 EXIF 除去 | 中 | 子どものプライバシー |
| **7** | 推奨 | 2.1 N+1 解消 | 中 | パフォーマンス |
| **8** | インフラ | 4.1 デプロイ準備 | 中 | リリース直前 |
| **9** | テスト | 3.2 セキュリティテスト | 中 | 品質保証 |

---

## 完了済み

- [x] 全メディアタイプの磨き込み（text, image, video, audio, link）— PR #173, #184, #190, #192
- [x] OGP フェッチ基盤 — PR #186
- [x] OGP リッチ表示 — PR #190
- [x] リンク型 UI ポリッシュ — PR #192
- [x] create post state reset バグ修正 — PR #182
- [x] AWS SDK バージョン同期 — PR #183
- [x] Idea 030 記録（デスクトップ対応）— PR #185
- [x] Codex MCP 方針修正
- [x] dependabot PR 全マージ

---

*最終更新: 2026-04-11*
