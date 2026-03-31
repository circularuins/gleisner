import { describe, it, expect, beforeAll, beforeEach, afterAll } from "vitest";
import { sql } from "drizzle-orm";
import {
  getTestApp,
  gql,
  db,
  signupAndGetToken,
  closeTestDb,
} from "./helpers.js";
import { parseLiteralJSON, ALLOWED_EVENT_TYPES } from "../types/analytics.js";
import { Kind, type ValueNode } from "graphql";

const TRACK_EVENT_MUTATION = `
  mutation TrackEvent($eventType: String!, $sessionId: String!, $metadata: JSON) {
    trackEvent(eventType: $eventType, sessionId: $sessionId, metadata: $metadata)
  }
`;

describe("Analytics", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestDb();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
    await db.execute(sql`TRUNCATE analytics_events`);
  });

  describe("trackEvent mutation", () => {
    it("records an event without authentication", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "page_view",
        sessionId: "sess-abc-123",
        metadata: { page: "/timeline" },
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.trackEvent).toBe(true);

      // Verify in DB
      const rows = await db.execute(
        sql`SELECT event_type, session_id, user_id, metadata FROM analytics_events`,
      );
      expect(rows.length).toBe(1);
      expect(rows[0].event_type).toBe("page_view");
      expect(rows[0].session_id).toBe("sess-abc-123");
      expect(rows[0].user_id).toBeNull();
      expect(rows[0].metadata).toEqual({ page: "/timeline" });
    });

    it("records userId when authenticated", async () => {
      const token = await signupAndGetToken(app, "an1@test.com", "anuser1");

      const result = await gql(
        app,
        TRACK_EVENT_MUTATION,
        {
          eventType: "post_view",
          sessionId: "sess-auth-456",
          metadata: { postId: "p1" },
        },
        token,
      );

      expect(result.errors).toBeUndefined();

      const rows = await db.execute(
        sql`SELECT user_id FROM analytics_events WHERE session_id = 'sess-auth-456'`,
      );
      expect(rows.length).toBe(1);
      expect(rows[0].user_id).not.toBeNull();
    });

    it("rejects invalid event type", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "invalid_event",
        sessionId: "sess-bad",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Invalid event type");
    });

    it("rejects empty sessionId", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "page_view",
        sessionId: "",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("sessionId");
    });

    it("accepts null metadata", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "session_start",
        sessionId: "sess-no-meta",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.trackEvent).toBe(true);
    });

    it("accepts all valid event types", async () => {
      for (const eventType of ALLOWED_EVENT_TYPES) {
        const result = await gql(app, TRACK_EVENT_MUTATION, {
          eventType,
          sessionId: `sess-${eventType}`,
        });
        expect(result.errors).toBeUndefined();
      }

      const rows = await db.execute(
        sql`SELECT count(*) as cnt FROM analytics_events`,
      );
      expect(Number(rows[0].cnt)).toBe(ALLOWED_EVENT_TYPES.length);
    });

    it("rejects sessionId exceeding 64 characters", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "page_view",
        sessionId: "a".repeat(65),
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("sessionId");
    });

    it("rejects metadata exceeding 4KB", async () => {
      const result = await gql(app, TRACK_EVENT_MUTATION, {
        eventType: "page_view",
        sessionId: "sess-big-meta",
        metadata: { payload: "x".repeat(5000) },
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("4096 bytes");
    });
  });

  describe("parseLiteralJSON", () => {
    it("parses string literal", () => {
      expect(parseLiteralJSON({ kind: Kind.STRING, value: "hello" })).toBe(
        "hello",
      );
    });

    it("parses int literal", () => {
      expect(parseLiteralJSON({ kind: Kind.INT, value: "42" })).toBe(42);
    });

    it("parses float literal", () => {
      expect(parseLiteralJSON({ kind: Kind.FLOAT, value: "3.14" })).toBe(3.14);
    });

    it("parses boolean literal", () => {
      expect(parseLiteralJSON({ kind: Kind.BOOLEAN, value: true })).toBe(true);
    });

    it("parses null literal", () => {
      expect(parseLiteralJSON({ kind: Kind.NULL })).toBeNull();
    });

    it("parses object literal", () => {
      const result = parseLiteralJSON({
        kind: Kind.OBJECT,
        fields: [
          {
            kind: Kind.OBJECT_FIELD,
            name: { kind: Kind.NAME, value: "key" },
            value: { kind: Kind.STRING, value: "val" },
          },
        ],
      });
      expect(result).toEqual({ key: "val" });
    });

    it("parses list literal", () => {
      const result = parseLiteralJSON({
        kind: Kind.LIST,
        values: [
          { kind: Kind.INT, value: "1" },
          { kind: Kind.INT, value: "2" },
        ],
      });
      expect(result).toEqual([1, 2]);
    });

    it("returns null for unknown AST kind (e.g. ENUM)", () => {
      expect(
        parseLiteralJSON({ kind: Kind.ENUM, value: "SOME_ENUM" }),
      ).toBeNull();
    });

    it("throws on nesting exceeding max depth", () => {
      // Build a deeply nested object: { a: { a: { a: ... } } }
      let ast = { kind: Kind.STRING, value: "leaf" } as ValueNode;
      for (let i = 0; i < 12; i++) {
        ast = {
          kind: Kind.OBJECT,
          fields: [
            {
              kind: Kind.OBJECT_FIELD as const,
              name: { kind: Kind.NAME as const, value: "a" },
              value: ast,
            },
          ],
        } as ValueNode;
      }
      expect(() => parseLiteralJSON(ast)).toThrow("maximum depth");
    });
  });
});
