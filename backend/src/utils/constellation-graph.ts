import { connections } from "../db/schema/index.js";
import { db } from "../db/index.js";

/**
 * Build adjacency list from all connections in the database.
 */
async function buildAdjacencyList(): Promise<Map<string, Set<string>>> {
  const allConns = await db
    .select({
      sourceId: connections.sourceId,
      targetId: connections.targetId,
    })
    .from(connections);

  const adj = new Map<string, Set<string>>();
  for (const c of allConns) {
    if (!adj.has(c.sourceId)) adj.set(c.sourceId, new Set());
    if (!adj.has(c.targetId)) adj.set(c.targetId, new Set());
    adj.get(c.sourceId)!.add(c.targetId);
    adj.get(c.targetId)!.add(c.sourceId);
  }
  return adj;
}

/**
 * BFS from a starting node using a pre-built adjacency list.
 */
function bfs(startId: string, adj: Map<string, Set<string>>): Set<string> {
  const visited = new Set<string>([startId]);
  const queue = [startId];

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

/**
 * Find all post IDs in the same constellation (connected component)
 * as the given postId by traversing connections via BFS.
 */
export async function findConstellationPostIds(
  postId: string,
): Promise<Set<string>> {
  const adj = await buildAdjacencyList();
  return bfs(postId, adj);
}

/**
 * For a set of post IDs, compute which constellation (connected component)
 * each belongs to. Returns a Map from postId to the Set of all post IDs
 * in its connected component.
 *
 * Fetches connections once and runs BFS for each component — O(V + E) total.
 */
export async function findAllConstellations(
  postIds: string[],
): Promise<Map<string, Set<string>>> {
  const adj = await buildAdjacencyList();
  const result = new Map<string, Set<string>>();
  const assigned = new Set<string>();

  for (const pid of postIds) {
    if (assigned.has(pid)) {
      // Already computed as part of another node's BFS
      continue;
    }
    const component = bfs(pid, adj);
    for (const memberId of component) {
      result.set(memberId, component);
      assigned.add(memberId);
    }
  }

  // Ensure all requested postIds have an entry (even if no connections)
  for (const pid of postIds) {
    if (!result.has(pid)) {
      const single = new Set([pid]);
      result.set(pid, single);
    }
  }

  return result;
}
