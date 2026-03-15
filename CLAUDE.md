# CLAUDE.md — Gleisner

このファイルは Gleisner 固有の Claude Code 設定です。
yatima ルートの CLAUDE.md（設計思想・共通ワークフロー）を継承した上で、本ファイルの技術スタック固有ルールが追加適用されます。

## プロジェクト概要

Gleisner は、アーティストの多面的な活動を **DAW 型マルチトラック・タイムライン**で発信する分散型プラットフォーム。

- 物理世界のクリエイティブ活動とデジタルプレゼンスを橋渡しする
- ユーザー（アーティスト）がデータとアイデンティティを自ら所有する
- 理不尽な BAN やプラットフォーム依存からの解放

### 命名の由来

Greg Egan "Diaspora" の **Gleisner robots**（物理世界とデジタル世界の橋渡し役）に由来。
詳細: `docs/decisions/002-naming-gleisner.md`

## 技術スタック

> **Status: 未定** — 決まり次第このセクションを更新する。

| レイヤー | 技術 | 備考 |
|----------|------|------|
| Backend  | TBD  | API サーバー |
| Frontend | TBD  | クライアントアプリ |
| Database | TBD  | |
| Protocol | TBD  | 分散型プロトコル |

## アーキテクチャ

- **API ファースト設計**: バックエンドとフロントエンドは完全分離。API を介してのみ通信する。
- **モノレポ構成**: `backend/` と `frontend/` が同居。

## 意思決定ドキュメント

`docs/decisions/` に ADR（Architecture Decision Records）を蓄積する。

### ADR 運用ルール

- 新規 ADR は連番で追加: `NNN-slug.md`
- 既存 ADR の変更は「Superseded by」で新 ADR を参照
- フォーマット: タイトル / ステータス / コンテキスト / 決定 / 結果

## 開発コマンド

> 技術スタック決定後に追記する。

```bash
# TBD
```
