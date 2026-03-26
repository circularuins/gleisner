# Idea 019: Media Upload & Cloudflare R2 Integration

## Summary

Replace URL direct input with actual file upload for avatars, cover images, and post media (image/video/audio). Use Cloudflare R2 (S3-compatible, selected in ADR 015) as the storage backend.

## Current State

- Avatar URL, cover image URL, media URL are all manual text input
- Backend accepts any URL — no domain restriction
- No file upload API exists

## Scope

### Phase 1: Avatar & Cover Image (lightweight)
- Signed upload URL API (`getUploadUrl` mutation)
- Client uploads directly to R2 via PUT
- Image picker UI (camera + gallery) for avatar/cover
- Crop/resize on client before upload
- R2 domain validation on save

### Phase 2: Post Media (heavier)
- Image/video/audio upload in create_post and edit_post screens
- Upload progress indicator
- Client-side compression/resize (images), thumbnail generation
- File size limits (TBD per media type)
- Replace "upload coming soon" placeholder in create_post_screen

## Infrastructure

- **Storage**: Cloudflare R2 bucket (prod + dev)
- **Upload flow**: Backend generates signed URL → Client PUTs to R2 → Client saves R2 URL to DB
- **Local dev**: MinIO (S3-compatible) or R2 dev bucket — TBD
- **Domain**: R2 custom domain or `pub-xxx.r2.dev`

## Timing

Implement alongside deployment preparation (Railway + Cloudflare Pages), so R2 credentials, domain configuration, and environment variables can be set up together.

## Dependencies

- ADR 015 (tech stack — R2 selected)
- Deployment setup (Railway + Cloudflare Pages)
