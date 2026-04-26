import { describe, it, expect } from "vitest";
import type { GraphQLObjectType } from "graphql";

// Production schema is defined by importing only `types/index.js`. That file
// intentionally omits `import "./comment.js"` for Phase 0 (see Issue #221).
// Loading nothing else here mirrors what production builds: any feature that
// is not registered in `types/index.js` must not appear in the resulting
// GraphQL schema.
//
// pothos' `builder` is a module-level singleton, so any side-effect import of
// a type module would pollute these assertions. vitest runs each test file in
// its own module context (default `isolate: true`), so the comment.test.ts
// file's individual `import "../types/comment.js"` does not leak here.
import { builder } from "../builder.js";
import "../types/index.js";

describe("Production schema hardening", () => {
  const schema = builder.toSchema();

  it("does not expose createComment mutation", () => {
    expect(
      schema.getMutationType()?.getFields()["createComment"],
    ).toBeUndefined();
  });

  it("does not expose updateComment mutation", () => {
    expect(
      schema.getMutationType()?.getFields()["updateComment"],
    ).toBeUndefined();
  });

  it("does not expose deleteComment mutation", () => {
    expect(
      schema.getMutationType()?.getFields()["deleteComment"],
    ).toBeUndefined();
  });

  it("does not expose comments query", () => {
    expect(schema.getQueryType()?.getFields()["comments"]).toBeUndefined();
  });

  it("Post type does not have a comments field", () => {
    const postType = schema.getType("Post") as GraphQLObjectType | undefined;
    expect(postType, "Post type should be registered").toBeDefined();
    expect(postType!.getFields()["comments"]).toBeUndefined();
  });

  it("Comment type itself is not registered", () => {
    // Defence in depth: if Comment object type leaks into the schema,
    // some other field or input could end up wired to it.
    expect(schema.getType("Comment")).toBeUndefined();
  });
});
