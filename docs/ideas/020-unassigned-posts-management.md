# Idea 020: Unassigned Posts Management

## Summary

When a track is deleted, its posts become unassigned (`trackId = null`) instead of being deleted. These posts are hidden from the timeline but can be managed from the Profile screen, where the user can reassign them to another track.

## Background

- Schema changed: `posts.trackId` is now nullable with `onDelete: "set null"` (previously `cascade`)
- Timeline display requires a track — unassigned posts are excluded
- Users need a way to recover/reassign posts after track deletion

## Design

### Profile Screen: Unassigned Posts Section
- Show count of unassigned posts (if any)
- Tap to open list view of unassigned posts
- Each post shows: title/body preview, media type icon, created date
- Tap post → edit screen (track selector allows reassignment)
- Bulk reassign option (select multiple → choose track)

### Timeline Behavior
- `trackId = null` posts are filtered out of timeline queries
- After reassignment, post appears in the new track's timeline

### Backend
- `posts` query should filter `WHERE track_id IS NOT NULL` (or handle in frontend)
- Consider a `myUnassignedPosts` query for the profile screen

## Dependencies

- Schema change: done (posts.trackId nullable, onDelete: set null)
- Edit post track selector: done (edit_post_screen.dart)
