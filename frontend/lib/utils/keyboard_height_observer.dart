// ignore_for_file: avoid_web_libraries_in_flutter
//
// Reliable soft-keyboard height for Flutter Web on iOS Safari.
//
// Problem: `MediaQuery.of(context).viewInsets.bottom` is unreliable on
// Flutter Web in iOS Safari. Long-standing engine issues
// (flutter/flutter#42211, #56039, #146726, #80253, #135800) cause it to
// either stay at 0 when the keyboard is visible, lag behind the actual
// transition, or — when the dynamic toolbar is involved — momentarily
// report values larger than the keyboard. This breaks every
// `Padding(EdgeInsets.only(bottom: viewInsets.bottom))` and AlertDialog
// `insetPadding.bottom` in the app.
//
// Strategy: cross-check Flutter's MediaQuery against the DOM-side
// `window.visualViewport` API and pick the larger plausible value, then
// clamp to `screenHeight * 0.6` so a transient over-report can't push a
// dialog off the top of the screen.
//
// ```text
// keyboardHeight = clamp(
//   max(MediaQuery.viewInsets.bottom, innerHeight − vv.height − vv.offsetTop),
//   0,
//   screenHeight * 0.6,
// )
// ```
//
// Wrap your `MaterialApp.builder` with `KeyboardHeightObserver(child: child)`
// and read the value via `KeyboardHeight.of(context)` from any descendant.
// Falls back to `MediaQuery.viewInsets.bottom` when no observer is in scope
// (tests, isolated widgets), so consumers stay correct even outside the
// wrapped tree.

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

/// Maximum keyboard height as a fraction of the screen height. iOS / Android
/// soft keyboards in portrait take roughly 35–45% of the screen; 60% leaves
/// generous headroom for the predictive bar and oversized accessory views
/// while still rejecting clearly bogus over-reports.
const double _maxKeyboardScreenFraction = 0.6;

/// Wraps the app and exposes the current keyboard height to descendants
/// through an [InheritedWidget]. Must wrap a subtree that has a [MediaQuery]
/// (typically placed in `MaterialApp.builder`).
class KeyboardHeightObserver extends StatefulWidget {
  final Widget child;

  const KeyboardHeightObserver({super.key, required this.child});

  @override
  State<KeyboardHeightObserver> createState() => _KeyboardHeightObserverState();
}

class _KeyboardHeightObserverState extends State<KeyboardHeightObserver>
    with WidgetsBindingObserver {
  double _keyboardHeight = 0;

  // JSFunction references are captured so removeEventListener can find them.
  JSFunction? _vvHandler;
  JSFunction? _winHandler;

  // Coalesce multiple change signals (didChangeMetrics + visualViewport
  // resize + window resize all firing in the same frame) into a single
  // post-frame recompute so we don't thrash setState.
  bool _recalcScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      try {
        _vvHandler = ((web.Event _) => _scheduleRecalculate()).toJS;
        _winHandler = ((web.Event _) => _scheduleRecalculate()).toJS;
        final vv = web.window.visualViewport;
        if (vv != null) {
          vv.addEventListener('resize', _vvHandler!);
          vv.addEventListener('scroll', _vvHandler!);
        }
        web.window.addEventListener('resize', _winHandler!);
      } catch (_) {
        // Best-effort: if DOM hooks fail we still get MediaQuery updates via
        // didChangeMetrics, so the observer degrades gracefully.
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      try {
        final vv = web.window.visualViewport;
        if (vv != null && _vvHandler != null) {
          vv.removeEventListener('resize', _vvHandler!);
          vv.removeEventListener('scroll', _vvHandler!);
        }
        if (_winHandler != null) {
          web.window.removeEventListener('resize', _winHandler!);
        }
      } catch (_) {}
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Flutter's view of the keyboard. Fires on both keyboard show/hide and
  // on URL bar / safe-area changes.
  @override
  void didChangeMetrics() {
    _scheduleRecalculate();
  }

  void _scheduleRecalculate() {
    if (_recalcScheduled) return;
    _recalcScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _recalcScheduled = false;
      if (!mounted) return;
      _recalculate();
    });
  }

  void _recalculate() {
    final mq = MediaQuery.maybeOf(context);
    final mqBottom = mq?.viewInsets.bottom ?? 0.0;
    final screenHeight = mq?.size.height ?? 0.0;

    double domBottom = 0.0;
    if (kIsWeb) {
      try {
        final vv = web.window.visualViewport;
        if (vv != null) {
          // The visual viewport shrinks when the iOS keyboard appears.
          // `offsetTop` becomes nonzero if the user has scrolled the page so
          // an input stays visible above the keyboard; subtracting it keeps
          // the math correct in that case.
          final innerH = web.window.innerHeight.toDouble();
          final vvH = vv.height.toDouble();
          final vvTop = vv.offsetTop.toDouble();
          final calc = innerH - vvH - vvTop;
          if (calc > 0) domBottom = calc;
        }
      } catch (_) {}
    }

    // Clamp each source independently before max-ing so a single bad reading
    // (e.g. iOS Safari briefly reporting innerHeight > viewport.height + 1000)
    // can't poison the picked value.
    final maxAllowed = screenHeight > 0
        ? screenHeight * _maxKeyboardScreenFraction
        : 1000.0;
    final mqClamped = mqBottom.clamp(0.0, maxAllowed);
    final domClamped = domBottom.clamp(0.0, maxAllowed);

    // Take the larger of the two — whichever channel actually noticed the
    // keyboard. When both are 0 the keyboard is not visible.
    final newHeight = mqClamped > domClamped ? mqClamped : domClamped;

    // Threshold avoids re-render storms when iOS Safari's visualViewport
    // jitters by sub-pixel amounts during the keyboard slide-in animation.
    if ((newHeight - _keyboardHeight).abs() > 0.5) {
      setState(() => _keyboardHeight = newHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Inject our cross-checked keyboard height into MediaQuery's viewInsets so
    // every descendant — Scaffold's resizeToAvoidBottomInset,
    // DraggableScrollableSheet, BottomSheet, AlertDialog, anything that reads
    // viewInsets.bottom directly — sees the value Flutter would normally
    // provide on native. Flutter Web on iOS Safari fails to propagate
    // visualViewport changes to viewInsets.bottom (it stays at 0 even while
    // the soft keyboard occupies ~50% of the screen, see
    // flutter/flutter#42211, #56039, #146726). Live readings on iPhone
    // Safari with the DOM HUD (PR #341) confirmed this exact divergence:
    // visualViewport.height collapses from 695 to 358 (= 337px keyboard) while
    // MediaQuery.viewInsets.bottom remains 0.
    //
    // Without this override, no amount of `viewInsets.bottom`-based padding
    // helps because the framework still lays out at `MediaQuery.size.height`
    // pixels and pins sheets/dialogs to the bottom of that taller-than-visible
    // box — pushing their lower halves behind the keyboard.
    final patchedMq = mq.copyWith(
      viewInsets: mq.viewInsets.copyWith(bottom: _keyboardHeight),
    );

    return MediaQuery(
      data: patchedMq,
      child: _KeyboardHeightInherited(
        keyboardHeight: _keyboardHeight,
        child: widget.child,
      ),
    );
  }
}

class _KeyboardHeightInherited extends InheritedWidget {
  final double keyboardHeight;

  const _KeyboardHeightInherited({
    required this.keyboardHeight,
    required super.child,
  });

  @override
  bool updateShouldNotify(_KeyboardHeightInherited old) =>
      keyboardHeight != old.keyboardHeight;
}

/// Reads the current soft-keyboard height in logical pixels.
///
/// - When wrapped in a [KeyboardHeightObserver] (the normal case via
///   `MaterialApp.builder`), returns the cross-checked value (max of
///   MediaQuery + visualViewport, clamped).
/// - Outside the wrapped tree (tests, isolated widget trees),
///   transparently falls back to `MediaQuery.of(context).viewInsets.bottom`
///   so callers keep working without special-casing.
///
/// Causes the calling widget to rebuild when the value changes.
class KeyboardHeight {
  static double of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_KeyboardHeightInherited>();
    if (inherited != null) return inherited.keyboardHeight;
    return MediaQuery.of(context).viewInsets.bottom;
  }
}
