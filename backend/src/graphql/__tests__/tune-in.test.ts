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
        birthYearMonth: "1990-01",
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
        birthYearMonth: "1990-01",
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

  describe("tuneIns query", () => {
    it("returns tuned-in users for an artist", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "q1a@example.com",
        "quser1a",
        "qartist1a",
      );
      const userToken = await signupAndGetToken(
        app,
        "q1b@example.com",
        "quser1b",
      );

      await gql(app, TOGGLE_TUNE_IN_MUTATION, { artistId }, userToken);

      const result = await gql(app, TUNE_INS_QUERY, { artistId });

      expect(result.errors).toBeUndefined();
      const tuneIns = result.data!.tuneIns as Array<Record<string, unknown>>;
      expect(tuneIns).toHaveLength(1);
    });

    it("returns empty array for artist with no tune-ins", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "q2@example.com",
        "quser2",
        "qartist2",
      );

      const result = await gql(app, TUNE_INS_QUERY, { artistId });

      expect(result.errors).toBeUndefined();
      expect(result.data!.tuneIns).toEqual([]);
    });
  });
});
