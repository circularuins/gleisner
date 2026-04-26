/// JPEG quality presets used by the upload pipeline.
///
/// Two distinct settings: thumbnails are aggressively compressed because
/// they're decorative and bandwidth-sensitive (Timeline / Discover scrolling
/// loads many at once); full-image conversions trade size for fidelity
/// because the user is going to view them at native resolution.
///
/// Values are double-precision JPEG quality in 0.0..1.0 (Web Canvas API
/// convention). For the `image_picker` `imageQuality` 1..100 integer scale,
/// multiply by 100 and clamp to 1..85 (`image_picker` ignores values >=
/// 85 on iOS; clamping forces re-encode + EXIF strip).
///
/// Related: ADR 022 (EXIF metadata removal), Issues #175 / #179.
library;

/// Video first-frame thumbnail. Goes onto Timeline cards behind the play
/// icon — visible but small. 0.75 keeps file size in the ~30 KB range while
/// remaining indistinguishable from 0.9 at thumbnail scale.
const double kThumbnailJpegQuality = 0.75;

/// HEIC → JPEG conversion for full-size images uploaded from Apple
/// devices. The output is shown at native resolution in the post detail
/// view, so we keep more detail. 0.85 is the standard "good quality"
/// preset that most still photo libraries default to.
const double kHeicConversionJpegQuality = 0.85;

/// Canvas-API metadata-stripping re-encode (EXIF / XMP / IPTC scrubbing).
/// Same fidelity rationale as the HEIC conversion path — full-size image,
/// shown at native resolution. Kept as a separate constant so each path's
/// rationale is documented even when the numbers happen to coincide.
const double kImageSanitizeJpegQuality = 0.85;

/// Upper bound for `image_picker.pickImage(imageQuality: ...)`.
///
/// `image_picker`'s `imageQuality` accepts 1..100 but only triggers a
/// re-encode below ~85 on iOS — values >= 85 may pass the original bytes
/// through (per `image_picker` issue tracker). Clamp callers to 85 max so
/// EXIF is always stripped via re-encode.
const int kImagePickerMaxQuality = 85;
