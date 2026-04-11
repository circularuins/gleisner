import { describe, it, expect, beforeAll, beforeEach, vi } from "vitest";
import { sign } from "node:crypto";
import "dotenv/config";

// Mock R2 so media URL validation accepts localhost in all environments
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../storage/r2.js")>();
  return {
    ...actual,
    isR2Configured: vi.fn(() => false),
  };
});
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
          mediaUrl: "http://localhost:4000/photo.jpg",
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
      expect(post.mediaUrl).toBe("http://localhost:4000/photo.jpg");
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
        { trackId, mediaType: "thought" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.createPost as Record<string, unknown>;
      expect(post.mediaType).toBe("thought");
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
        mediaType: "thought",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects image post without mediaUrl", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "pmedia1@example.com",
        "pmuser1",
        "pmartist1",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "image", title: "No File" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Media file is required for this post type",
      );
    });

    it("rejects video post without mediaUrl", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "pmedia2@example.com",
        "pmuser2",
        "pmartist2",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "video", title: "No File" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Media file is required for this post type",
      );
    });

    it("allows text post without mediaUrl", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "pmedia3@example.com",
        "pmuser3",
        "pmartist3",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "Text Only" },
        token,
      );

      expect(result.errors).toBeUndefined();
    });

    it("allows link post without mediaUrl (URL is separate)", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "pmedia4@example.com",
        "pmuser4",
        "pmartist4",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId,
          mediaType: "link",
          title: "Link Post",
          mediaUrl: "https://example.com/article",
        },
        token,
      );

      expect(result.errors).toBeUndefined();
    });

    it("rejects if user has no artist profile", async () => {
      const token = await signupAndGetToken(app, "p3@example.com", "puser3");

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId: "00000000-0000-0000-0000-000000000000",
          mediaType: "thought",
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
        { trackId, mediaType: "thought" },
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
        { trackId, mediaType: "article", title: "a".repeat(101) },
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
        { trackId, mediaType: "thought", importance: 1.5 },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Importance must be between 0.0 and 1.0",
      );
    });

    it("rejects body longer than 10000 characters", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "p7@example.com",
        "puser7",
        "partist7",
      );

      const result = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "thought", body: "a".repeat(281) },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Body must be 280 characters or less",
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
        { trackId, mediaType: "article", title: "Original" },
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
          mediaUrl: "http://localhost:4000/updated.jpg",
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

    it("rejects changing mediaType to image without mediaUrl", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "umedia1@example.com",
        "umuser1",
        "umartist1",
      );
      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "Text Post" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: postId, mediaType: "image" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Media file is required for this post type",
      );
    });

    it("rejects clearing mediaUrl on image post", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "umedia2@example.com",
        "umuser2",
        "umartist2",
      );
      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId,
          mediaType: "image",
          title: "With File",
          mediaUrl: "http://localhost:4000/img.jpg",
        },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: postId, mediaUrl: null },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Media file is required for this post type",
      );
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
        { trackId, mediaType: "article", title: "Mine" },
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
        { trackId, mediaType: "article", title: "Original" },
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

    it("rejects body longer than 10000 characters on update", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "u4@example.com",
        "uuser4",
        "uartist4",
      );

      const createResult = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "Original" },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: postId, body: "a".repeat(10001) },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Body must be 10000 characters or less",
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
        { trackId, mediaType: "article", title: "ToDelete" },
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
        { trackId, mediaType: "article", title: "NotYours" },
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
        {
          trackId,
          mediaType: "image",
          title: "QueryPost",
          mediaUrl: "http://localhost:4000/query.jpg",
        },
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
        { trackId, mediaType: "article", title: "Post A" },
        token,
      );
      await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId,
          mediaType: "image",
          title: "Post B",
          mediaUrl: "http://localhost:4000/b.jpg",
        },
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
        { trackId, mediaType: "article", title: "Nested Post" },
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
        { trackId, mediaType: "article", title: "With Relations" },
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

  describe("myUnassignedPosts", () => {
    const MY_UNASSIGNED_POSTS_QUERY = `
      query {
        myUnassignedPosts {
          id title mediaType
          track { id }
        }
      }
    `;

    const DELETE_TRACK_MUTATION_LOCAL = `
      mutation DeleteTrack($id: String!) {
        deleteTrack(id: $id) {
          id
        }
      }
    `;

    it("returns empty when no unassigned posts exist", async () => {
      const { token } = await signupRegisterArtistAndCreateTrack(
        app,
        "ua1@example.com",
        "uauser1",
        "uaartist1",
      );

      const result = await gql(app, MY_UNASSIGNED_POSTS_QUERY, {}, token);

      expect(result.errors).toBeUndefined();
      expect(result.data!.myUnassignedPosts).toEqual([]);
    });

    it("returns posts after track deletion (trackId becomes null)", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "ua2@example.com",
        "uauser2",
        "uaartist2",
      );

      // Create posts on the track
      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "Orphan A" },
        token,
      );
      await gql(
        app,
        CREATE_POST_MUTATION,
        {
          trackId,
          mediaType: "image",
          title: "Orphan B",
          mediaUrl: "http://localhost:4000/orphan.jpg",
        },
        token,
      );

      // Delete the track — posts become unassigned (trackId = null)
      await gql(app, DELETE_TRACK_MUTATION_LOCAL, { id: trackId }, token);

      const result = await gql(app, MY_UNASSIGNED_POSTS_QUERY, {}, token);

      expect(result.errors).toBeUndefined();
      const posts = result.data!.myUnassignedPosts as Array<
        Record<string, unknown>
      >;
      expect(posts).toHaveLength(2);
      const titles = posts.map((p) => p.title).sort();
      expect(titles).toEqual(["Orphan A", "Orphan B"]);
      // Track should be null
      expect(posts[0].track).toBeNull();
      expect(posts[1].track).toBeNull();
    });

    it("does not return other user's unassigned posts", async () => {
      const { token: token1, trackId } =
        await signupRegisterArtistAndCreateTrack(
          app,
          "ua3a@example.com",
          "uauser3a",
          "uaartist3a",
        );
      const token2 = await signupAndRegisterArtist(
        app,
        "ua3b@example.com",
        "uauser3b",
        "uaartist3b",
      );

      // User1 creates a post, then deletes the track
      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "User1 Post" },
        token1,
      );
      await gql(app, DELETE_TRACK_MUTATION_LOCAL, { id: trackId }, token1);

      // User2 should see no unassigned posts
      const result = await gql(app, MY_UNASSIGNED_POSTS_QUERY, {}, token2);

      expect(result.errors).toBeUndefined();
      expect(result.data!.myUnassignedPosts).toEqual([]);
    });

    it("unassigned posts are excluded from timeline queries", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "ua4@example.com",
        "uauser4",
        "uaartist4",
      );

      // Create 2 posts, then delete track
      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "article", title: "Will Vanish" },
        token,
      );
      await gql(app, DELETE_TRACK_MUTATION_LOCAL, { id: trackId }, token);

      // Create a new track with a post (so we have something in timeline)
      const newTrackResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "NewTrack", color: "#00FF00" },
        token,
      );
      const newTrackId = (newTrackResult.data!.createTrack as { id: string })
        .id;
      await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId: newTrackId, mediaType: "article", title: "Visible Post" },
        token,
      );

      // posts query for newTrack should only return "Visible Post"
      const result = await gql(app, POSTS_QUERY, { trackId: newTrackId });
      const posts = result.data!.posts as Array<Record<string, unknown>>;
      expect(posts).toHaveLength(1);
      expect(posts[0].title).toBe("Visible Post");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, MY_UNASSIGNED_POSTS_QUERY);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
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
        { trackId, mediaType: "article", title: "Hash Test", body: "Body" },
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
        { trackId, mediaType: "article", title: "Original" },
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
        birthYearMonth: "1990-01",
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
        mediaType: "article",
        importance: 0.5,
      });
      const sigBuf = sign(null, Buffer.from(contentHash), testPrivKey);
      const signatureB64 = sigBuf.toString("base64");

      const result = await gql(
        app,
        CREATE_POST_WITH_HASH,
        {
          trackId,
          mediaType: "article",
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
          mediaType: "article",
          title: "Bad Sig",
          signature:
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Invalid signature");
    });

    it("rejects updating signed post content without new signature", async () => {
      // Setup: create a signed post
      const signupResult = await gql(app, SIGNUP_MUTATION, {
        email: "hash5@example.com",
        password: "password123",
        username: "hashuser5",
        birthYearMonth: "1990-01",
      });
      const token = (signupResult.data!.signup as { token: string }).token;
      const userId = (signupResult.data!.signup as { user: { id: string } })
        .user.id;

      const { generateEdKeyPair } = await import("../../auth/crypto.js");
      const { publicKey: testPubKey, privateKey: testPrivKey } =
        generateEdKeyPair();
      await db.execute(
        sql`UPDATE users SET public_key = ${testPubKey} WHERE id = ${userId}`,
      );

      await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername: "hashartist5", displayName: "Hash Artist 5" },
        token,
      );
      const trackResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "HashTrack5", color: "#FF0000" },
        token,
      );
      const trackId = (trackResult.data!.createTrack as { id: string }).id;

      const { computeContentHash } = await import("../../auth/signing.js");
      const contentHash = computeContentHash({
        title: "Signed Original",
        body: null,
        mediaUrl: null,
        mediaType: "article",
        importance: 0.5,
      });
      const { sign } = await import("node:crypto");
      const sigBuf = sign(null, Buffer.from(contentHash), testPrivKey);
      const signatureB64 = sigBuf.toString("base64");

      const createResult = await gql(
        app,
        CREATE_POST_WITH_HASH,
        {
          trackId,
          mediaType: "article",
          title: "Signed Original",
          signature: signatureB64,
        },
        token,
      );
      expect(createResult.errors).toBeUndefined();
      const postId = (createResult.data!.createPost as { id: string }).id;

      // Try to update content without providing new signature
      const updateResult = await gql(
        app,
        UPDATE_POST_WITH_HASH,
        { id: postId, title: "Tampered" },
        token,
      );

      expect(updateResult.errors).toBeDefined();
      expect(updateResult.errors![0].message).toContain(
        "A new signature is required",
      );
    });
  });

  describe("media duration limits (ADR 025)", () => {
    const CREATE_POST_WITH_DURATION = `
      mutation CreatePost($trackId: String!, $mediaType: MediaType!, $duration: Int, $mediaUrl: String) {
        createPost(trackId: $trackId, mediaType: $mediaType, duration: $duration, mediaUrl: $mediaUrl) {
          id duration mediaType
        }
      }
    `;

    it("rejects video longer than 60 seconds", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur1@test.com",
        "dur1",
        "durart1",
      );
      const result = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "video",
          duration: 61,
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("60-second limit");
    });

    it("accepts video at exactly 60 seconds", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur2@test.com",
        "dur2",
        "durart2",
      );
      const result = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "video",
          duration: 60,
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      expect(result.errors).toBeUndefined();
    });

    it("rejects audio longer than 300 seconds", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur3@test.com",
        "dur3",
        "durart3",
      );
      const result = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "audio",
          duration: 301,
          mediaUrl: "http://localhost:4000/test-audio.mp3",
        },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("300-second limit");
    });

    it("accepts audio at exactly 300 seconds", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur4@test.com",
        "dur4",
        "durart4",
      );
      const result = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "audio",
          duration: 300,
          mediaUrl: "http://localhost:4000/test-audio.mp3",
        },
        token,
      );
      expect(result.errors).toBeUndefined();
    });

    it("allows text post with any reasonable duration", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur5@test.com",
        "dur5",
        "durart5",
      );
      const result = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        { trackId, mediaType: "thought", duration: 3600 },
        token,
      );
      expect(result.errors).toBeUndefined();
    });

    // updatePost tests — effectiveType logic (args.mediaType ?? post.mediaType)
    const UPDATE_POST_WITH_DURATION = `
      mutation UpdatePost($id: String!, $mediaType: MediaType, $duration: Int, $mediaUrl: String) {
        updatePost(id: $id, mediaType: $mediaType, duration: $duration, mediaUrl: $mediaUrl) {
          id duration mediaType
        }
      }
    `;

    it("rejects updatePost with duration exceeding video limit", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur6@test.com",
        "dur6",
        "durart6",
      );
      const createResult = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "video",
          duration: 30,
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_WITH_DURATION,
        { id: postId, duration: 61 },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("60-second limit");
    });

    it("rejects updatePost changing text to video with over-limit duration", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur7@test.com",
        "dur7",
        "durart7",
      );
      const createResult = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        { trackId, mediaType: "thought", duration: 120 },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_WITH_DURATION,
        {
          id: postId,
          mediaType: "video",
          duration: 61,
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("60-second limit");
    });

    it("accepts updatePost with duration within video limit", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur8@test.com",
        "dur8",
        "durart8",
      );
      const createResult = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        {
          trackId,
          mediaType: "video",
          duration: 30,
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_POST_WITH_DURATION,
        { id: postId, duration: 60 },
        token,
      );
      expect(result.errors).toBeUndefined();
    });

    it("rejects updatePost changing mediaType when existing duration exceeds new limit", async () => {
      const { token, trackId } = await signupRegisterArtistAndCreateTrack(
        app,
        "dur9@test.com",
        "dur9",
        "durart9",
      );
      // Create text post with 120s duration (allowed for text)
      const createResult = await gql(
        app,
        CREATE_POST_WITH_DURATION,
        { trackId, mediaType: "thought", duration: 120 },
        token,
      );
      const postId = (createResult.data!.createPost as { id: string }).id;

      // Change to video without sending duration — existing 120s exceeds 60s limit
      const result = await gql(
        app,
        UPDATE_POST_WITH_DURATION,
        {
          id: postId,
          mediaType: "video",
          mediaUrl: "http://localhost:4000/test-video.mp4",
        },
        token,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("60-second limit");
    });
  });
});
