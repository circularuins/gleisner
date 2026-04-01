# Analytics Queries

`analytics_events` テーブルからユーザー行動データを取得するための SQL クエリ集。

## 接続方法

```bash
# ローカル開発
pnpm db:studio            # Drizzle Studio (GUI)
docker exec -it gleisner-db psql -U gleisner -d gleisner  # CLI

# Railway 本番
railway run pnpm db:studio
railway connect            # psql 接続
```

---

## Page Views

### 昨日の PV（ページ別）

```sql
SELECT metadata->>'page' AS page, count(*) AS views
FROM analytics_events
WHERE event_type = 'page_view'
  AND created_at >= CURRENT_DATE - INTERVAL '1 day'
  AND created_at < CURRENT_DATE
GROUP BY page
ORDER BY views DESC;
```

### 過去7日間の日別 PV 推移

```sql
SELECT created_at::date AS date, count(*) AS views
FROM analytics_events
WHERE event_type = 'page_view'
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date;
```

### 過去7日間のページ別 PV ランキング

```sql
SELECT metadata->>'page' AS page, count(*) AS views
FROM analytics_events
WHERE event_type = 'page_view'
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY page
ORDER BY views DESC;
```

---

## Sessions

### 今日のユニークセッション数

```sql
SELECT count(DISTINCT session_id) AS unique_sessions
FROM analytics_events
WHERE created_at >= CURRENT_DATE;
```

### 過去7日間の日別ユニークセッション数

```sql
SELECT created_at::date AS date, count(DISTINCT session_id) AS sessions
FROM analytics_events
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date;
```

---

## Users

### アクティブユーザー（過去7日間にイベントを送信した認証済みユーザー）

```sql
SELECT u.username, count(*) AS events,
       count(DISTINCT ae.session_id) AS sessions,
       max(ae.created_at) AS last_seen
FROM analytics_events ae
JOIN users u ON ae.user_id = u.id
WHERE ae.created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY u.id, u.username
ORDER BY last_seen DESC;
```

### 未認証 vs 認証済みイベント割合

```sql
SELECT
  count(*) FILTER (WHERE user_id IS NULL) AS anonymous,
  count(*) FILTER (WHERE user_id IS NOT NULL) AS authenticated,
  count(*) AS total
FROM analytics_events
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days';
```

---

## Engagement

### イベントタイプ別カウント（過去7日間）

```sql
SELECT event_type, count(*) AS count
FROM analytics_events
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY event_type
ORDER BY count DESC;
```

### 投稿閲覧ランキング（post_view の postId 別）

```sql
SELECT metadata->>'postId' AS post_id, count(*) AS views
FROM analytics_events
WHERE event_type = 'post_view'
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY post_id
ORDER BY views DESC
LIMIT 20;
```

### Signup ファネル（過去30日間）

```sql
SELECT event_type, count(*) AS count
FROM analytics_events
WHERE event_type IN ('signup_start', 'signup_complete')
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY event_type;
```

---

## Public Timeline

### 公開タイムラインの閲覧数（アーティスト別）

```sql
SELECT metadata->>'page' AS artist_page, count(*) AS views
FROM analytics_events
WHERE event_type = 'page_view'
  AND metadata->>'page' LIKE '/@%'
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY artist_page
ORDER BY views DESC;
```

---

## Maintenance

### テーブルサイズ確認

```sql
SELECT count(*) AS total_events,
       pg_size_pretty(pg_total_relation_size('analytics_events')) AS table_size
FROM analytics_events;
```

### 古いイベントの削除（90日以上前）

```sql
-- ⚠ 実行前に件数を確認
SELECT count(*) FROM analytics_events WHERE created_at < CURRENT_DATE - INTERVAL '90 days';

-- バッチ削除（1000件ずつ、テーブルロックを最小化）
-- 件数が 0 になるまで繰り返し実行
DELETE FROM analytics_events
WHERE id IN (
  SELECT id FROM analytics_events
  WHERE created_at < CURRENT_DATE - INTERVAL '90 days'
  LIMIT 1000
);
```
