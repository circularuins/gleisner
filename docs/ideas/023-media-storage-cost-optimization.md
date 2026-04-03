# Idea 023: Media Storage Cost Optimization

## Summary

As Gleisner grows beyond family use, media storage costs (especially video) will become significant. This document outlines a staged approach to keep costs manageable while preserving the lifelog principle (data is never deleted).

## Cost Model (Cloudflare R2)

| Resource | Free Tier | Overage |
|----------|-----------|---------|
| Storage | 10 GB | $0.015/GB/month |
| Class A ops (PUT) | 1M/month | $4.50/1M |
| Class B ops (GET) | 10M/month | $0.36/1M |
| Egress | Unlimited | Free |

Storage is cumulative — it grows as users upload and never shrinks (lifelog).

### Projected Costs (1 year cumulative)

| Users | Avg/user | Total Storage | Monthly Cost |
|-------|----------|---------------|-------------|
| 5 (family) | 500 MB | 30 GB | $0.30 |
| 50 (invite) | 500 MB | 300 GB | $4.35 |
| 500 | 500 MB | 3 TB | $43.50 |
| 5,000 (public) | 500 MB | 30 TB | $435 |

## Optimization Stages

### Stage 1: Per-User Storage Quota (before invite expansion)

Track cumulative bytes uploaded per user. Enforce a quota (e.g., 1 GB free tier). Reject uploads that would exceed the quota.

- Add `storage_used_bytes` column to `users` table
- Increment on successful upload, decrement on delete (if ever implemented)
- Return remaining quota in `me` query for UI display
- **Issue**: Create when implementing

### Stage 2: Server-Side Video Transcoding (before public launch)

Raw uploaded videos are typically 3-10x larger than necessary. Transcode to 720p H.264 after upload.

**Option A: Cloudflare Stream**
- Managed service: $1/1000 min stored, $0.50/1000 min viewed
- API-based, minimal infrastructure
- Adaptive bitrate streaming included

**Option B: Self-hosted FFmpeg (on Railway or dedicated worker)**
- One-time setup cost, no per-minute charges
- More control over quality/format
- Requires compute resources

**Recommendation**: Start with Cloudflare Stream for simplicity. Migrate to self-hosted only if costs become prohibitive at scale.

### Stage 3: Tiered Storage (at scale)

Move media older than N months to cheaper storage tier. R2 Infrequent Access is planned but not yet available. Alternative: move to Backblaze B2 ($0.005/GB/month) with Cloudflare CDN in front.

### Stage 4: Client-Side Video Compression (iOS/Android)

When native apps launch, use `video_compress` or similar to transcode on-device before upload. This is not feasible on Flutter Web but works well on mobile. Reduces upload time and storage simultaneously.

## Current Settings (as of Idea creation)

| Media Type | Max Upload Size | Client Compression |
|-----------|----------------|-------------------|
| Avatar | 5 MB | 512x512, quality 75% |
| Cover | 10 MB | 1280x720, quality 75% |
| Post Image | 100 MB | 1280x1280, quality 75% |
| Post Video | 100 MB | None (raw upload) |
| Post Audio | 100 MB | None (raw upload) |

## Dependencies

- ADR 015 (R2 selected as storage backend)
- Idea 019 (media upload implementation)
- Idea 022 (pre-launch checklist — quota should be checked before invite expansion)
