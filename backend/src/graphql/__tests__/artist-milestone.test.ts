import { describe, it, expect, beforeAll, beforeEach, afterAll } from "vitest";
import { sql } from "drizzle-orm";
import {
  getTestApp,
  gql,
  db,
  signupAndGetToken,
  signupAndRegisterArtist,
  closeTestDb,
} from "./helpers.js";

const CREATE_MILESTONE = `
  mutation CreateMilestone($category: MilestoneCategory!, $title: String!, $description: String, $date: String!, $position: Int) {
    createArtistMilestone(category: $category, title: $title, description: $description, date: $date, position: $position) {
      id category title description date position createdAt
    }
  }
`;

const UPDATE_MILESTONE = `
  mutation UpdateMilestone($id: String!, $category: MilestoneCategory, $title: String, $description: String, $date: String, $position: Int) {
    updateArtistMilestone(id: $id, category: $category, title: $title, description: $description, date: $date, position: $position) {
      id category title description date position
    }
  }
`;

const DELETE_MILESTONE = `
  mutation DeleteMilestone($id: String!) {
    deleteArtistMilestone(id: $id) {
      id
    }
  }
`;

const ARTIST_WITH_MILESTONES = `
  query Artist($username: String!) {
    artist(username: $username) {
      id artistUsername
      milestones {
        id category title description date position
      }
    }
  }
`;

const TOGGLE_MILESTONE_REACTION = `
  mutation ToggleMilestoneReaction($milestoneId: String!, $emoji: String!) {
    toggleMilestoneReaction(milestoneId: $milestoneId, emoji: $emoji) {
      id emoji createdAt
    }
  }
`;

const ARTIST_MILESTONE_REACTIONS = `
  query Artist($username: String!) {
    artist(username: $username) {
      milestones {
        id reactionCounts { emoji count }
      }
    }
  }
`;

describe("Artist Milestones", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestDb();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createArtistMilestone", () => {
    it("creates a milestone", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "m1@test.com",
        "muser1",
        "martist1",
      );

      const result = await gql(
        app,
        CREATE_MILESTONE,
        {
          category: "award",
          title: "Best New Artist",
          description: "Awarded at ceremony",
          date: "2025-06-15",
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const m = result.data!.createArtistMilestone as Record<string, unknown>;
      expect(m.category).toBe("award");
      expect(m.title).toBe("Best New Artist");
      expect(m.description).toBe("Awarded at ceremony");
      expect(m.date).toBe("2025-06-15");
      expect(m.position).toBe(0);
    });

    it("rejects without authentication", async () => {
      const result = await gql(app, CREATE_MILESTONE, {
        category: "release",
        title: "First EP",
        date: "2024-01-01",
      });
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects without artist profile", async () => {
      const token = await signupAndGetToken(app, "m2@test.com", "muser2");
      const result = await gql(
        app,
        CREATE_MILESTONE,
        { category: "event", title: "Solo Show", date: "2024-03-01" },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Artist profile required");
    });

    it("rejects empty title", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "m3@test.com",
        "muser3",
        "martist3",
      );
      const result = await gql(
        app,
        CREATE_MILESTONE,
        { category: "award", title: "   ", date: "2024-01-01" },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Title");
    });

    it("rejects invalid date format", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "m4@test.com",
        "muser4",
        "martist4",
      );
      const result = await gql(
        app,
        CREATE_MILESTONE,
        { category: "release", title: "Album", date: "2024/01/01" },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("YYYY-MM-DD");
    });

    it("rejects non-existent date", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "m5@test.com",
        "muser5",
        "martist5",
      );
      const result = await gql(
        app,
        CREATE_MILESTONE,
        { category: "event", title: "Show", date: "2025-13-45" },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("valid date");
    });
  });

  describe("updateArtistMilestone", () => {
    it("updates a milestone", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "u1@test.com",
        "uuser1",
        "uartist1",
      );
      const created = await gql(
        app,
        CREATE_MILESTONE,
        { category: "event", title: "First Gig", date: "2023-08-10" },
        token,
      );
      const id = (created.data!.createArtistMilestone as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_MILESTONE,
        { id, title: "Updated Gig", category: "event" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const m = result.data!.updateArtistMilestone as Record<string, unknown>;
      expect(m.title).toBe("Updated Gig");
    });

    it("rejects update of another artist's milestone", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "u2a@test.com",
        "uuser2a",
        "uartist2a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "u2b@test.com",
        "uuser2b",
        "uartist2b",
      );

      const created = await gql(
        app,
        CREATE_MILESTONE,
        { category: "award", title: "My Award", date: "2024-01-01" },
        token1,
      );
      const id = (created.data!.createArtistMilestone as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_MILESTONE,
        { id, title: "Stolen" },
        token2,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Milestone not found");
    });
  });

  describe("deleteArtistMilestone", () => {
    it("deletes own milestone", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "d1@test.com",
        "duser1",
        "dartist1",
      );
      const created = await gql(
        app,
        CREATE_MILESTONE,
        { category: "education", title: "Music School", date: "2020-04-01" },
        token,
      );
      const id = (created.data!.createArtistMilestone as { id: string }).id;

      const result = await gql(app, DELETE_MILESTONE, { id }, token);
      expect(result.errors).toBeUndefined();
    });
  });

  // Milestone reactions exercise the same `validateEmoji` + ON CONFLICT
  // refactor as `toggleReaction` (see `reaction.test.ts`). Until this PR
  // there were NO integration tests for `toggleMilestoneReaction` at all,
  // so this block also serves as basic-behavior coverage.
  describe("toggleMilestoneReaction", () => {
    async function createMilestone(
      app: Awaited<ReturnType<typeof getTestApp>>,
      token: string,
    ): Promise<string> {
      const result = await gql(
        app,
        CREATE_MILESTONE,
        {
          category: "release",
          title: "Debut Single",
          date: "2024-04-01",
        },
        token,
      );
      return (result.data!.createArtistMilestone as { id: string }).id;
    }

    it("toggles a reaction on, then off", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr1@test.com",
        "mruser1",
        "mrartist1",
      );
      const milestoneId = await createMilestone(app, token);

      const onResult = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: "🔥" },
        token,
      );
      expect(onResult.errors).toBeUndefined();
      const reaction = onResult.data!.toggleMilestoneReaction as Record<
        string,
        unknown
      >;
      expect(reaction.emoji).toBe("🔥");

      const offResult = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: "🔥" },
        token,
      );
      expect(offResult.errors).toBeUndefined();
      expect(offResult.data!.toggleMilestoneReaction).toBeNull();
    });

    it("accepts a 64-character emoji string (maxlen boundary)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr2@test.com",
        "mruser2",
        "mrartist2",
      );
      const milestoneId = await createMilestone(app, token);
      const value = "a".repeat(64);

      const result = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: value },
        token,
      );
      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleMilestoneReaction as Record<
        string,
        unknown
      >;
      expect(reaction.emoji).toBe(value);
    });

    it("rejects an emoji string longer than 64 characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr3@test.com",
        "mruser3",
        "mrartist3",
      );
      const milestoneId = await createMilestone(app, token);

      const result = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: "a".repeat(65) },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("64 characters or less");
    });

    it("accepts a ZWJ family emoji (👨‍👩‍👧‍👦)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr4@test.com",
        "mruser4",
        "mrartist4",
      );
      const milestoneId = await createMilestone(app, token);
      const family = "👨‍👩‍👧‍👦";

      const result = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: family },
        token,
      );
      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleMilestoneReaction as Record<
        string,
        unknown
      >;
      expect(reaction.emoji).toBe(family);
    });

    it("rejects emoji containing control or bidi characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr5@test.com",
        "mruser5",
        "mrartist5",
      );
      const milestoneId = await createMilestone(app, token);

      const result = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId, emoji: "​🔥" }, // ZWSP
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Emoji contains disallowed characters",
      );
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, TOGGLE_MILESTONE_REACTION, {
        milestoneId: "00000000-0000-0000-0000-000000000000",
        emoji: "🔥",
      });
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects malformed milestone id (validateUUID guard)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "mr6@test.com",
        "mruser6",
        "mrartist6",
      );

      const result = await gql(
        app,
        TOGGLE_MILESTONE_REACTION,
        { milestoneId: "not-a-uuid", emoji: "🔥" },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Invalid milestone id");
    });

    it("is idempotent under concurrent toggle requests for the same emoji", async () => {
      // ON CONFLICT DO NOTHING regression guard. Without it the second
      // INSERT in a parallel pair would surface the unique-constraint
      // violation as a generic 500.
      const token = await signupAndRegisterArtist(
        app,
        "mr7@test.com",
        "mruser7",
        "mrartist7",
      );
      const milestoneId = await createMilestone(app, token);

      const results = await Promise.all([
        gql(
          app,
          TOGGLE_MILESTONE_REACTION,
          { milestoneId, emoji: "🚀" },
          token,
        ),
        gql(
          app,
          TOGGLE_MILESTONE_REACTION,
          { milestoneId, emoji: "🚀" },
          token,
        ),
      ]);
      for (const r of results) {
        expect(r.errors).toBeUndefined();
      }

      // Final state must be either 0 (both toggled — net cancel) or 1
      // (one INSERT survived; the other is a no-op via ON CONFLICT) —
      // never an error.
      const finalQuery = await gql(
        app,
        ARTIST_MILESTONE_REACTIONS,
        { username: "mrartist7" },
        token,
      );
      const milestones = (
        finalQuery.data!.artist as {
          milestones: Array<{
            id: string;
            reactionCounts: Array<{ emoji: string; count: number }>;
          }>;
        }
      ).milestones;
      const target = milestones.find((m) => m.id === milestoneId)!;
      const rocket = target.reactionCounts.find((c) => c.emoji === "🚀");
      expect([undefined, { emoji: "🚀", count: 1 }]).toContainEqual(
        rocket ?? undefined,
      );
    });
  });

  describe("artist.milestones field", () => {
    it("returns milestones sorted by date descending", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "q1@test.com",
        "quser1",
        "qartist1",
      );

      await gql(
        app,
        CREATE_MILESTONE,
        { category: "release", title: "First Album", date: "2020-01-01" },
        token,
      );
      await gql(
        app,
        CREATE_MILESTONE,
        { category: "award", title: "Grammy", date: "2023-02-05" },
        token,
      );
      await gql(
        app,
        CREATE_MILESTONE,
        { category: "event", title: "Solo Exhibition", date: "2021-06-15" },
        token,
      );

      const result = await gql(app, ARTIST_WITH_MILESTONES, {
        username: "qartist1",
      });

      expect(result.errors).toBeUndefined();
      const artist = result.data!.artist as {
        milestones: Array<{ title: string; date: string }>;
      };
      expect(artist.milestones).toHaveLength(3);
      // Newest first
      expect(artist.milestones[0].title).toBe("Grammy");
      expect(artist.milestones[1].title).toBe("Solo Exhibition");
      expect(artist.milestones[2].title).toBe("First Album");
    });
  });
});
