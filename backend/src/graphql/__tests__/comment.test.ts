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
// Comments are disabled in production schema (see types/index.ts).
// Re-register for tests so the Phase 0 disablement is covered by integration coverage.
import "../types/comment.js";

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

const CREATE_COMMENT_MUTATION = `
  mutation CreateComment($postId: String!, $body: String!) {
    createComment(postId: $postId, body: $body) {
      id body createdAt updatedAt
    }
  }
`;

const UPDATE_COMMENT_MUTATION = `
  mutation UpdateComment($id: String!, $body: String!) {
    updateComment(id: $id, body: $body) {
      id body updatedAt
    }
  }
`;

const DELETE_COMMENT_MUTATION = `
  mutation DeleteComment($id: String!) {
    deleteComment(id: $id) {
      id body
    }
  }
`;

const COMMENTS_QUERY = `
  query Comments($postId: String!) {
    comments(postId: $postId) {
      id body
      user { id username }
    }
  }
`;

const POST_WITH_COMMENTS_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id
      comments {
        id body
      }
    }
  }
`;

const COMMENT_WITH_RELATIONS_QUERY = `
  query Comments($postId: String!) {
    comments(postId: $postId) {
      id body
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

describe("Comment GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createComment", () => {
    it("creates a comment successfully", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "c1@example.com",
        "cuser1",
        "cartist1",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Great post!" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const comment = result.data!.createComment as Record<string, unknown>;
      expect(comment.id).toBeDefined();
      expect(comment.body).toBe("Great post!");
      expect(comment.createdAt).toBeDefined();
      expect(comment.updatedAt).toBeDefined();
    });

    it("allows non-artist users to comment", async () => {
      const artistToken = await signupAndRegisterArtist(
        app,
        "c2a@example.com",
        "cuser2a",
        "cartist2a",
      );
      const postId = await createPostForTest(app, artistToken);

      const userToken = await signupAndGetToken(
        app,
        "c2b@example.com",
        "cuser2b",
      );

      const result = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Nice work!" },
        userToken,
      );

      expect(result.errors).toBeUndefined();
      const comment = result.data!.createComment as Record<string, unknown>;
      expect(comment.body).toBe("Nice work!");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_COMMENT_MUTATION, {
        postId: "00000000-0000-0000-0000-000000000000",
        body: "Hello",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects when post does not exist", async () => {
      const token = await signupAndGetToken(app, "c3@example.com", "cuser3");

      const result = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId: "00000000-0000-0000-0000-000000000000", body: "Hello" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Post not found");
    });

    it("rejects empty body", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "c4@example.com",
        "cuser4",
        "cartist4",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "   " },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Comment body is required");
    });

    it("rejects body longer than 500 characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "c5@example.com",
        "cuser5",
        "cartist5",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "a".repeat(501) },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Comment body must be 500 characters or less",
      );
    });
  });

  describe("updateComment", () => {
    it("updates comment body", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "u1@example.com",
        "uuser1",
        "uartist1",
      );
      const postId = await createPostForTest(app, token);

      const createResult = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Original" },
        token,
      );
      const commentId = (createResult.data!.createComment as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_COMMENT_MUTATION,
        { id: commentId, body: "Updated" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const comment = result.data!.updateComment as Record<string, unknown>;
      expect(comment.body).toBe("Updated");
    });

    it("rejects update by another user", async () => {
      const artistToken = await signupAndRegisterArtist(
        app,
        "u2a@example.com",
        "uuser2a",
        "uartist2a",
      );
      const postId = await createPostForTest(app, artistToken);

      const createResult = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "My comment" },
        artistToken,
      );
      const commentId = (createResult.data!.createComment as { id: string }).id;

      const otherToken = await signupAndGetToken(
        app,
        "u2b@example.com",
        "uuser2b",
      );

      const result = await gql(
        app,
        UPDATE_COMMENT_MUTATION,
        { id: commentId, body: "Stolen" },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Comment not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, UPDATE_COMMENT_MUTATION, {
        id: "00000000-0000-0000-0000-000000000000",
        body: "No Auth",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects empty body", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "u3@example.com",
        "uuser3",
        "uartist3",
      );
      const postId = await createPostForTest(app, token);

      const createResult = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Original" },
        token,
      );
      const commentId = (createResult.data!.createComment as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_COMMENT_MUTATION,
        { id: commentId, body: "  " },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Comment body is required");
    });
  });

  describe("deleteComment", () => {
    it("deletes own comment", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "d1@example.com",
        "duser1",
        "dartist1",
      );
      const postId = await createPostForTest(app, token);

      const createResult = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "ToDelete" },
        token,
      );
      const commentId = (createResult.data!.createComment as { id: string }).id;

      const result = await gql(
        app,
        DELETE_COMMENT_MUTATION,
        { id: commentId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const comment = result.data!.deleteComment as Record<string, unknown>;
      expect(comment.body).toBe("ToDelete");

      // Verify it's gone
      const queryResult = await gql(app, COMMENTS_QUERY, { postId });
      expect(queryResult.data!.comments).toEqual([]);
    });

    it("rejects delete by another user", async () => {
      const artistToken = await signupAndRegisterArtist(
        app,
        "d2a@example.com",
        "duser2a",
        "dartist2a",
      );
      const postId = await createPostForTest(app, artistToken);

      const createResult = await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Not yours" },
        artistToken,
      );
      const commentId = (createResult.data!.createComment as { id: string }).id;

      const otherToken = await signupAndGetToken(
        app,
        "d2b@example.com",
        "duser2b",
      );

      const result = await gql(
        app,
        DELETE_COMMENT_MUTATION,
        { id: commentId },
        otherToken,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Comment not found");
    });
  });

  describe("comments query", () => {
    it("returns comments for a post", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "q1@example.com",
        "quser1",
        "qartist1",
      );
      const postId = await createPostForTest(app, token);

      await gql(app, CREATE_COMMENT_MUTATION, { postId, body: "First" }, token);
      await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Second" },
        token,
      );

      const result = await gql(app, COMMENTS_QUERY, { postId });

      expect(result.errors).toBeUndefined();
      const comments = result.data!.comments as Array<Record<string, unknown>>;
      expect(comments).toHaveLength(2);
    });

    it("returns empty array for post with no comments", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "q2@example.com",
        "quser2",
        "qartist2",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(app, COMMENTS_QUERY, { postId });

      expect(result.errors).toBeUndefined();
      expect(result.data!.comments).toEqual([]);
    });
  });

  describe("Post.comments field", () => {
    it("returns comments via post query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "pf1@example.com",
        "pfuser1",
        "pfartist1",
      );
      const postId = await createPostForTest(app, token);

      await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "Nested comment" },
        token,
      );

      const result = await gql(app, POST_WITH_COMMENTS_QUERY, { id: postId });

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      const comments = post.comments as Array<Record<string, unknown>>;
      expect(comments).toHaveLength(1);
      expect(comments[0].body).toBe("Nested comment");
    });
  });

  describe("Comment.user and Comment.post fields", () => {
    it("returns user and post via comments query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "rel1@example.com",
        "reluser1",
        "relartist1",
      );
      const postId = await createPostForTest(app, token);

      await gql(
        app,
        CREATE_COMMENT_MUTATION,
        { postId, body: "With relations" },
        token,
      );

      const result = await gql(app, COMMENT_WITH_RELATIONS_QUERY, { postId });

      expect(result.errors).toBeUndefined();
      const comments = result.data!.comments as Array<Record<string, unknown>>;
      expect(comments).toHaveLength(1);
      const comment = comments[0];
      const user = comment.user as Record<string, unknown>;
      const post = comment.post as Record<string, unknown>;
      expect(user.username).toBe("reluser1");
      expect(post.id).toBe(postId);
    });
  });
});
