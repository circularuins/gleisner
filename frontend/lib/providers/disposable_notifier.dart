import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin that tracks disposal state for Riverpod Notifiers.
///
/// Riverpod 3.x removed `mounted` from StateNotifier. This mixin provides
/// an equivalent `disposed` flag that is set via `ref.onDispose`.
///
/// Usage: call `initDisposable()` in `build()`, then check `disposed`
/// before setting state in async callbacks.
mixin DisposableNotifier<T> on Notifier<T> {
  bool _disposed = false;

  bool get disposed => _disposed;

  void initDisposable() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
  }
}
