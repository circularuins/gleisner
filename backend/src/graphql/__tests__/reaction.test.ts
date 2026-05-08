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

const CREATE_TRACK_MUTATION = `
  mutation CreateTrack($name: String!, $color: String!) {
    createTrack(name: $name, color: $color) {
      id name color
    }
  }
`;

const CREATE_POST_MUTATION = `
  mutation CreatePost($trackId: String!, $mediaType: MediaType!) {
    createPost(trackId: $trackId, mediaType: $mediaType) {
      id
    }
  }
`;

const TOGGLE_REACTION_MUTATION = `
  mutation ToggleReaction($postId: String!, $emoji: String!) {
    toggleReaction(postId: $postId, emoji: $emoji) {
      id emoji createdAt
    }
  }
`;

const DELETE_REACTION_MUTATION = `
  mutation DeleteReaction($id: String!) {
    deleteReaction(id: $id) {
      id emoji
    }
  }
`;

const REACTIONS_QUERY = `
  query Reactions($postId: String!) {
    reactions(postId: $postId) {
      id emoji
      user { id username }
    }
  }
`;

const POST_WITH_REACTIONS_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id title
      reactions {
        id emoji
      }
    }
  }
`;

const REACTION_WITH_RELATIONS_QUERY = `
  query Reactions($postId: String!) {
    reactions(postId: $postId) {
      id emoji
      user { id username }
      post { id }
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
  await gql(
    app,
    REGISTER_ARTIST_MUTATION,
    { artistUsername, displayName: `Artist ${artistUsername}` },
    token,
  );
  return token;
}

async function createPostForTest(
  app: ReturnType<typeof createTestApp>,
  token: string,
) {
  const trackResult = await gql(
    app,
    CREATE_TRACK_MUTATION,
    { name: "TestTrack", color: "#FF0000" },
    token,
  );
  const trackId = (trackResult.data!.createTrack as { id: string }).id;

  const postResult = await gql(
    app,
    CREATE_POST_MUTATION,
    { trackId, mediaType: "thought" },
    token,
  );
  return (postResult.data!.createPost as { id: string }).id;
}

describe("Reaction GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("toggleReaction", () => {
    it("creates a reaction (toggle on)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r1@example.com",
        "ruser1",
        "rartist1",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "👍" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleReaction as Record<string, unknown>;
      expect(reaction.id).toBeDefined();
      expect(reaction.emoji).toBe("👍");
      expect(reaction.createdAt).toBeDefined();
    });

    it("removes a reaction when toggled again (toggle off)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r2@example.com",
        "ruser2",
        "rartist2",
      );
      const postId = await createPostForTest(app, token);

      // Toggle on
      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "👍" }, token);

      // Toggle off
      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "👍" },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(result.data!.toggleReaction).toBeNull();

      // Verify it's gone
      const queryResult = await gql(app, REACTIONS_QUERY, { postId }, token);
      expect(queryResult.data!.reactions).toEqual([]);
    });

    it("allows different emojis on same post", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r3@example.com",
        "ruser3",
        "rartist3",
      );
      const postId = await createPostForTest(app, token);

      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "👍" }, token);
      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "❤️" }, token);

      const queryResult = await gql(app, REACTIONS_QUERY, { postId }, token);
      const reactions = queryResult.data!.reactions as Array<
        Record<string, unknown>
      >;
      expect(reactions).toHaveLength(2);
      const emojis = reactions.map((r) => r.emoji).sort();
      expect(emojis).toEqual(["❤️", "👍"]);
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, TOGGLE_REACTION_MUTATION, {
        postId: "00000000-0000-0000-0000-000000000000",
        emoji: "👍",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects when post does not exist", async () => {
      const token = await signupAndGetToken(app, "r4@example.com", "ruser4");

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId: "00000000-0000-0000-0000-000000000000", emoji: "👍" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Post not found");
    });

    it("rejects empty emoji", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r5@example.com",
        "ruser5",
        "rartist5",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "   " },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Emoji is required");
    });

    it("allows non-artist users to react", async () => {
      const artistToken = await signupAndRegisterArtist(
        app,
        "r6a@example.com",
        "ruser6a",
        "rartist6a",
      );
      const postId = await createPostForTest(app, artistToken);

      // Regular user (not an artist) reacts
      const userToken = await signupAndGetToken(
        app,
        "r6b@example.com",
        "ruser6b",
      );

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "🎉" },
        userToken,
      );

      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleReaction as Record<string, unknown>;
      expect(reaction.emoji).toBe("🎉");
    });

    // Emoji column expansion (varchar(10) -> varchar(64)) and validateEmoji
    // helper rollout. Each case exercises one branch of `validateEmoji` in
    // GraphQL context; the helper itself is unit-tested in
    // `validators.test.ts` so these only assert the integration path.

    it("accepts a 64-character emoji string (maxlen boundary)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r7@example.com",
        "ruser7",
        "rartist7",
      );
      const postId = await createPostForTest(app, token);
      const value = "a".repeat(64);

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: value },
        token,
      );
      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleReaction as Record<string, unknown>;
      expect(reaction.emoji).toBe(value);
    });

    it("rejects an emoji string longer than 64 characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r8@example.com",
        "ruser8",
        "rartist8",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "a".repeat(65) },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("64 characters or less");
    });

    it("accepts a ZWJ family emoji (👨‍👩‍👧‍👦 = 11 code units)", async () => {
      // The whole motivation for the column expansion: this emoji is 11
      // UTF-16 code units (4 surrogate pairs joined by 3 ZWJ chars), so
      // the previous `varchar(10)` silently truncated it to a different
      // glyph at the DB layer.
      const token = await signupAndRegisterArtist(
        app,
        "r9@example.com",
        "ruser9",
        "rartist9",
      );
      const postId = await createPostForTest(app, token);
      const family = "👨‍👩‍👧‍👦";

      const result = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: family },
        token,
      );
      expect(result.errors).toBeUndefined();
      const reaction = result.data!.toggleReaction as Record<string, unknown>;
      expect(reaction.emoji).toBe(family);
    });

    it("rejects emoji containing control or bidi characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r10@example.com",
        "ruser10",
        "rartist10",
      );
      const postId = await createPostForTest(app, token);

      // Trojan Source / invisible-payload class. Picker UI cannot produce
      // these, so any client sending them is already off-path.
      const cases = [
        "\u200B\uD83C\uDF89", // ZWSP + party-popper
        "\uD83C\uDF89\u202E\uD83C\uDF89", // RLO bidi override sandwich
        "\uD83C\uDF89\u0000\uD83C\uDF89", // NUL embedded
        "\uD83C\uDF89\uFEFF\uD83C\uDF89", // ZWNBSP / BOM (mid-string; trim() would otherwise strip a leading/trailing BOM)
      ];
      for (const value of cases) {
        const result = await gql(
          app,
          TOGGLE_REACTION_MUTATION,
          { postId, emoji: value },
          token,
        );
        expect(result.errors).toBeDefined();
        expect(result.errors![0].message).toBe(
          "Emoji contains disallowed characters",
        );
      }
    });

    it("is idempotent under concurrent toggle requests for the same emoji", async () => {
      // Regression guard for the ON CONFLICT DO NOTHING refactor. The
      // previous SELECT → DELETE/INSERT path could race past `existing`
      // and surface a unique-constraint 500 ("Failed to create reaction")
      // when two requests arrived in the same tick. Either ordering of
      // INSERT-INSERT (one wins / one toggles off) is fine — what we
      // assert here is "no GraphQL errors and the table converges to a
      // deterministic state".
      const token = await signupAndRegisterArtist(
        app,
        "r11@example.com",
        "ruser11",
        "rartist11",
      );
      const postId = await createPostForTest(app, token);

      const results = await Promise.all([
        gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "🚀" }, token),
        gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "🚀" }, token),
      ]);
      for (const r of results) {
        expect(r.errors).toBeUndefined();
      }

      // After two toggles by the same user, the row count must be 0 OR 1
      // (depending on which call's INSERT succeeded first), but never 2 —
      // the unique constraint prevents 2, and the helper must not
      // surface that as an error.
      const queryResult = await gql(app, REACTIONS_QUERY, { postId }, token);
      const reactions = queryResult.data!.reactions as Array<unknown>;
      expect([0, 1]).toContain(reactions.length);
    });
  });

  describe("deleteReaction", () => {
    it("deletes own reaction", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "d1@example.com",
        "duser1",
        "dartist1",
      );
      const postId = await createPostForTest(app, token);

      const toggleResult = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "👍" },
        token,
      );
      const reactionId = (toggleResult.data!.toggleReaction as { id: string })
        .id;

      const result = await gql(
        app,
        DELETE_REACTION_MUTATION,
        { id: reactionId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const reaction = result.data!.deleteReaction as Record<string, unknown>;
      expect(reaction.emoji).toBe("👍");

      // Verify it's gone
      const queryResult = await gql(app, REACTIONS_QUERY, { postId }, token);
      expect(queryResult.data!.reactions).toEqual([]);
    });

    it("rejects delete of another user's reaction", async () => {
      const artistToken = await signupAndRegisterArtist(
        app,
        "d2a@example.com",
        "duser2a",
        "dartist2a",
      );
      const postId = await createPostForTest(app, artistToken);

      const toggleResult = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "👍" },
        artistToken,
      );
      const reactionId = (toggleResult.data!.toggleReaction as { id: string })
        .id;

      const otherToken = await signupAndGetToken(
        app,
        "d2b@example.com",
        "duser2b",
      );

      const result = await gql(
        app,
        DELETE_REACTION_MUTATION,
        { id: reactionId },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Reaction not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, DELETE_REACTION_MUTATION, {
        id: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("reactions query", () => {
    it("returns reactions for a post", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "q1a@example.com",
        "quser1a",
        "qartist1a",
      );
      const postId = await createPostForTest(app, token1);
      const token2 = await signupAndGetToken(app, "q1b@example.com", "quser1b");

      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "👍" }, token1);
      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "❤️" }, token2);

      const result = await gql(app, REACTIONS_QUERY, { postId }, token1);

      expect(result.errors).toBeUndefined();
      const reactions = result.data!.reactions as Array<
        Record<string, unknown>
      >;
      expect(reactions).toHaveLength(2);
    });

    it("returns empty array for post with no reactions", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "q2@example.com",
        "quser2",
        "qartist2",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(app, REACTIONS_QUERY, { postId }, token);

      expect(result.errors).toBeUndefined();
      expect(result.data!.reactions).toEqual([]);
    });
  });

  describe("Post.reactions field", () => {
    it("returns reactions via post query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "pf1@example.com",
        "pfuser1",
        "pfartist1",
      );
      const postId = await createPostForTest(app, token);

      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "🔥" }, token);

      const result = await gql(
        app,
        POST_WITH_REACTIONS_QUERY,
        { id: postId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      const reactions = post.reactions as Array<Record<string, unknown>>;
      expect(reactions).toHaveLength(1);
      expect(reactions[0].emoji).toBe("🔥");
    });
  });

  describe("Reaction.user and Reaction.post fields", () => {
    it("returns user and post via reactions query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "rel1@example.com",
        "reluser1",
        "relartist1",
      );
      const postId = await createPostForTest(app, token);

      await gql(app, TOGGLE_REACTION_MUTATION, { postId, emoji: "✨" }, token);

      const result = await gql(
        app,
        REACTION_WITH_RELATIONS_QUERY,
        { postId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const reactions = result.data!.reactions as Array<
        Record<string, unknown>
      >;
      expect(reactions).toHaveLength(1);
      const reaction = reactions[0];
      const user = reaction.user as Record<string, unknown>;
      // ReactionType.post is nullable (#250: hides child / non-public author
      // posts). Public author flow stays non-null but guard the assertion
      // so future test additions for hidden authors don't TypeError.
      const post = reaction.post as Record<string, unknown> | null;
      expect(user.username).toBe("reluser1");
      expect(post).not.toBeNull();
      expect(post!.id).toBe(postId);
    });
  });
});
