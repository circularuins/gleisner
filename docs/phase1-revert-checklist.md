# Phase 1 Revert Checklist

Phase 0 で一時的に導入した制限を、Phase 1（クローズドベータ）移行時に解除するためのチェックリスト。

Phase 0 の位置づけと対策の背景は以下を参照:
- `docs/ideas/022-pre-launch-checklist.md`（Phase 戦略全体）
- `docs/phase0-public-exposure-audit.md`（未ログイン露出の監査）

## 一括検出コマンド

全ての PHASE_0_REVERT マーカーを検出:

```bash
grep -rn "PHASE_0_REVERT" gleisner/ --include="*.ts" --include="*.dart" --include="*.html" --include="*.txt"
```

Cloudflare ダッシュボードや環境変数の変更は grep では検出できないため、本チェックリストで補完する。

## 1. クロール拒否の解除

### 1.1 robots.txt の更新

- [ ] `gleisner/frontend/web/robots.txt` の `Disallow: /` を削除または調整
- [ ] LLM クローラーについては Phase 1 方針を再決定（継続拒否 / 一部許可 / 全許可）
- [ ] **6 ヶ月ごとに LLM クローラー UA リストを見直す**（2026-04 時点で最新。UA 名・robots.txt 尊重状況は変動が速い）

### 1.2 SPA meta タグの削除

- [ ] `gleisner/frontend/web/index.html` の以下 2 行を削除:
  ```html
  <meta name="robots" content="noindex,nofollow,noarchive,nosnippet">
  <meta name="googlebot" content="noindex,nofollow">
  ```

### 1.3 OGP レスポンスの noindex 削除

- [ ] `gleisner/backend/src/routes/ogp.ts` の以下を削除:
  - 生成 HTML 内の `<meta name="robots" content="noindex,...">`
  - `c.header("X-Robots-Tag", "noindex, nofollow, noarchive");`
- [ ] 対応するテスト `backend/src/routes/__tests__/ogp.test.ts` の `"includes Phase 0 noindex meta and X-Robots-Tag header"` ケースを削除または調整

### 1.4 CDN キャッシュパージ

- [ ] Cloudflare Pages / OGP エンドポイントのキャッシュをパージ
  - 理由: OGP レスポンスは `Cache-Control: public, max-age=300` でキャッシュ済み
  - 方法: Cloudflare Dashboard → Caching → Purge Everything（または URL 指定）

## 2. Cloudflare Bot 対策の緩和

Phase 1 で招待制ベータを開始する際、クローラー拒否の強度を緩和:

- [ ] Bot Fight Mode の設定を見直し（特に Turnstile を導入した場合は要整合性確認）
- [ ] WAF Rate Limiting ルールを一般公開時に合わせてチューニング
- [ ] Phase 1 時点で Preflight メモリを更新（`project_phase0_preflight.md`）

## 3. コメント機能の復帰（PR #219）

別 Issue: **#221** で追跡中。

- [ ] `backend/src/graphql/types/index.ts` の `import "./comment.js";` アンコメント
- [ ] `backend/src/graphql/__tests__/comment.test.ts` 冒頭の個別 `import "../types/comment.js"` を削除
- [ ] `backend/src/graphql/__tests__/public-user.test.ts` の `"comments query user does not expose email"` の `it.skip` → `it` に戻す
- [ ] コメント関連のフロント UI を表示に戻す
- [ ] 電気通信事業法（ADR 022）観点で弁護士相談が完了していることを確認

## 4. その他の Phase 1 対応（参考）

本チェックリスト外だが、Phase 1 移行時に同時検討すべき項目:

- [ ] セキュリティ Immediate タスク（ADR 020）: CORS 本番設定、CSP/X-Frame-Options、アカウント列挙防止
- [ ] 利用規約・プライバシーポリシー・AI 利用ポリシーのドラフト作成（Idea 022 Phase 1 Required）
- [ ] 弁護士初回相談完了
- [ ] 商標登録出願の開始
- [ ] メール送信基盤（SPF/DKIM/DMARC）

詳細は `docs/ideas/022-pre-launch-checklist.md` の Phase 1 セクション参照。

## 5. 検証手順

Phase 1 移行 PR マージ後:

- [ ] `curl https://gleisner.app/robots.txt` が Phase 1 設定を返すか
- [ ] `curl -I https://gleisner.app/` に noindex ヘッダーがないか
- [ ] `curl -I https://gleisner.app/ogp/@seeduser` に X-Robots-Tag がないか
- [ ] Google Search Console で "site:gleisner.app" が徐々にインデックスされ始めるか（数日〜週単位）
- [ ] Twitter Card Validator / Facebook Debugger で OGP プレビューが正常表示
- [ ] Cloudflare Analytics でクローラートラフィックが急増しても従量課金アラートが出ないこと

### Phase 0 時点の逆向き検証

Phase 0 リリース直後・リリース後定期的に実行:

```bash
./scripts/verify-phase0-deploy.sh                    # default: https://gleisner.app
./scripts/verify-phase0-deploy.sh https://staging.gleisner.app  # ステージング向け
SEED_USER=myartist ./scripts/verify-phase0-deploy.sh            # 確認対象のアーティストを指定
```

- 全パス = Phase 0 状態が正しく反映されている
- 失敗 = robots.txt / noindex meta / X-Robots-Tag / OGP プロキシのいずれかが本番で壊れている

Phase 1 移行時はスクリプト自体を削除するか、検証項目を反転させる。
