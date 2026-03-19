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
  mutation Signup($email: String!, $password: String!, $username: String!) {
    signup(email: $email, password: $password, username: $username) {
      token
      user { id }
    }
  }
`;

const TOGGLE_FOLLOW_MUTATION = `
  mutation ToggleFollow($userId: String!) {
    toggleFollow(userId: $userId) {
      createdAt
      follower { id username }
      following { id username }
    }
  }
`;

const FOLLOWERS_QUERY = `
  query Followers($userId: String!) {
    followers(userId: $userId) {
      follower { id username }
    }
  }
`;

const FOLLOWING_QUERY = `
  query Following($userId: String!) {
    following(userId: $userId) {
      following { id username }
    }
  }
`;

async function signupAndGetTokenAndId(
  app: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
) {
  const result = await gql(app, SIGNUP_MUTATION, {
    email,
    password: "password123",
    username,
  });
  const signup = result.data!.signup as {
    token: string;
    user: { id: string };
  };
  return { token: signup.token, userId: signup.user.id };
}

describe("Follow GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("toggleFollow", () => {
    it("follows a user (toggle on)", async () => {
      const { token: token1 } = await signupAndGetTokenAndId(
        app,
        "f1a@example.com",
        "fuser1a",
      );
      const { userId: userId2 } = await signupAndGetTokenAndId(
        app,
        "f1b@example.com",
        "fuser1b",
      );

      const result = await gql(
        app,
        TOGGLE_FOLLOW_MUTATION,
        { userId: userId2 },
        token1,
      );

      expect(result.errors).toBeUndefined();
      const follow = result.data!.toggleFollow as Record<string, unknown>;
      expect(follow.createdAt).toBeDefined();
      expect((follow.follower as Record<string, unknown>).username).toBe(
        "fuser1a",
      );
      expect((follow.following as Record<string, unknown>).username).toBe(
        "fuser1b",
      );
    });

    it("unfollows when toggled again (toggle off)", async () => {
      const { token: token1 } = await signupAndGetTokenAndId(
        app,
        "f2a@example.com",
        "fuser2a",
      );
      const { userId: userId2 } = await signupAndGetTokenAndId(
        app,
        "f2b@example.com",
        "fuser2b",
      );

      await gql(app, TOGGLE_FOLLOW_MUTATION, { userId: userId2 }, token1);
      const result = await gql(
        app,
        TOGGLE_FOLLOW_MUTATION,
        { userId: userId2 },
        token1,
      );

      expect(result.errors).toBeUndefined();
      expect(result.data!.toggleFollow).toBeNull();

      const followersResult = await gql(app, FOLLOWERS_QUERY, {
        userId: userId2,
      });
      expect(followersResult.data!.followers).toEqual([]);
    });

    it("rejects self-follow", async () => {
      const { token, userId } = await signupAndGetTokenAndId(
        app,
        "f3@example.com",
        "fuser3",
      );

      const result = await gql(app, TOGGLE_FOLLOW_MUTATION, { userId }, token);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Cannot follow yourself");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, TOGGLE_FOLLOW_MUTATION, {
        userId: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("followers / following queries", () => {
    it("returns followers and following", async () => {
      const { token: token1, userId: userId1 } = await signupAndGetTokenAndId(
        app,
        "q1a@example.com",
        "quser1a",
      );
      const { userId: userId2 } = await signupAndGetTokenAndId(
        app,
        "q1b@example.com",
        "quser1b",
      );

      await gql(app, TOGGLE_FOLLOW_MUTATION, { userId: userId2 }, token1);

      const followersResult = await gql(app, FOLLOWERS_QUERY, {
        userId: userId2,
      });
      expect(followersResult.errors).toBeUndefined();
      const followers = followersResult.data!.followers as Array<
        Record<string, unknown>
      >;
      expect(followers).toHaveLength(1);

      const followingResult = await gql(app, FOLLOWING_QUERY, {
        userId: userId1,
      });
      expect(followingResult.errors).toBeUndefined();
      const following = followingResult.data!.following as Array<
        Record<string, unknown>
      >;
      expect(following).toHaveLength(1);
    });

    it("returns empty arrays for user with no follows", async () => {
      const { userId } = await signupAndGetTokenAndId(
        app,
        "q2@example.com",
        "quser2",
      );

      const followersResult = await gql(app, FOLLOWERS_QUERY, { userId });
      expect(followersResult.data!.followers).toEqual([]);

      const followingResult = await gql(app, FOLLOWING_QUERY, { userId });
      expect(followingResult.data!.following).toEqual([]);
    });
  });
});
