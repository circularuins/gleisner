import { describe, it, expect, beforeAll, beforeEach, vi } from "vitest";
import "dotenv/config";

// Mock R2 so media URL validation accepts localhost in all environments
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../storage/r2.js")>();
  return {
    ...actual,
    isR2Configured: vi.fn(() => false),
  };
});

import { Hono } from "hono";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { sql } from "drizzle-orm";
import { createYoga } from "graphql-yoga";
import { initJwtKeys } from "../../auth/jwt.js";
import { authMiddleware, type AuthUser } from "../../auth/middleware.js";
import { builder } from "../../graphql/builder.js";
import "../../graphql/types/index.js";
import { ogp } from "../ogp.js";
import {
  SIGNUP_MUTATION,
  REGISTER_ARTIST_MUTATION,
} from "../../graphql/__tests__/helpers.js";

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
  app.route("/ogp", ogp);
  return app;
}

async function gql(
  testApp: ReturnType<typeof createTestApp>,
  query: string,
  variables?: Record<string, unknown>,
  token?: string,
) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await testApp.request("/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  });
  return res.json() as Promise<{
    data?: Record<string, unknown>;
    errors?: Array<{ message: string }>;
  }>;
}

async function signupAndGetToken(
  testApp: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
) {
  const result = await gql(testApp, SIGNUP_MUTATION, {
    email,
    password: "password123",
    username,
    birthYearMonth: "1990-01",
  });
  return (result.data!.signup as { token: string }).token;
}

describe("OGP endpoint", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  it("returns OGP HTML for public artist", async () => {
    const token = await signupAndGetToken(app, "ogp@test.com", "ogpuser");
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "ogpartist", displayName: "OGP Test Artist" },
      token,
    );

    await db.execute(
      sql`UPDATE artists SET bio = 'Test bio' WHERE artist_username = 'ogpartist'`,
    );

    const res = await app.request("/ogp/@ogpartist");

    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain("og:title");
    expect(html).toContain("OGP Test Artist");
    expect(html).toContain("og:description");
    expect(html).toContain("Test bio");
    expect(html).toContain("twitter:card");
  });

  it("returns 404 for private artist", async () => {
    const token = await signupAndGetToken(app, "priv@test.com", "privuser");
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "privartist", displayName: "Private Artist" },
      token,
    );

    await db.execute(
      sql`UPDATE artists SET profile_visibility = 'private' WHERE artist_username = 'privartist'`,
    );

    const res = await app.request("/ogp/@privartist");

    expect(res.status).toBe(404);
  });

  it("returns 404 for non-existent artist", async () => {
    const res = await app.request("/ogp/@nonexistent");

    expect(res.status).toBe(404);
  });

  it("returns 404 for invalid username format", async () => {
    const res = await app.request("/ogp/@invalid-user!");

    expect(res.status).toBe(404);
  });

  it("escapes HTML in artist fields", async () => {
    const token = await signupAndGetToken(app, "xss@test.com", "xssuser");
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      {
        artistUsername: "xssartist",
        displayName: '<script>alert("xss")</script>',
      },
      token,
    );

    const res = await app.request("/ogp/@xssartist");

    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).not.toContain("<script>");
    expect(html).toContain("&lt;script&gt;");
  });

  it("uses tagline as fallback when bio is empty", async () => {
    const token = await signupAndGetToken(app, "tag@test.com", "taguser");
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "tagartist", displayName: "Tag Artist" },
      token,
    );

    await db.execute(
      sql`UPDATE artists SET tagline = 'My tagline' WHERE artist_username = 'tagartist'`,
    );

    const res = await app.request("/ogp/@tagartist");

    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain("My tagline");
  });
});
