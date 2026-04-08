/// Estimate reading time for mixed English/CJK text.
/// Returns 0 for very short text (< 50 chars).
int estimateReadingMinutes(String text) {
  if (text.length < 50) return 0;
  // Count CJK characters (Chinese, Japanese, Korean)
  final cjk = RegExp(r'[\u3000-\u9fff\uf900-\ufaff]');
  final cjkCount = cjk.allMatches(text).length;
  // Count English words (non-CJK, space-separated)
  final nonCjk = text.replaceAll(cjk, ' ');
  final wordCount = nonCjk
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
  // ~200 wpm English, ~400 cpm CJK
  final minutes = (wordCount / 200) + (cjkCount / 400);
  return minutes.ceil().clamp(0, 99);
}
