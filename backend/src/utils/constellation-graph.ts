import { connections } from "../db/schema/index.js";
import { db } from "../db/index.js";

/**
 * Find all post IDs in the same constellation (connected component)
 * as the given postId by traversing connections via BFS.
 */
export async function findConstellationPostIds(
  postId: string,
): Promise<Set<string>> {
  // Fetch all connections and BFS in memory (sufficient for MVP scale)
  const allConns = await db
    .select({
      sourceId: connections.sourceId,
      targetId: connections.targetId,
    })
    .from(connections);

  // Build adjacency list
  const adj = new Map<string, Set<string>>();
  for (const c of allConns) {
    if (!adj.has(c.sourceId)) adj.set(c.sourceId, new Set());
    if (!adj.has(c.targetId)) adj.set(c.targetId, new Set());
    adj.get(c.sourceId)!.add(c.targetId);
    adj.get(c.targetId)!.add(c.sourceId);
  }

  // BFS
  const visited = new Set<string>([postId]);
  const queue = [postId];

  while (queue.length > 0) {
    const current = queue.shift()!;
    for (const neighbor of adj.get(current) ?? []) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        queue.push(neighbor);
      }
    }
  }

  return visited;
}
