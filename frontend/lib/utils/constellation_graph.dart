import 'dart:collection';

import '../models/post.dart';

/// Find all post IDs in the same constellation (connected component)
/// as [postId] by traversing outgoing and incoming connections via BFS.
///
/// Returns a set containing at least [postId] itself.
Set<String> findConstellation(String postId, List<Post> allPosts) {
  // Build adjacency list
  final adj = <String, Set<String>>{};
  for (final p in allPosts) {
    for (final c in p.outgoingConnections) {
      adj.putIfAbsent(c.sourceId, () => {}).add(c.targetId);
      adj.putIfAbsent(c.targetId, () => {}).add(c.sourceId);
    }
    for (final c in p.incomingConnections) {
      adj.putIfAbsent(c.sourceId, () => {}).add(c.targetId);
      adj.putIfAbsent(c.targetId, () => {}).add(c.sourceId);
    }
  }

  // BFS from postId
  final visited = <String>{postId};
  final queue = Queue<String>()..add(postId);

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final neighbor in adj[current] ?? <String>{}) {
      if (visited.add(neighbor)) {
        queue.add(neighbor);
      }
    }
  }

  return visited;
}
