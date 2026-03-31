import { GraphQLError, GraphQLScalarType, Kind } from "graphql";
import type { ValueNode } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { analyticsEvents } from "../../db/schema/index.js";

const MAX_JSON_DEPTH = 10;

// JSON scalar for metadata — accepts any JSON value (depth-limited)
export function parseLiteralJSON(ast: ValueNode, depth = 0): unknown {
  if (depth > MAX_JSON_DEPTH) {
    throw new GraphQLError(
      `JSON nesting exceeds maximum depth of ${MAX_JSON_DEPTH}`,
    );
  }
  if (ast.kind === Kind.STRING) return ast.value;
  if (ast.kind === Kind.INT) return parseInt(ast.value, 10);
  if (ast.kind === Kind.FLOAT) return parseFloat(ast.value);
  if (ast.kind === Kind.BOOLEAN) return ast.value;
  if (ast.kind === Kind.NULL) return null;
  if (ast.kind === Kind.OBJECT) {
    const obj: Record<string, unknown> = {};
    for (const field of ast.fields) {
      obj[field.name.value] = parseLiteralJSON(field.value, depth + 1);
    }
    return obj;
  }
  if (ast.kind === Kind.LIST) {
    return ast.values.map((v) => parseLiteralJSON(v, depth + 1));
  }
  return null;
}

const GraphQLJSON = new GraphQLScalarType({
  name: "JSON",
  description: "Arbitrary JSON value",
  serialize: (value) => value,
  parseValue: (value) => value,
  parseLiteral: (ast) => parseLiteralJSON(ast),
});

/**
 * Allowed analytics event types. Each corresponds to a user interaction
 * we want to track for Phase 0 UI/UX optimization.
 *
 * To add a new type: append here and add corresponding frontend trackEvent
 * call. Keep the list small — analytics noise dilutes signal.
 */
export const ALLOWED_EVENT_TYPES = [
  "page_view", // Screen navigation (includes page path in metadata)
  "post_view", // Post detail sheet opened
  "reaction_tap", // Reaction added/removed
  "connection_click", // Connection pill tapped in detail sheet
  "scroll_depth", // Periodic scroll position snapshots
  "session_start", // App opened / page loaded
  "signup_start", // Signup form opened
  "signup_complete", // Signup succeeded
] as const;

// Register as inputType since Pothos doesn't have addScalarType for arbitrary names.
// We use builder.scalarType to register it properly.
builder.scalarType("JSON", {
  serialize: GraphQLJSON.serialize,
  parseValue: GraphQLJSON.parseValue,
  parseLiteral: GraphQLJSON.parseLiteral,
});

builder.mutationFields((t) => ({
  trackEvent: t.field({
    type: "Boolean",
    args: {
      eventType: t.arg.string({ required: true }),
      sessionId: t.arg.string({ required: true }),
      metadata: t.arg({ type: "JSON" }),
    },
    resolve: async (_parent, args, ctx) => {
      // Validate event type
      if (
        !ALLOWED_EVENT_TYPES.includes(
          args.eventType as (typeof ALLOWED_EVENT_TYPES)[number],
        )
      ) {
        throw new GraphQLError(
          `Invalid event type. Allowed: ${ALLOWED_EVENT_TYPES.join(", ")}`,
        );
      }

      // Validate sessionId length
      if (args.sessionId.length > 64 || args.sessionId.length === 0) {
        throw new GraphQLError("sessionId must be between 1 and 64 characters");
      }

      // Validate metadata size (4KB byte limit to prevent DoS)
      if (args.metadata != null) {
        const metadataStr = JSON.stringify(args.metadata);
        if (Buffer.byteLength(metadataStr, "utf-8") > 4096) {
          throw new GraphQLError("metadata must be 4096 bytes or less");
        }
      }

      await db.insert(analyticsEvents).values({
        eventType: args.eventType,
        userId: ctx.authUser?.userId ?? null,
        sessionId: args.sessionId,
        metadata: args.metadata ?? null,
      });

      return true;
    },
  }),
}));
