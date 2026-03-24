import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import "dotenv/config";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { sql } from "drizzle-orm";
import { Hono } from "hono";
import { createYoga } from "graphql-yoga";
import { initJwtKeys } from "../../auth/jwt.js";
import { authMiddleware, type AuthUser } from "../../auth/middleware.js";

// Import GraphQL schema setup
import { builder } from "../builder.js";
import "../types/index.js";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL)
  throw new Error("DATABASE_URL is required for integration tests");

const client = postgres(DATABASE_URL);
const db = drizzle(client);

// Build the Hono app with GraphQL for testing
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

describe("Auth GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  const SIGNUP_MUTATION = `
    mutation Signup($email: String!, $password: String!, $username: String!) {
      signup(email: $email, password: $password, username: $username) {
        token
        user { id did email username publicKey }
      }
    }
  `;

  const LOGIN_MUTATION = `
    mutation Login($email: String!, $password: String!) {
      login(email: $email, password: $password) {
        token
        user { id email username }
      }
    }
  `;

  const ME_QUERY = `
    query { me { id email username did } }
  `;

  describe("signup", () => {
    it("creates a user and returns token + user", async () => {
      const result = await gql(app, SIGNUP_MUTATION, {
        email: "test@example.com",
        password: "password123",
        username: "testuser",
      });

      expect(result.errors).toBeUndefined();
      const { token, user } = result.data!.signup as {
        token: string;
        user: Record<string, string>;
      };
      expect(token).toBeTruthy();
      expect(user.email).toBe("test@example.com");
      expect(user.username).toBe("testuser");
      expect(user.did).toMatch(/^did:web:gleisner\.app:u:.+$/);
      expect(user.publicKey).toContain("-----BEGIN PUBLIC KEY-----");
    });

    it("rejects password shorter than 8 characters", async () => {
      const result = await gql(app, SIGNUP_MUTATION, {
        email: "test@example.com",
        password: "short",
        username: "testuser",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Password must be between 8 and 128 characters",
      );
    });

    it("rejects password longer than 128 characters", async () => {
      const result = await gql(app, SIGNUP_MUTATION, {
        email: "test@example.com",
        password: "a".repeat(129),
        username: "testuser",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Password must be between 8 and 128 characters",
      );
    });

    it("rejects username shorter than 2 characters", async () => {
      const result = await gql(app, SIGNUP_MUTATION, {
        email: "test@example.com",
        password: "password123",
        username: "a",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Username must be between 2 and 30 characters",
      );
    });

    it("rejects username with invalid characters", async () => {
      const result = await gql(app, SIGNUP_MUTATION, {
        email: "test@example.com",
        password: "password123",
        username: "bad user!",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Username can only contain letters, numbers, and underscores",
      );
    });

    it("rejects duplicate email", async () => {
      await gql(app, SIGNUP_MUTATION, {
        email: "dup@example.com",
        password: "password123",
        username: "user1",
      });

      const result = await gql(app, SIGNUP_MUTATION, {
        email: "dup@example.com",
        password: "password123",
        username: "user2",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Email already registered");
    });

    it("rejects duplicate username", async () => {
      await gql(app, SIGNUP_MUTATION, {
        email: "user1@example.com",
        password: "password123",
        username: "sameuser",
      });

      const result = await gql(app, SIGNUP_MUTATION, {
        email: "user2@example.com",
        password: "password123",
        username: "sameuser",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Username already taken");
    });
  });

  describe("login", () => {
    beforeEach(async () => {
      // Create a user for login tests
      await gql(app, SIGNUP_MUTATION, {
        email: "login@example.com",
        password: "password123",
        username: "loginuser",
      });
    });

    it("returns token + user with valid credentials", async () => {
      const result = await gql(app, LOGIN_MUTATION, {
        email: "login@example.com",
        password: "password123",
      });

      expect(result.errors).toBeUndefined();
      const { token, user } = result.data!.login as {
        token: string;
        user: Record<string, string>;
      };
      expect(token).toBeTruthy();
      expect(user.email).toBe("login@example.com");
      expect(user.username).toBe("loginuser");
    });

    it("rejects wrong password", async () => {
      const result = await gql(app, LOGIN_MUTATION, {
        email: "login@example.com",
        password: "wrongpassword",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Invalid credentials");
    });

    it("rejects non-existent email", async () => {
      const result = await gql(app, LOGIN_MUTATION, {
        email: "nobody@example.com",
        password: "password123",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Invalid credentials");
    });

    it("rejects password longer than 128 characters (DoS prevention)", async () => {
      const result = await gql(app, LOGIN_MUTATION, {
        email: "login@example.com",
        password: "a".repeat(129),
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Invalid credentials");
    });
  });

  describe("me", () => {
    it("returns user info when authenticated", async () => {
      const signupResult = await gql(app, SIGNUP_MUTATION, {
        email: "me@example.com",
        password: "password123",
        username: "meuser",
      });
      const { token } = signupResult.data!.signup as { token: string };

      const result = await gql(app, ME_QUERY, undefined, token);

      expect(result.errors).toBeUndefined();
      const me = result.data!.me as Record<string, string>;
      expect(me.email).toBe("me@example.com");
      expect(me.username).toBe("meuser");
      expect(me.did).toMatch(/^did:web:gleisner\.app:u:.+$/);
    });

    it("returns null when not authenticated", async () => {
      const result = await gql(app, ME_QUERY);

      expect(result.errors).toBeUndefined();
      expect(result.data!.me).toBeNull();
    });
  });
});
