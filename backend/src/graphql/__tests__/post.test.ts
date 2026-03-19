import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { sign } from "node:crypto";
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
  mutation Signup($email: String!, $password: String!, $username: String!) {
    signup(email: $email, password: $password, username: $username) {
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
  mutation CreatePost(
    $trackId: String!,
    $mediaType: MediaType!,
    $title: String,
    $body: String,
    $mediaUrl: String,
    $importance: Float,
    $layoutX: Int,
    $layoutY: Int
  ) {
    createPost(
      trackId: $trackId,
      mediaType: $mediaType,
      title: $title,
      body: $body,
      mediaUrl: $mediaUrl,
      importance: $importance,
      layoutX: $layoutX,
      layoutY: $layoutY
    ) {
      id mediaType title body mediaUrl importance layoutX layoutY createdAt updatedAt
    }
  }
`;

const UPDATE_POST_MUTATION = `
  mutation UpdatePost(
    $id: String!,
    $mediaType: MediaType,
    $title: String,
    $body: String,
    $mediaUrl: String,
    $importance: Float,
    $layoutX: Int,
    $layoutY: Int
  ) {
    updatePost(
      id: $id,
      mediaType: $mediaType,
      title: $title,
      body: $body,
      mediaUrl: $mediaUrl,
      importance: $importance,
      layoutX: $layoutX,
      layoutY: $layoutY
    ) {
      id mediaType title body mediaUrl importance layoutX layoutY
    }
  }
`;

const DELETE_POST_MUTATION = `
  mutation DeletePost($id: String!) {
    deletePost(id: $id) {
      id mediaType title
    }
  }
`;

const POST_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id mediaType title body mediaUrl importance layoutX layoutY createdAt updatedAt
      author { id username }
      track { id name }
    }
  }
`;

const POSTS_QUERY = `
  query Posts($trackId: String!) {
    posts(trackId: $trackId) {
      id mediaType title
    }
  }
`;

const TRACK_WITH_POSTS_QUERY = `
  query Track($id: String!) {
    track(id: $id) {
      id name
      posts {
        id mediaType title
      }
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

async function signupRegisterArtistAndCreateTrack(
  app: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
  artistUsername: string,
  trackName: string = "TestTrack",
) {
  const token = await signupAndRegisterArtist(
    app,
    email,
    username,
    artistUsername,
  );
  const result = await gql(
    app,
    CREATE_TRACK_MUTATION,
    { name: trackName, color: "#FF0000" },
    token,
  );
  const trackId = (result.data!.createTrack as { id: string }).id;
  return { token, trackId };
}

describe("Post GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createPost", () => {
    it("creates a post with all fields", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p1@example.com",
        "puser1",
        "partist1",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId,
          mediaType: "image",
          title: "My Photo",
          body: "A beautiful sunset",
          mediaUrl: "https://example.com/photo.jpg",
          importance: 0.8,
          layoutX: 10,
          layoutY: 20,
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.createPost as Record<string, unknown>;
      expect(post.id).toBeDefined();
      expect(post.mediaType).toBe("image");
      expect(post.title).toBe("My Photo");
      expect(post.body).toBe("A beautiful sunset");
      expect(post.mediaUrl).toBe("https://example.com/photo.jpg");
      expect(post.importance).toBe(0.8);
      expect(post.layoutX).toBe(10);
      expect(post.layoutY).toBe(20);
      expect(post.createdAt).toBeDefined();
      expect(post.updatedAt).toBeDefined();
    });

    it("creates a post with minimal fields (defaults apply)", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p2@example.com",
        "puser2",
        "partist2",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.createPost as Record<string, unknown>;
      expect(post.mediaType).toBe("text");
      expect(post.title).toBeNull();
      expect(post.body).toBeNull();
      expect(post.mediaUrl).toBeNull();
      expect(post.importance).toBe(0.5);
      expect(post.layoutX).toBe(0);
      expect(post.layoutY).toBe(0);
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_POST_MUTATION, {
        trackId: "00000000-0000-0000-0000-000000000000",
        mediaType: "text",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects if user has no artist profile", async () => {
      const token = await signupAndGetToken(app, "p3@example.com", "puser3");

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId: "00000000-0000-0000-0000-000000000000",
          mediaType: "text",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Artist profile required to create a post",
      );
    });

    it("rejects posting to another user's track", async () => {
      const { trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p4a@example.com",
        "puser4a",
        "partist4a",
      );
      const otherToken = await signupAndRegisterArtist(
        app,
        "p4b@example.com",
        "puser4b",
        "partist4b",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text" },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Not authorized to post to this track",
      );
    });

    it("rejects title longer than 100 characters", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p5@example.com",
        "puser5",
        "partist5",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "a".repeat(101) },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Title must be 100 characters or less",
      );
    });

    it("rejects importance out of range", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p6@example.com",
        "puser6",
        "partist6",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", importance: 1.5 },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Importance must be between 0.0 and 1.0",
      );
    });
  });

  describe("updatePost", () => {
    it("updates post fields", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "u1@example.com",
        "uuser1",
        "uartist1",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "Original" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        {
          id: postId,
          mediaType: "image",
          title: "Updated",
          body: "New body",
          importance: 0.9,
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.updatePost as Record<string, unknown>;
      expect(post.mediaType).toBe("image");
      expect(post.title).toBe("Updated");
      expect(post.body).toBe("New body");
      expect(post.importance).toBe(0.9);
    });

    it("rejects update by another user", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "u2a@example.com",
        "uuser2a",
        "uartist2a",
      );
      const otherToken = await signupAndRegisterArtist(
        app,
        "u2b@example.com",
        "uuser2b",
        "uartist2b",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "Mine" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: postId, title: "Stolen" },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Not authorized to update this post",
      );
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, UPDATE_POST_MUTATION, {
        id: "00000000-0000-0000-0000-000000000000",
        title: "No Auth",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects title longer than 100 characters", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "u3@example.com",
        "uuser3",
        "uartist3",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "Original" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: postId, title: "a".repeat(101) },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Title must be 100 characters or less",
      );
    });
  });

  describe("deletePost", () => {
    it("deletes a post successfully", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "d1@example.com",
        "duser1",
        "dartist1",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "ToDelete" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        DELETE_POST_MUTATION,
        { id: postId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.deletePost as Record<string, unknown>;
      expect(post.title).toBe("ToDelete");

      // Verify it's gone
      const queryResult = await gql(app, POST_QUERY, { id: postId });
      expect(queryResult.data!.post).toBeNull();
    });

    it("rejects delete by another user", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "d2a@example.com",
        "duser2a",
        "dartist2a",
      );
      const otherToken = await signupAndRegisterArtist(
        app,
        "d2b@example.com",
        "duser2b",
        "dartist2b",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "NotYours" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        DELETE_POST_MUTATION,
        { id: postId },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Not authorized to delete this post",
      );
    });
  });

  describe("post query", () => {
    it("returns post by ID", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "q1@example.com",
        "quser1",
        "qartist1",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "image", title: "QueryPost" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(app, POST_QUERY, { id: postId });

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      expect(post.mediaType).toBe("image");
      expect(post.title).toBe("QueryPost");
    });

    it("returns null for non-existent ID", async () => {
      const result = await gql(app, POST_QUERY, {
        id: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.post).toBeNull();
    });
  });

  describe("posts query", () => {
    it("returns posts for a track", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "ql1@example.com",
        "qluser1",
        "qlartist1",
      );

      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "Post A" },
        token,
      );
      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "image", title: "Post B" },
        token,
      );

      const result = await gql(app, POSTS_QUERY, { trackId });

      expect(result.errors).toBeUndefined();
      const posts = result.data!.posts as Array<Record<string, unknown>>;
      expect(posts).toHaveLength(2);
      const titles = posts.map((p) => p.title).sort();
      expect(titles).toEqual(["Post A", "Post B"]);
    });

    it("returns empty array for non-existent trackId", async () => {
      const result = await gql(app, POSTS_QUERY, {
        trackId: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.posts).toEqual([]);
    });
  });

  describe("Track.posts field", () => {
    it("returns posts via track query", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "tf1@example.com",
        "tfuser1",
        "tfartist1",
      );

      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "Nested Post" },
        token,
      );

      const result = await gql(app, TRACK_WITH_POSTS_QUERY, { id: trackId });

      expect(result.errors).toBeUndefined();
      const track = result.data!.track as Record<string, unknown>;
      const posts = track.posts as Array<Record<string, unknown>>;
      expect(posts).toHaveLength(1);
      expect(posts[0].title).toBe("Nested Post");
    });
  });

  describe("Post.author and Post.track fields", () => {
    it("returns author and track via post query", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "rel1@example.com",
        "reluser1",
        "relartist1",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "text", title: "With Relations" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(app, POST_QUERY, { id: postId });

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      const author = post.author as Record<string, unknown>;
      const track = post.track as Record<string, unknown>;
      expect(author.username).toBe("reluser1");
      expect(track.name).toBe("TestTrack");
    });
  });

  describe("contentHash and signature", () => {
    const CREATE_POST_WITH_HASH = `
      mutation CreatePost(
        $trackId: String!,
        $mediaType: MediaType!,
        $title: String,
        $body: String,
        $signature: String
      ) {
        createPost(
          trackId: $trackId,
          mediaType: $mediaType,
          title: $title,
          body: $body,
          signature: $signature
        ) {
          id contentHash signature
        }
      }
    `;

    const UPDATE_POST_WITH_HASH = `
      mutation UpdatePost($id: String!, $title: String, $body: String, $signature: String) {
        updatePost(id: $id, title: $title, body: $body, signature: $signature) {
          id contentHash signature
        }
      }
    `;

    it("auto-generates contentHash on createPost", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "hash1@example.com",
        "hashuser1",
        "hashartist1",
      );

      const result = await gql(
        app,
        CREATE_POST_WITH_HASH,
        { trackId, mediaType: "text", title: "Hash Test", body: "Body" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.createPost as Record<string, unknown>;
      expect(post.contentHash).toBeDefined();
      expect(typeof post.contentHash).toBe("string");
      expect((post.contentHash as string).length).toBe(64);
      expect(post.signature).toBeNull();
    });

    it("recomputes contentHash on updatePost", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "hash2@example.com",
        "hashuser2",
        "hashartist2",
      );

      const createResult = await gql(
        app,
        CREATE_POST_WITH_HASH,
        { trackId, mediaType: "text", title: "Original" },
        token,
      );
      const created = createResult.data!.createPost as Record<string, unknown>;
      const originalHash = created.contentHash;

      const updateResult = await gql(
        app,
        UPDATE_POST_WITH_HASH,
        { id: created.id as string, title: "Updated" },
        token,
      );

      expect(updateResult.errors).toBeUndefined();
      const updated = updateResult.data!.updatePost as Record<string, unknown>;
      expect(updated.contentHash).toBeDefined();
      expect(updated.contentHash).not.toBe(originalHash);
    });

    it("saves valid signature on createPost", async () => {
      // First signup to get user's publicKey, then use the private key to sign
      const signupResult = await gql(app, SIGNUP_MUTATION, {
        email: "hash3@example.com",
        password: "password123",
        username: "hashuser3",
      });
      const token = (signupResult.data!.signup as { token: string }).token;
      const userId = (signupResult.data!.signup as { user: { id: string } })
        .user.id;

      // Get user's encrypted private key — we need the actual key for signing
      // Instead, let's query the DB directly for the user's keys
      // Generate a fresh key pair for testing, update the user's public key
      const { generateEdKeyPair } = await import("../../auth/crypto.js");
      const { publicKey: testPubKey, privateKey: testPrivKey } =
        generateEdKeyPair();

      await db.execute(
        sql`UPDATE users SET public_key = ${testPubKey} WHERE id = ${userId}`,
      );

      // Register artist and create track
      await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername: "hashartist3", displayName: "Hash Artist 3" },
        token,
      );
      const trackResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "HashTrack", color: "#FF0000" },
        token,
      );
      const trackId = (trackResult.data!.createTrack as { id: string }).id;

      // Compute expected hash to sign it
      const { computeContentHash } = await import("../../auth/signing.js");
      const contentHash = computeContentHash({
        title: "Signed Post",
        body: null,
        mediaUrl: null,
        importance: 0.5,
      });
      const sigBuf = sign(null, Buffer.from(contentHash), testPrivKey);
      const signatureB64 = sigBuf.toString("base64");

      const result = await gql(
        app,
        CREATE_POST_WITH_HASH,
        {
          trackId,
          mediaType: "text",
          title: "Signed Post",
          signature: signatureB64,
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.createPost as Record<string, unknown>;
      expect(post.contentHash).toBe(contentHash);
      expect(post.signature).toBe(signatureB64);
    });

    it("rejects invalid signature on createPost", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "hash4@example.com",
        "hashuser4",
        "hashartist4",
      );

      const result = await gql(
        app,
        CREATE_POST_WITH_HASH,
        {
          trackId,
          mediaType: "text",
          title: "Bad Sig",
          signature: "dGhpcyBpcyBub3QgYSB2YWxpZCBzaWduYXR1cmU=",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Invalid signature");
    });
  });
});
