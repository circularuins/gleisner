import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gleisner Design Tokens
///
/// Single source of truth for all visual constants.
/// Import this file instead of hardcoding Color/fontSize/padding values.

// ---------------------------------------------------------------------------
// Colors — Dark theme palette
// ---------------------------------------------------------------------------

/// Background surfaces (3 tiers — resist adding more)
const colorSurface0 = Color(0xFF0a0a0f); // Deepest background (timeline canvas)
const colorSurface1 = Color(0xFF0c0c12); // Cards, sheets, elevated surfaces
const colorSurface2 = Color(0xFF151520); // Raised elements (badges, pills)

/// Borders & dividers
const colorBorder = Color(0xFF1a1a28);

/// Text hierarchy (3 tiers)
const colorTextPrimary = Color(0xFFf0f0f5); // Headings, important text
const colorTextSecondary = Color(0xFFccccdd); // Body text
const colorTextMuted = Color(0xFF9999b0); // Captions, timestamps

/// Interactive elements (2 tiers)
const colorInteractive = Color(0xFF8888a0); // Icons, buttons, active states
const colorInteractiveMuted = Color(0xFF666688); // Disabled, secondary actions

/// Functional
const colorError = Color(0xFFef4444);

/// Material 3 seed
const colorSeed = Color(0xFF6C63FF);

/// Accent: warm gold for primary actions (distinct from all track colors)
const colorAccentGold = Color(0xFFd4af37);

/// Fallback
const colorTrackFallback = Color(0xFF808080);

/// Warm off-white "paper" color used for polaroid-style photo frames in the
/// multi-image timeline pile (fresh / newer polaroid tone).
const colorPaperWhite = Color(0xFFf5f0e2);

/// Yellowed paper tone for aged polaroid frames. Per-tile lerp between
/// [colorPaperWhite] and this gives each photo in the pile its own age.
const colorPaperAged = Color(0xFFe8d3a8);

/// Base color for the sepia / haze overlay laid on top of polaroid images
/// (applied at low alpha to simulate fading and dustiness).
const colorPaperAgingTint = Color(0xFF8b6e3f);

// ---------------------------------------------------------------------------
// Activity grid palette (Idea 032)
// ---------------------------------------------------------------------------
// GitHub-style contribution grid reinterpreted in Gleisner's universe
// vocabulary: cells are calendar squares for legibility, but active ones
// glow with the same track-palette cyan/violet that the rest of the
// product uses for "alive" surfaces. Tier brightness is achieved by
// alpha-layering the base hue over a dark empty cell; the top tier
// blends toward violet to read as a small nebula.

/// Empty / inactive cell. Sits one shade above `colorSurface1` so the
/// grid reads as a discrete shape rather than transparent voids, but
/// stays muted enough that the active cells dominate visually.
const colorActivityEmpty = Color(0xFF1f1f2e);

/// Base hue for active cells — track-palette cyan. Layered at rising
/// alpha across the four post-count tiers and blended toward
/// `colorActivityHigh` at the nebula tier.
const colorActivityBase = Color(0xFF22d3ee);

/// Top-tier accent — track-palette violet. Used for the 7+ posts
/// nebula tier's cell tint, its outer halo, and the legend's
/// rightmost swatch.
const colorActivityHigh = Color(0xFF8b5cf6);

/// Tiny inner sparkle drawn on top-tier cells to give them a star /
/// lens-flare quality without sacrificing the calendar shape.
const colorActivitySparkle = Color(0xFFf5f5fa);

// ---------------------------------------------------------------------------
// Typography — Font sizes (6-step scale)
// ---------------------------------------------------------------------------

const fontSizeXs = 10.0; // Micro labels, badges
const fontSizeSm = 12.0; // Captions, metadata
const fontSizeMd = 14.0; // Body text, form labels
const fontSizeLg = 16.0; // Primary body, buttons
const fontSizeXl = 18.0; // Section headers
const fontSizeTitle = 22.0; // Page titles, detail sheet titles

// ---------------------------------------------------------------------------
// Font weights
// ---------------------------------------------------------------------------

const weightNormal = FontWeight.w400;
const weightMedium = FontWeight.w500;
const weightSemibold = FontWeight.w600;
const weightBold = FontWeight.w700;

// ---------------------------------------------------------------------------
// Spacing — 4px base scale
// ---------------------------------------------------------------------------

const spaceXxs = 2.0;
const spaceXs = 4.0;
const spaceSm = 8.0;
const spaceMd = 12.0;
const spaceLg = 16.0;
const spaceXl = 24.0;
const spaceXxl = 32.0;

// ---------------------------------------------------------------------------
// Border radius
// ---------------------------------------------------------------------------

const radiusSm = 4.0;
const radiusMd = 8.0;
const radiusLg = 12.0;
const radiusXl = 16.0;
const radiusSheet = 20.0;
const radiusFull = 999.0;

// ---------------------------------------------------------------------------
// Tap target / swatch sizes
// ---------------------------------------------------------------------------

/// Minimum interactive tap target per Material guidelines (matches
/// Flutter's `kMinInteractiveDimension`).
const tapTargetMin = 44.0;

/// Visible diameter of a color swatch dot inside a tappable cell. The
/// outer cell is `tapTargetMin` so the dot floats inside a generous
/// touch zone for color-vision-deficient users.
const swatchVisibleSize = 32.0;

// ---------------------------------------------------------------------------
// Responsive breakpoints (Idea 030)
// ---------------------------------------------------------------------------

const breakpointTablet = 600.0;
const breakpointDesktop = 1024.0;

/// Content max-width on large screens (centered with padding)
const maxContentWidth = 1200.0;

/// Side panel width on desktop (detail sheet replacement)
const sidePanelWidth = 420.0;

/// Navigation rail width on desktop/tablet
const navRailWidth = 72.0;

/// True if the width is tablet or wider (>= 600px).
bool isTabletOrWider(double width) => width >= breakpointTablet;

/// True if the width is desktop (>= 1024px).
bool isDesktop(double width) => width >= breakpointDesktop;

/// True when the timeline should use horizontal (DAW-style) scrolling.
///
/// Tied to the same breakpoint as the NavigationRail (Idea 030): the
/// timeline orientation flips together with the side nav. Reads the screen
/// width via [MediaQuery.sizeOf] (size-only dependency) so it can be safely
/// called outside `LayoutBuilder` — `LayoutBuilder` builders should never
/// touch `MediaQuery.of` directly because non-size changes (textScale,
/// viewInsets) would trigger redundant constraint rebuilds.
///
/// At the lower edge of the breakpoint (≥600 px screen) the NavigationRail
/// consumes [navRailWidth] (72 px) plus a 1 px divider, so the effective
/// horizontal canvas can be as narrow as ~527 px. [ConstellationLayout]
/// must keep nodes legible at that width — verify when changing layout
/// constants. The desktop side panel ([sidePanelWidth]) opens only at
/// ≥1024 px, where there is enough room left for the canvas.
bool useHorizontalTimeline(BuildContext context) =>
    isTabletOrWider(MediaQuery.sizeOf(context).width);

/// Responsive grid column count for card grids (Discover, etc.).
int responsiveGridColumns(double width) {
  if (width >= breakpointDesktop) return 4;
  if (width >= breakpointTablet) return 3;
  return 2;
}

// ---------------------------------------------------------------------------
// Track color presets
//
// Used for both
//   (1) auto-assigning a color when a track is created without an explicit
//       picker selection (e.g. the artist registration wizard's default
//       drafts), and
//   (2) the preset swatch grid in `TrackColorPicker` so the quick-pick
//       chips share the same palette as the auto-assignment rotation.
// ---------------------------------------------------------------------------

const trackColorPresets = [
  '#f97316', // orange
  '#a78bfa', // purple
  '#22d3ee', // cyan
  '#84cc16', // lime
  '#ef4444', // red
  '#fbbf24', // amber
  '#ec4899', // pink
  '#14b8a6', // teal
  '#8b5cf6', // violet
  '#f43f5e', // rose
];

// ---------------------------------------------------------------------------
// Opacity presets
// ---------------------------------------------------------------------------

const opacityDisabled = 0.38;
const opacityOverlay = 0.5;
const opacitySubtle = 0.12;
const opacityBorder = 0.3;

// ---------------------------------------------------------------------------
// Common text styles (convenience)
// ---------------------------------------------------------------------------

/// Display font for headings and titles.
final textTitle = GoogleFonts.urbanist(
  color: colorTextPrimary,
  fontSize: fontSizeTitle,
  fontWeight: weightBold,
  height: 1.3,
);

final textHeading = GoogleFonts.urbanist(
  color: colorTextPrimary,
  fontSize: fontSizeXl,
  fontWeight: weightSemibold,
);

/// Body font for readable content.
final textBody = GoogleFonts.plusJakartaSans(
  color: colorTextSecondary,
  fontSize: fontSizeLg,
  height: 1.6,
);

final textCaption = GoogleFonts.plusJakartaSans(
  color: colorTextMuted,
  fontSize: fontSizeSm,
);

final textMicro = GoogleFonts.plusJakartaSans(
  color: colorTextMuted,
  fontSize: fontSizeXs,
  fontWeight: weightSemibold,
  letterSpacing: 0.5,
);

final textLabel = GoogleFonts.plusJakartaSans(
  color: colorInteractiveMuted,
  fontSize: fontSizeSm,
  fontWeight: weightMedium,
);

/// Monospace font family for URLs and code.
final monoFontFamily = GoogleFonts.jetBrainsMono().fontFamily;

// ---------------------------------------------------------------------------
// Shadows — Stacked drop shadows for foreground content over cover images
// ---------------------------------------------------------------------------

/// Two-layer black shadow for icons / text rendered on top of an arbitrary
/// cover image or hero photo. The tight inner shadow defines a sharp dark
/// silhouette around the glyph; the wider outer shadow adds a soft halo
/// that keeps near-white foreground content legible even on light photos
/// (sky, snow, paper). Use this in preference to wrapping icons in a
/// semi-transparent backdrop chip, which adds visual weight.
///
/// Color literals are const-friendly forms of `Colors.black.withValues(...)`:
///   0xB3000000 ≈ alpha 0.70  (179/255)
///   0x66000000 ≈ alpha 0.40  (102/255)
const coverIconShadows = <Shadow>[
  Shadow(color: Color(0xB3000000), blurRadius: 8),
  Shadow(color: Color(0x66000000), blurRadius: 16),
];
