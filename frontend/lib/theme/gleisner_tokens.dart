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
// Track color presets (for auto-assignment)
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
