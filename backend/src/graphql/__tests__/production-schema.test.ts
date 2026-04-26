import { beforeAll, describe, expect, it } from "vitest";
import type { GraphQLObjectType, GraphQLSchema } from "graphql";

// Production schema is defined by importing only `types/index.js`. That file
// intentionally omits `import "./comment.js"` for Phase 0 (see Issue #221).
// Loading nothing else here mirrors what production builds: any feature that
// is not registered in `types/index.js` must not appear in the resulting
// GraphQL schema.
//
// IMPORTANT — singleton + isolation contract:
// pothos' `builder` is module-level singleton state, so any side-effect import
// of a type module would pollute these assertions. This file relies on
// vitest's `isolate: true` (default; see `backend/vitest.config.ts`) to keep
// each test file in its own module scope. The sibling `comment.test.ts`
// individually imports `../types/comment.js` to keep that resolver covered
// while disabled — that import does NOT leak here only because of isolation.
// If `vitest.config.ts` ever sets `isolate: false` or switches `pool` away
// from a worker-isolated pool, this test file becomes load-order-sensitive
// and must be rewritten (e.g., by spinning up a fresh builder per test, or by
// running it as a separate vitest project).
import { builder } from "../builder.js";
import "../types/index.js";

const EXCLUDED_MUTATIONS = [
  "createComment",
  "updateComment",
  "deleteComment",
] as const;

const EXCLUDED_QUERIES = ["comments"] as const;

// Object types and any input types that comment resolvers might introduce in
// future iterations. The input names here are speculative — current Phase 0
// code uses scalar args, but pinning them now means a future migration to
// `t.input({...})` style won't quietly leak Comment shapes through inputRef.
const EXCLUDED_TYPES = [
  "Comment",
  "CommentInput",
  "CreateCommentInput",
  "UpdateCommentInput",
] as const;

describe("Production schema hardening (#222)", () => {
  let schema: GraphQLSchema;

  beforeAll(() => {
    schema = builder.toSchema();
  });

  it("Mutation and Query root types are defined", () => {
    // Without these the per-field assertions below would pass vacuously
    // (optional chaining returns undefined when the root type is missing).
    expect(schema.getMutationType(), "Mutation root must exist").toBeDefined();
    expect(schema.getQueryType(), "Query root must exist").toBeDefined();
  });

  describe.each(EXCLUDED_MUTATIONS)("mutation %s", (name) => {
    it("does not expose in production schema", () => {
      expect(schema.getMutationType()!.getFields()[name]).toBeUndefined();
    });
  });

  describe.each(EXCLUDED_QUERIES)("query %s", (name) => {
    it("does not expose in production schema", () => {
      expect(schema.getQueryType()!.getFields()[name]).toBeUndefined();
    });
  });

  describe.each(EXCLUDED_TYPES)("type %s", (name) => {
    it("does not register in production schema", () => {
      expect(schema.getType(name)).toBeUndefined();
    });
  });

  it("Post type does not expose a comments field", () => {
    // comment.ts attaches `comments` to PostType via builder.objectFields(...),
    // so a leaked import would manifest as a new field on the existing Post
    // type rather than a brand-new type registration.
    const postType = schema.getType("Post") as GraphQLObjectType | undefined;
    expect(postType, "Post type must be registered").toBeDefined();
    expect(postType!.getFields()["comments"]).toBeUndefined();
  });
});
