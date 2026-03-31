import { GraphQLError, GraphQLScalarType, Kind } from "graphql";
import type { ValueNode } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { analyticsEvents } from "../../db/schema/index.js";

// JSON scalar for metadata — accepts any JSON value
function parseLiteralJSON(ast: ValueNode): unknown {
  if (ast.kind === Kind.STRING) return ast.value;
  if (ast.kind === Kind.INT) return parseInt(ast.value, 10);
  if (ast.kind === Kind.FLOAT) return parseFloat(ast.value);
  if (ast.kind === Kind.BOOLEAN) return ast.value;
  if (ast.kind === Kind.NULL) return null;
  if (ast.kind === Kind.OBJECT) {
    const obj: Record<string, unknown> = {};
    for (const field of ast.fields) {
      obj[field.name.value] = parseLiteralJSON(field.value);
    }
    return obj;
  }
  if (ast.kind === Kind.LIST) {
    return ast.values.map((v) => parseLiteralJSON(v));
  }
  return null;
}

const GraphQLJSON = new GraphQLScalarType({
  name: "JSON",
  description: "Arbitrary JSON value",
  serialize: (value) => value,
  parseValue: (value) => value,
  parseLiteral: parseLiteralJSON,
});

const ALLOWED_EVENT_TYPES = [
  "page_view",
  "post_view",
  "reaction_tap",
  "connection_click",
  "scroll_depth",
  "session_start",
  "signup_start",
  "signup_complete",
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
