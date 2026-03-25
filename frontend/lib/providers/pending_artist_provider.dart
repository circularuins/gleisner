import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the artistUsername to auto-switch to when Timeline tab activates.
/// Set before navigating to /timeline, cleared after consumption.
class PendingArtistNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String username) => state = username;
  void clear() => state = null;
}

final pendingArtistProvider =
    NotifierProvider<PendingArtistNotifier, String?>(PendingArtistNotifier.new);
