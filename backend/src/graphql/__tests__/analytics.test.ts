import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { sql } from "drizzle-orm";
import {
  getTestApp,
  gql,
  db,
  signupAndGetToken,
  closeTestDb,
} from "./helpers.js";

const TRACK_EVENT_MUTATION = `
  mutation TrackEvent($eventType: String!, $sessionId: String!, $metadata: JSON) {
    trackEvent(eventType: $eventType, sessionId: $sessionId, metadata: $metadata)
  }
`;

describe("Analytics", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
    return closeTestDb;
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
      const types = [
        "page_view",
        "post_view",
        "reaction_tap",
        "connection_click",
        "scroll_depth",
        "session_start",
        "signup_start",
        "signup_complete",
      ];

      for (const eventType of types) {
        const result = await gql(app, TRACK_EVENT_MUTATION, {
          eventType,
          sessionId: `sess-${eventType}`,
        });
        expect(result.errors).toBeUndefined();
      }

      const rows = await db.execute(
        sql`SELECT count(*) as cnt FROM analytics_events`,
      );
      expect(Number(rows[0].cnt)).toBe(types.length);
    });
  });
});
