# Idea 030: Responsive Layout for Desktop and Tablet

**Status:** Validated
**Priority:** Phase 0 required
**Date:** 2026-04-09

## Summary

Adapt the current mobile-first UI for desktop and tablet screen sizes. The timeline should switch to horizontal scrolling on wider screens (mirroring a real DAW timeline), and other screens need layout adjustments for larger viewports.

## Notes

### Timeline (core change)

- Current: Vertical scroll with constellation layout (`SingleChildScrollView`, vertical axis, `ConstellationLayout` computes node positions within a fixed-width column)
- Desktop/Tablet: Switch to **horizontal scroll** to match the DAW metaphor (ADR 004) — time flows left-to-right, tracks stack vertically
- The constellation layout algorithm (`constellation_layout.dart`) would need a mode toggle or separate layout strategy for horizontal orientation
- Track filter rail (currently horizontal chips at top) may move to a vertical sidebar on wide screens
- Avatar rail positioning may change

### Breakpoint strategy

- Consider 3 tiers: mobile (< 600px), tablet (600–1024px), desktop (> 1024px)
- ADR 015 mentions "Phase 2: Add responsive breakpoints for mobile browsers"
- Flutter's `LayoutBuilder` / `MediaQuery` for breakpoint detection
- May need a `ResponsiveScaffold` wrapper or similar pattern

### Detail sheets / bottom sheets

- Current: `DraggableScrollableSheet` (mobile-centric)
- Desktop: May need to switch to side panels or dialog overlays instead of bottom sheets
- Post detail could appear as a right-side panel (master-detail pattern)

### Post creation / editing

- Current: Full-screen push navigation
- Desktop: Could use a dialog or split-pane layout
- Form fields may benefit from wider layout (multi-column)

### Navigation

- Current: `StatefulShellRoute` with bottom navigation bar
- Desktop: Sidebar navigation (persistent left rail) would be more natural
- Tab switching logic may need adaptation

### Other screens to consider

- Discover: Card grid could use more columns on wider screens
- Profile / Artist page: Content could be arranged in columns
- Onboarding: May need centering / max-width constraints

### Performance consideration

- Horizontal timeline with many nodes may need virtualization (visible-area-only rendering)
- Current vertical scroll uses `RepaintBoundary` per node but no full virtualization

### Related

- ADR 004 (DAW-style timeline concept)
- ADR 006 (Constellation visual design — currently assumes vertical scroll)
- ADR 015 (Technology stack — mentions responsive phases)
- Idea 025 (Media type polish — per-type layouts may need responsive variants)
