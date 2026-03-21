# Idea 013: Multiple artist profiles as a paid feature

**Status:** Raw idea
**Date:** 2026-03-21

## Summary

Free tier allows one artist profile per user account. Paid plan unlocks multiple artist profiles, enabling users who perform under different names or genres to maintain separate identities. This creates a natural upgrade path: users discover the need as they grow on the platform.

## Notes

### Conversion funnel

- Free: 1 user → 1 artist profile (sufficient for getting started)
- The need for multiple profiles emerges organically: "I want to separate my jazz persona from my electronic music project"
- By this point the user is invested in the platform → natural willingness to pay
- Real-world validation: surprisingly common among musicians to use multiple stage names for different genres

### Architecture considerations

- Current schema already supports 1:1 user→artist relationship (`artists.userId` with unique constraint)
- Paid plan would relax this to 1:N (remove unique constraint, add plan-based limit check)
- Each artist profile has its own tracks, posts, followers, tune-ins — fully independent timelines
- User can switch between artist profiles (similar to YouTube channel switching)
- DID implications: each artist profile could have its own DID, or share the user's DID with sub-identifiers

### UX flow

- Profile switcher in the header (like YouTube/Instagram account switching)
- "Create another artist profile" button in settings → hits the paywall if on free tier
- Each profile has its own timeline, followers, and creative journey
- Cross-profile content sharing could be a feature (re-post from one persona to another)

### Pricing model considerations

- This is a "quality of life" upgrade, not a gated core feature — aligns with the Egan principle of self-determination
- Could be bundled with other premium features (AI Coach from Idea 010, extra storage, etc.)
- Avoid punishing existing users: if someone already has content, ensure smooth upgrade experience

### Related

- Idea 003 (Artist/Fan mode): multiple artist profiles add complexity to mode switching
- Idea 010 (AI Coach): potential premium bundle
- ADR 014 (DID): multi-profile DID delegation needs design
- Current schema: `artists` table has `userId` → would need plan-based limit enforcement
