/// Deterministic RNG seeded from a string.
///
/// Mirrors the HTML mock's `mkRng()` function for consistent visual output.
class DeterministicRng {
  int _h;

  DeterministicRng(String seed) : _h = 0 {
    for (int i = 0; i < seed.length; i++) {
      _h = ((_h << 5) - _h + seed.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    if (_h >= 0x80000000) _h -= 0x100000000;
  }

  double next() {
    _h = (_h * 16807) % 2147483647;
    return (_h & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}
