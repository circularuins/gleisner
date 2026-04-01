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
