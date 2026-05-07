// ignore_for_file: avoid_web_libraries_in_flutter
//
// Temporary diagnostics overlay for the iPhone Safari soft-keyboard issue.
// Activated only when the URL contains `?debug=keyboard` (or `&debug=keyboard`).
// Shows MediaQuery viewInsets / size alongside DOM-side window.innerHeight and
// visualViewport metrics so we can see — on a real device — what value the
// `MediaQuery.viewInsets.bottom`-based layout fixes are actually receiving
// while the keyboard is open.
//
// **Do not ship in production.** Once the root cause is confirmed and the real
// fix has landed, delete this file and the `builder:` hook in `app.dart`.

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Returns true when the current page URL has `debug=keyboard` in its query
/// string (search portion). False on non-web targets and when the query is
/// absent or unreadable.
bool keyboardDebugOverlayEnabled() {
  if (!kIsWeb) return false;
  try {
    final search = web.window.location.search;
    // `search` is e.g. "?debug=keyboard" or "?foo=1&debug=keyboard".
    return search.contains('debug=keyboard');
  } catch (_) {
    return false;
  }
}

/// Diagnostics overlay. Wrap the child returned by `MaterialApp.builder` with
/// `KeyboardDebugOverlay(child: child)` and the overlay will be drawn on top
/// of every screen when the URL flag is set.
class KeyboardDebugOverlay extends StatefulWidget {
  final Widget child;

  const KeyboardDebugOverlay({super.key, required this.child});

  @override
  State<KeyboardDebugOverlay> createState() => _KeyboardDebugOverlayState();
}

class _KeyboardDebugOverlayState extends State<KeyboardDebugOverlay>
    with WidgetsBindingObserver {
  // Keep references so we can remove them on dispose. Each addEventListener
  // call needs the same JSFunction reference for removeEventListener to work.
  JSFunction? _vvHandler;
  JSFunction? _winHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      try {
        final handler = ((web.Event _) => _markDirty()).toJS;
        _vvHandler = handler;
        final vv = web.window.visualViewport;
        if (vv != null) {
          vv.addEventListener('resize', handler);
          vv.addEventListener('scroll', handler);
        }
        _winHandler = ((web.Event _) => _markDirty()).toJS;
        web.window.addEventListener('resize', _winHandler!);
      } catch (_) {
        // Ignore — overlay just won't update on DOM events.
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      try {
        final vv = web.window.visualViewport;
        final h = _vvHandler;
        if (vv != null && h != null) {
          vv.removeEventListener('resize', h);
          vv.removeEventListener('scroll', h);
        }
        final wh = _winHandler;
        if (wh != null) {
          web.window.removeEventListener('resize', wh);
        }
      } catch (_) {}
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Catches MediaQuery changes (Flutter's view of the keyboard).
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  void _markDirty() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!keyboardDebugOverlayEnabled()) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        // Top-right corner. SafeArea so the notch / status bar doesn't cover it.
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _DebugPanel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    String winH = '?';
    String winW = '?';
    String vvH = '?';
    String vvW = '?';
    String vvTop = '?';
    String vvLeft = '?';
    String vvScale = '?';
    String calcKb = '?';
    String docVisH = '?';

    if (kIsWeb) {
      try {
        winH = web.window.innerHeight.toString();
        winW = web.window.innerWidth.toString();
        final vv = web.window.visualViewport;
        if (vv != null) {
          vvH = vv.height.toStringAsFixed(1);
          vvW = vv.width.toStringAsFixed(1);
          vvTop = vv.offsetTop.toStringAsFixed(1);
          vvLeft = vv.offsetLeft.toStringAsFixed(1);
          vvScale = vv.scale.toStringAsFixed(2);
          // Heuristic: keyboard height = layout viewport height − visual
          // viewport bottom. On iOS Safari the visualViewport shrinks when
          // the keyboard opens; offsetTop becomes nonzero if the user has
          // scrolled the page up to keep the input visible.
          final kb = web.window.innerHeight - vv.height - vv.offsetTop;
          calcKb = kb.toStringAsFixed(1);
        }
        // `documentElement.clientHeight` is the layout viewport. Useful to
        // compare against window.innerHeight (sometimes they diverge on iOS).
        docVisH = web.document.documentElement?.clientHeight.toString() ?? '?';
      } catch (e) {
        winH = 'err: $e';
      }
    }

    final lines = <(String, String, Color?)>[
      (
        'mq.size',
        '${mq.size.width.toStringAsFixed(0)} x ${mq.size.height.toStringAsFixed(0)}',
        null,
      ),
      (
        'mq.viewInsets.bottom',
        mq.viewInsets.bottom.toStringAsFixed(1),
        Colors.lightBlueAccent,
      ),
      ('mq.viewInsets.top', mq.viewInsets.top.toStringAsFixed(1), null),
      ('mq.viewPadding.bottom', mq.viewPadding.bottom.toStringAsFixed(1), null),
      ('mq.devicePixelRatio', mq.devicePixelRatio.toStringAsFixed(2), null),
      ('—', '—', null),
      ('window.innerWxH', '$winW x $winH', null),
      ('vv.WxH', '$vvW x $vvH', null),
      ('vv.offset L,T', '$vvLeft, $vvTop', null),
      ('vv.scale', vvScale, null),
      ('docEl.clientHeight', docVisH, null),
      ('—', '—', null),
      ('calc kbH = innerH − vvH − vvTop', calcKb, Colors.yellowAccent),
    ];

    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.yellow.withValues(alpha: 0.5)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'monospace',
            fontFamilyFallback: ['Courier', 'monospace'],
            height: 1.25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'KB DEBUG  ?debug=keyboard',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              for (final (label, value, color) in lines)
                if (label == '—')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.white24,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(color: color ?? Colors.white70),
                        ),
                      ),
                      Text(
                        value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: color ?? Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
