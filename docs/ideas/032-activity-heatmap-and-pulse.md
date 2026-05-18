# Idea 032: Star Calendar Heatmap & Pulse Beacon

**Status:** Validated
**Priority:** Phase 0.x (immediate)
**Date:** 2026-05-18

## Summary

Visualize per-artist daily posting activity using two complementary components themed around Gleisner's "artist's universe" metaphor: (1) a **star calendar** heatmap on the artist page (GitHub-style contribution grid reinterpreted as a night sky), and (2) a **pulse beacon** dot on discovery cards indicating recency of activity. The goal is to make daily posting feel visibly rewarded and to surface "alive" artists in discovery, reinforcing posting motivation among the current ~4 active artists.

## Notes

### Component 1: Star calendar (artist page)

- Placed directly below the Tune In button on the artist page
- Grid: 7 rows × N weeks (N = weeks since registration, capped at 52; horizontal scroll for older artists)
- Cell shape: **circles**, not squares — more cosmic, less industrial; row spacing slightly looser than GitHub
- Background per cell: deep space color (`#0A0E1A`-ish), optional faint star dust noise
- Active cells map post count to star brightness:
  - 1 post: faint small star (low-opacity white)
  - 2–3: brighter star with mild glow
  - 4–6: bright star + halo
  - 7+: cluster / nebula — largest glow, accent tint (cyan or violet)
- Optional sparse twinkle animation (performance-budgeted)
- Tooltip on hover/tap: `YYYY/MM/DD · N 件の投稿` (empty days show just date)
- Empty-state copy for brand-new artists: 「これから星が灯ります」 (or English equivalent in i18n)
- Naming candidates for the section header: 星暦 (せいれき) / 光跡 (こうせき) / "Star Calendar"

### Component 2: Pulse beacon (discovery cards)

- Position: top-right of the artist card cover image, 8–12px dot
- Maps last-posted recency to a beacon state:
  - Within 24h: bright cyan/white, fast breathing pulse (~1.2s cycle)
  - Within 7d: warm white, slower pulse (~2s)
  - Within 30d: dim static glow (no animation)
  - >30d: hidden — silence is a meaningful state
- Animation drives **opacity only**, never scale/transform — keeps GPU cost flat across many cards
- Optional long-press / hover: textual recency ("3 日前にアクティブ")

### Backend

- New endpoint, e.g., `GET /artists/:id/activity` returning:
  - `series: { date: ISODate, count: int }[]` for the calendar (registration → today, capped at 365 entries)
  - `lastPostedAt: ISODate | null` for the beacon
- Daily aggregate is cheap; cache per-day (or compute on demand and HTTP-cache 1h)
- For the discovery list, `lastPostedAt` may be inlined into the artist list response to avoid N+1 fetches

### Frontend (Flutter)

- `CustomPainter` for the calendar grid — paint cells in one pass, avoid per-cell widgets
- `AnimationController` for the pulse, with a single controller per visible card; consider a shared ticker if many cards animate
- Wrap discovery cards in `RepaintBoundary` to localize repaints (see [[project_constellation_performance.md]])
- Respect reduced-motion preferences: disable twinkle and pulse animation when set

### Phase considerations

- Star calendar works in Phase 0 context too — the "family lifelog" framing ("our child's activity sky") is a natural fit
- Pulse beacon depends on Discovery being visible; ship together if Discovery is already exposed to current users
- This idea is greenlit for immediate implementation despite Phase 0 timing because the 4 active artists' visible reward loop directly affects retention

### Open questions

- Does the heatmap count **all** posts or only public/timeline-visible posts? (Affects how private/draft activity is reflected.) Default: count all posts the viewer is permitted to see — i.e., apply existing visibility filter at aggregation time.
- For an artist with <7 days of registration, should the calendar render at all or wait until there's enough horizontal width? Suggestion: always render, padded left so the first week aligns to "today" column.
- Privacy: should an artist be able to opt out of showing the heatmap or pulse? Probably yes longer-term; not required for v1.

### Related

- ADR 006 (Constellation visual design — star/space metaphor source)
- ADR 008 (Artist mode / Fan mode — affects who sees what)
- ADR 009 (Discover tab — host surface for the pulse beacon)
- ADR 013 (Profile and artist page — host surface for the calendar)
- Idea 005 (Synapse timeline — adjacent universe-themed visualization)
- Idea 015 (View count display — adjacent activity-metric display)
