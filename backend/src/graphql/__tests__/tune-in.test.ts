import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import "dotenv/config";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { sql } from "drizzle-orm";
import { Hono } from "hono";
import { createYoga } from "graphql-yoga";
import { initJwtKeys } from "../../auth/jwt.js";
import { authMiddleware, type AuthUser } from "../../auth/middleware.js";

import { builder } from "../builder.js";
import "../types/index.js";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL)
  throw new Error("DATABASE_URL is required for integration tests");

const client = postgres(DATABASE_URL);
const db = drizzle(client);

function createTestApp() {
  const schema = builder.toSchema();
  const yoga = createYoga<{ authUser?: AuthUser }>({
    schema,
    maskedErrors: false,
  });

  const app = new Hono<{ Variables: { authUser?: AuthUser } }>();
  app.use(authMiddleware);
  app.on(["GET", "POST"], "/graphql", async (c) => {
    const authUser = c.get("authUser");
    const response = await yoga.handleRequest(c.req.raw, { authUser });
    return response;
  });
  return app;
}

async function gql(
  app: ReturnType<typeof createTestApp>,
  query: string,
  variables?: Record<string, unknown>,
  token?: string,
) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await app.request("/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  });
  return res.json() as Promise<{
    data?: Record<string, unknown>;
    errors?: Array<{ message: string }>;
  }>;
}

const SIGNUP_MUTATION = `
  mutation Signup($email: String!, $password: String!, $username: String!, $birthYearMonth: String!) {
    signup(email: $email, password: $password, username: $username, birthYearMonth: $birthYearMonth) {
      token
      user { id }
    }
  }
`;

const REGISTER_ARTIST_MUTATION = `
  mutation RegisterArtist($artistUsername: String!, $displayName: String!) {
    registerArtist(artistUsername: $artistUsername, displayName: $displayName) {
      id artistUsername
    }
  }
`;

const ARTIST_QUERY = `
  query Artist($username: String!) {
    artist(username: $username) {
      id tunedInCount
    }
  }
`;

const ARTIST_WITH_TUNE_INS_QUERY = `
  query ArtistWithTuneIns($username: String!) {
    artist(username: $username) {
      id
      tuneIns { user { id username } }
    }
  }
`;

const TOGGLE_TUNE_IN_MUTATION = `
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) {
      createdAt
      user { id username }
      artist { id artistUsername }
    }
  }
`;

const TUNE_INS_QUERY = `
  query TuneIns($artistId: String!) {
    tuneIns(artistId: $artistId) {
      user { id username }
    }
  }
`;

const MY_TUNE_INS_QUERY = `
  query MyTuneIns {
    myTuneIns {
      createdAt
      lastPostActivityAt
      artist { id artistUsername }
    }
  }
`;

const CREATE_TRACK_MUTATION = `
  mutation CreateTrack($name: String!, $color: String!) {
    createTrack(name: $name, color: $color) { id }
  }
`;

const CREATE_POST_MUTATION = `
  mutation CreatePost($trackId: String!, $mediaType: MediaType!, $title: String, $visibility: String) {
    createPost(trackId: $trackId, mediaType: $mediaType, title: $title, visibility: $visibility) {
      id
    }
  }
`;

async function signupAndGetToken(
  app: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
) {
  const result = await gql(app, SIGNUP_MUTATION, {
    email,
    password: "password123",
    username,
    birthYearMonth: "1990-01",
  });
  return (result.data!.signup as { token: string }).token;
}

async function signupAndRegisterArtist(
  app: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
  artistUsername: string,
) {
  const token = await signupAndGetToken(app, email, username);
  const result = await gql(
    app,
    REGISTER_ARTIST_MUTATION,
    { artistUsername, displayName: `Artist ${artistUsername}` },
    token,
  );
  const artistId = (result.data!.registerArtist as { id: string }).id;
  return { token, artistId };
}

/**
 * Create a post by the artist owner and (optionally) backdate its
 * `updated_at` to a specific time so we can test the avatar rail sort
 * deterministically.
 */
async function createPostWithUpdatedAt(
  app: ReturnType<typeof createTestApp>,
  ownerToken: string,
  options: {
    visibility?: "public" | "draft";
    updatedAt?: Date;
    title?: string;
  } = {},
) {
  const trackResult = await gql(
    app,
    CREATE_TRACK_MUTATION,
    { name: `track_${crypto.randomUUID().slice(0, 8)}`, color: "#FF0000" },
    ownerToken,
  );
  const trackId = (trackResult.data!.createTrack as { id: string }).id;

  const postResult = await gql(
    app,
    CREATE_POST_MUTATION,
    {
      trackId,
      mediaType: "thought",
      title: options.title ?? null,
      visibility: options.visibility ?? "public",
    },
    ownerToken,
  );
  const postId = (postResult.data!.createPost as { id: string }).id;

  if (options.updatedAt) {
    // Direct UPDATE — createPost only sets updated_at to defaultNow().
    // Tests need explicit timestamps to assert sort order without flakiness.
    await db.execute(
      sql`UPDATE posts SET updated_at = ${options.updatedAt.toISOString()}::timestamptz WHERE id = ${postId}`,
    );
  }
  return postId;
}

describe("TuneIn GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("toggleTuneIn", () => {
    it("tunes in to an artist (toggle on)", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "t1a@example.com",
        "tuser1a",
        "tartist1a",
      );
      const userToken = await signupAndGetToken(
        app,
        "t1b@example.com",
        "tuser1b",
      );

      const result = await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId },
        userToken,
      );

      expect(result.errors).toBeUndefined();
      const tuneIn = result.data!.toggleTuneIn as Record<string, unknown>;
      expect(tuneIn.createdAt).toBeDefined();
      expect((tuneIn.user as Record<string, unknown>).username).toBe("tuser1b");
      expect((tuneIn.artist as Record<string, unknown>).artistUsername).toBe(
        "tartist1a",
      );

      // Verify tunedInCount incremented
      const artistResult = await gql(app, ARTIST_QUERY, {
        username: "tartist1a",
      });
      const artist = artistResult.data!.artist as Record<string, unknown>;
      expect(artist.tunedInCount).toBe(1);
    });

    it("tunes out when toggled again (toggle off)", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "t2a@example.com",
        "tuser2a",
        "tartist2a",
      );
      const userToken = await signupAndGetToken(
        app,
        "t2b@example.com",
        "tuser2b",
      );

      await gql(app, TOGGLE_TUNE_IN_MUTATION, { artistId }, userToken);
      const result = await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId },
        userToken,
      );

      expect(result.errors).toBeUndefined();
      expect(result.data!.toggleTuneIn).toBeNull();

      // Verify tunedInCount decremented back to 0
      const artistResult = await gql(app, ARTIST_QUERY, {
        username: "tartist2a",
      });
      const artist = artistResult.data!.artist as Record<string, unknown>;
      expect(artist.tunedInCount).toBe(0);
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, TOGGLE_TUNE_IN_MUTATION, {
        artistId: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("tuneIns query (artist followers)", () => {
    it("returns followers when called by the artist owner", async () => {
      const { token: ownerToken, artistId } = await signupAndRegisterArtist(
        app,
        "q1a@example.com",
        "quser1a",
        "qartist1a",
      );
      const followerToken = await signupAndGetToken(
        app,
        "q1b@example.com",
        "quser1b",
      );

      await gql(app, TOGGLE_TUNE_IN_MUTATION, { artistId }, followerToken);

      const result = await gql(app, TUNE_INS_QUERY, { artistId }, ownerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.tuneIns as Array<Record<string, unknown>>;
      expect(tuneIns).toHaveLength(1);
      expect((tuneIns[0].user as Record<string, unknown>).username).toBe(
        "quser1b",
      );
    });

    it("returns empty array for artist with no tune-ins (owner)", async () => {
      const { token: ownerToken, artistId } = await signupAndRegisterArtist(
        app,
        "q2@example.com",
        "quser2",
        "qartist2",
      );

      const result = await gql(app, TUNE_INS_QUERY, { artistId }, ownerToken);

      expect(result.errors).toBeUndefined();
      expect(result.data!.tuneIns).toEqual([]);
    });

    it("rejects unauthenticated requests", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "q3@example.com",
        "quser3",
        "qartist3",
      );

      const result = await gql(app, TUNE_INS_QUERY, { artistId });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects non-owner callers (Forbidden)", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "q4a@example.com",
        "quser4a",
        "qartist4a",
      );
      const otherToken = await signupAndGetToken(
        app,
        "q4b@example.com",
        "quser4b",
      );

      const result = await gql(app, TUNE_INS_QUERY, { artistId }, otherToken);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Forbidden");
    });
  });

  describe("Artist.tuneIns field (artist followers via Artist query)", () => {
    it("returns followers when called by the artist owner", async () => {
      const { token: ownerToken, artistId } = await signupAndRegisterArtist(
        app,
        "a1a@example.com",
        "auser1a",
        "aartist1a",
      );
      const followerToken = await signupAndGetToken(
        app,
        "a1b@example.com",
        "auser1b",
      );
      await gql(app, TOGGLE_TUNE_IN_MUTATION, { artistId }, followerToken);

      const result = await gql(
        app,
        ARTIST_WITH_TUNE_INS_QUERY,
        { username: "aartist1a" },
        ownerToken,
      );

      expect(result.errors).toBeUndefined();
      const artist = result.data!.artist as Record<string, unknown>;
      const fieldTuneIns = artist.tuneIns as Array<Record<string, unknown>>;
      expect(fieldTuneIns).toHaveLength(1);
    });

    it("rejects unauthenticated requests via Artist.tuneIns", async () => {
      await signupAndRegisterArtist(
        app,
        "a2@example.com",
        "auser2",
        "aartist2",
      );

      const result = await gql(app, ARTIST_WITH_TUNE_INS_QUERY, {
        username: "aartist2",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects non-owner callers via Artist.tuneIns (Forbidden)", async () => {
      await signupAndRegisterArtist(
        app,
        "a3a@example.com",
        "auser3a",
        "aartist3a",
      );
      const otherToken = await signupAndGetToken(
        app,
        "a3b@example.com",
        "auser3b",
      );

      const result = await gql(
        app,
        ARTIST_WITH_TUNE_INS_QUERY,
        { username: "aartist3a" },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Forbidden");
    });
  });

  describe("myTuneIns sort order (avatar rail)", () => {
    /**
     * Setup: viewer tunes in to artists A, B, C in that order.
     * Each test then arranges per-artist post activity and asserts the
     * resolver's returned order.
     */
    async function setupThreeArtists() {
      const a = await signupAndRegisterArtist(
        app,
        "ma1@example.com",
        "musera1",
        "mart_a",
      );
      const b = await signupAndRegisterArtist(
        app,
        "mb1@example.com",
        "muserb1",
        "mart_b",
      );
      const c = await signupAndRegisterArtist(
        app,
        "mc1@example.com",
        "muserc1",
        "mart_c",
      );
      const viewerToken = await signupAndGetToken(
        app,
        "viewer@example.com",
        "viewerm",
      );

      await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId: a.artistId },
        viewerToken,
      );
      await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId: b.artistId },
        viewerToken,
      );
      await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId: c.artistId },
        viewerToken,
      );

      return { a, b, c, viewerToken };
    }

    it("orders artists by MAX(posts.updated_at) DESC", async () => {
      const { a, b, c, viewerToken } = await setupThreeArtists();

      // a: oldest activity, b: newest activity, c: middle
      await createPostWithUpdatedAt(app, a.token, {
        updatedAt: new Date("2024-01-01T00:00:00Z"),
      });
      await createPostWithUpdatedAt(app, b.token, {
        updatedAt: new Date("2024-03-01T00:00:00Z"),
      });
      await createPostWithUpdatedAt(app, c.token, {
        updatedAt: new Date("2024-02-01T00:00:00Z"),
      });

      const result = await gql(app, MY_TUNE_INS_QUERY, {}, viewerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.myTuneIns as Array<Record<string, unknown>>;
      const usernames = tuneIns.map(
        (t) => (t.artist as Record<string, unknown>).artistUsername,
      );
      expect(usernames).toEqual(["mart_b", "mart_c", "mart_a"]);
    });

    it("places artists with no posts at the end, ordered by tunedInAt ASC", async () => {
      // a and c are needed only for the tune-in side effect inside
      // setupThreeArtists(); the assertion only inspects ordering.
      const { b, viewerToken } = await setupThreeArtists();

      // Only b has a post; a and c have nothing.
      await createPostWithUpdatedAt(app, b.token, {
        updatedAt: new Date("2024-05-01T00:00:00Z"),
      });

      const result = await gql(app, MY_TUNE_INS_QUERY, {}, viewerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.myTuneIns as Array<Record<string, unknown>>;
      const usernames = tuneIns.map(
        (t) => (t.artist as Record<string, unknown>).artistUsername,
      );
      // b (has post) → a, c (no posts, in tune-in order)
      expect(usernames).toEqual(["mart_b", "mart_a", "mart_c"]);
    });

    it("ignores draft posts when sorting (visibility filter)", async () => {
      const { a, b, viewerToken } = await setupThreeArtists();

      // a has a recent draft (must NOT count), b has an older public post
      await createPostWithUpdatedAt(app, a.token, {
        visibility: "draft",
        updatedAt: new Date("2024-12-01T00:00:00Z"),
      });
      await createPostWithUpdatedAt(app, b.token, {
        visibility: "public",
        updatedAt: new Date("2024-01-01T00:00:00Z"),
      });

      const result = await gql(app, MY_TUNE_INS_QUERY, {}, viewerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.myTuneIns as Array<Record<string, unknown>>;
      const orderedActive = tuneIns
        .filter((t) => t.lastPostActivityAt !== null)
        .map((t) => (t.artist as Record<string, unknown>).artistUsername);
      // Only b is "active" — a's draft is ignored, c has no posts.
      expect(orderedActive).toEqual(["mart_b"]);
      // a's lastPostActivityAt should be null (draft excluded)
      const tuneInForA = tuneIns.find(
        (t) =>
          (t.artist as Record<string, unknown>).artistUsername === "mart_a",
      );
      expect(tuneInForA!.lastPostActivityAt).toBeNull();
    });

    it("orders artists with no posts by tunedInAt ASC (oldest tune-in first)", async () => {
      const { viewerToken } = await setupThreeArtists();
      // No posts created — all three artists have null lastPostActivityAt.

      const result = await gql(app, MY_TUNE_INS_QUERY, {}, viewerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.myTuneIns as Array<Record<string, unknown>>;
      const usernames = tuneIns.map(
        (t) => (t.artist as Record<string, unknown>).artistUsername,
      );
      // All null → tunedInAt ASC = order of toggleTuneIn calls (a, b, c)
      expect(usernames).toEqual(["mart_a", "mart_b", "mart_c"]);
      for (const t of tuneIns) {
        expect(t.lastPostActivityAt).toBeNull();
      }
    });

    it("uses MAX(updated_at) so a recent edit re-sorts the artist to the front", async () => {
      const { a, b, viewerToken } = await setupThreeArtists();

      // Both have a post, b's is newer initially.
      await createPostWithUpdatedAt(app, a.token, {
        updatedAt: new Date("2024-01-01T00:00:00Z"),
      });
      await createPostWithUpdatedAt(app, b.token, {
        updatedAt: new Date("2024-02-01T00:00:00Z"),
      });

      // Bump a's old post's updated_at to "now-ish" — simulates an edit.
      await createPostWithUpdatedAt(app, a.token, {
        updatedAt: new Date("2024-12-01T00:00:00Z"),
      });

      const result = await gql(app, MY_TUNE_INS_QUERY, {}, viewerToken);

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.myTuneIns as Array<Record<string, unknown>>;
      const usernames = tuneIns
        .filter((t) => t.lastPostActivityAt !== null)
        .map((t) => (t.artist as Record<string, unknown>).artistUsername);
      expect(usernames).toEqual(["mart_a", "mart_b"]);
    });

    it("rejects unauthenticated myTuneIns requests", async () => {
      const result = await gql(app, MY_TUNE_INS_QUERY);
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });
});
