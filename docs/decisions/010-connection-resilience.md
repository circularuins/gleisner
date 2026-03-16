# ADR 010: Connection Resilience — Group Integrity on Node Deletion

## Status

Accepted

## Context

ADR 008 introduced node deletion. A problem arises when a node in the middle of a connected group is deleted: the group could split into two disconnected subgroups, breaking the narrative thread. This is unacceptable — a group's continuity must survive individual node removals.

## Decision

### Two Connection Types

Connections are classified by origin, each with different internal behavior:

| Type | Created by | Internal model | Display model |
|------|-----------|----------------|---------------|
| **AI-detected** | System (audience correlation, thematic similarity) | Fully connected within the group | Only the immediate predecessor by timestamp |
| **User-explicit** | Artist during posting (Related Post field, ADR 007) | Point-to-point (target node only) | Direct link to the specified node |

### AI-Detected Connections: Group Model

When the system connects a new node to any member of an existing group:

1. **Storage**: The node is internally associated with **all** nodes in that group (full mesh within the group)
2. **Timeline visual**: Synapse lines are drawn only between each node and its **immediate predecessor by timestamp** within the group — a clean chain, not a web
3. **Detail view (Connected Posts)**: Shows only the immediate predecessor, maintaining the same chain metaphor
4. **On deletion**: When a middle node is removed, the nodes before and after it are still connected through the group's full mesh. The display chain simply skips the deleted node, connecting to the next available predecessor by timestamp

This ensures that **deleting any single node never splits a group**.

### User-Explicit Connections: Point-to-Point

When an artist manually links a post to a specific target during creation (via the Related Post picker in ADR 007):

1. **Storage**: A direct edge between the two nodes only
2. **Display**: A distinct synapse line between the two specific nodes
3. **On deletion**: If either node is deleted, this specific connection is removed. This is expected behavior — the artist made a deliberate link to a specific post, and that link's meaning is tied to both endpoints

### Visualization Distinction

To help users understand the difference:

- AI-detected group connections use the existing dashed synapse style (blended track colors)
- User-explicit connections use a solid synapse line, potentially with a subtle link icon or different stroke pattern (detail TBD)

## Consequences

- Group integrity is guaranteed regardless of node deletion — no orphaned subgroups
- The full-mesh internal model is invisible to users; they see a clean temporal chain
- Storage cost scales with group size (N nodes = N edges per node), but groups are expected to be small (typically < 20 nodes)
- User-explicit links are semantically distinct and behave predictably (delete either end → link gone)
- The two connection types can coexist on the same node (a node can be part of an AI group and also have explicit links to unrelated nodes)

## Related

- ADR 008 — Artist Mode & content management (node deletion)
- ADR 007 — Posting flow (Related Post linking)
- ADR 006 — Timeline visual design (synapse connections)
- Idea 006 — Related posts & thread view
