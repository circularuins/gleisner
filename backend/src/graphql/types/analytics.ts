import { GraphQLError, Kind } from "graphql";
import type { ValueNode } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { analyticsEvents } from "../../db/schema/index.js";

export const MAX_JSON_DEPTH = 10;

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

export const MAX_METADATA_BYTES = 4096;

/** Validate JSON depth recursively (works on parseValue input — plain JS objects). */
export function validateJsonDepth(value: unknown, depth = 0): void {
  if (depth > MAX_JSON_DEPTH) {
    throw new GraphQLError(
      `JSON nesting exceeds maximum depth of ${MAX_JSON_DEPTH}`,
    );
  }
  if (Array.isArray(value)) {
    for (const item of value) validateJsonDepth(item, depth + 1);
  } else if (value !== null && typeof value === "object") {
    for (const v of Object.values(value)) validateJsonDepth(v, depth + 1);
  }
}

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

builder.scalarType("JSON", {
  serialize: (value) => value,
  parseValue: (value) => {
    validateJsonDepth(value);
    if (value != null) {
      const bytes = Buffer.byteLength(JSON.stringify(value), "utf-8");
      if (bytes > MAX_METADATA_BYTES) {
        throw new GraphQLError(
          `metadata must be ${MAX_METADATA_BYTES} bytes or less`,
        );
      }
    }
    return value;
  },
  parseLiteral: (ast) => parseLiteralJSON(ast),
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

      // metadata depth + size validation is handled by the JSON scalar's parseValue

      try {
        await db.insert(analyticsEvents).values({
          eventType: args.eventType,
          userId: ctx.authUser?.userId ?? null,
          sessionId: args.sessionId,
          metadata: args.metadata ?? null,
        });
      } catch {
        throw new GraphQLError("Failed to record analytics event");
      }

      return true;
    },
  }),
}));
