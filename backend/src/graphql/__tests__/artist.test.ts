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
if (!DATABASE_URL) throw new Error("DATABASE_URL is required for integration tests");

const client = postgres(DATABASE_URL);
const db = drizzle(client);

function createTestApp() {
  const schema = builder.toSchema();
  const yoga = createYoga<{ authUser?: AuthUser }>({ schema, maskedErrors: false });

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
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await app.request("/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  });
  return res.json() as Promise<{ data?: Record<string, unknown>; errors?: Array<{ message: string }> }>;
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
  mutation RegisterArtist(
    $artistUsername: String!,
    $displayName: String!,
    $tagline: String,
    $location: String,
    $activeSince: Int,
    $avatarUrl: String,
    $coverImageUrl: String
  ) {
    registerArtist(
      artistUsername: $artistUsername,
      displayName: $displayName,
      tagline: $tagline,
      location: $location,
      activeSince: $activeSince,
      avatarUrl: $avatarUrl,
      coverImageUrl: $coverImageUrl
    ) {
      id artistUsername displayName bio tagline location activeSince avatarUrl coverImageUrl tunedInCount createdAt updatedAt
    }
  }
`;

const UPDATE_ARTIST_MUTATION = `
  mutation UpdateArtist(
    $displayName: String,
    $bio: String,
    $tagline: String,
    $location: String,
    $activeSince: Int,
    $avatarUrl: String,
    $coverImageUrl: String
  ) {
    updateArtist(
      displayName: $displayName,
      bio: $bio,
      tagline: $tagline,
      location: $location,
      activeSince: $activeSince,
      avatarUrl: $avatarUrl,
      coverImageUrl: $coverImageUrl
    ) {
      id artistUsername displayName bio tagline location activeSince avatarUrl coverImageUrl tunedInCount
    }
  }
`;

const ARTIST_QUERY = `
  query Artist($username: String!) {
    artist(username: $username) {
      id artistUsername displayName bio tagline location activeSince avatarUrl coverImageUrl tunedInCount
    }
  }
`;

async function signupAndGetToken(app: ReturnType<typeof createTestApp>, email: string, username: string) {
  const result = await gql(app, SIGNUP_MUTATION, { email, password: "password123", username });
  return (result.data!.signup as { token: string }).token;
}

describe("Artist GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("registerArtist", () => {
    it("registers with required fields only", async () => {
      const token = await signupAndGetToken(app, "artist1@example.com", "user1");

      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "myartist",
        displayName: "My Artist",
      }, token);

      expect(result.errors).toBeUndefined();
      const artist = result.data!.registerArtist as Record<string, unknown>;
      expect(artist.artistUsername).toBe("myartist");
      expect(artist.displayName).toBe("My Artist");
      expect(artist.bio).toBeNull();
      expect(artist.tagline).toBeNull();
      expect(artist.location).toBeNull();
      expect(artist.activeSince).toBeNull();
      expect(artist.avatarUrl).toBeNull();
      expect(artist.coverImageUrl).toBeNull();
      expect(artist.tunedInCount).toBe(0);
    });

    it("registers with all fields", async () => {
      const token = await signupAndGetToken(app, "artist2@example.com", "user2");

      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "fullartist",
        displayName: "Full Artist",
        tagline: "Making music since forever",
        location: "Tokyo, Japan",
        activeSince: 2010,
        avatarUrl: "https://example.com/avatar.jpg",
        coverImageUrl: "https://example.com/cover.jpg",
      }, token);

      expect(result.errors).toBeUndefined();
      const artist = result.data!.registerArtist as Record<string, unknown>;
      expect(artist.artistUsername).toBe("fullartist");
      expect(artist.displayName).toBe("Full Artist");
      expect(artist.tagline).toBe("Making music since forever");
      expect(artist.location).toBe("Tokyo, Japan");
      expect(artist.activeSince).toBe(2010);
      expect(artist.avatarUrl).toBe("https://example.com/avatar.jpg");
      expect(artist.coverImageUrl).toBe("https://example.com/cover.jpg");
      expect(artist.tunedInCount).toBe(0);
    });

    it("rejects if user is already an artist", async () => {
      const token = await signupAndGetToken(app, "artist3@example.com", "user3");
      await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "first_artist",
        displayName: "First",
      }, token);

      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "second_artist",
        displayName: "Second",
      }, token);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("User is already registered as an artist");
    });

    it("rejects duplicate artist username", async () => {
      const token1 = await signupAndGetToken(app, "a4@example.com", "user4");
      await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "taken_name",
        displayName: "First",
      }, token1);

      const token2 = await signupAndGetToken(app, "a5@example.com", "user5");
      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "taken_name",
        displayName: "Second",
      }, token2);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Artist username already taken");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "noauth",
        displayName: "No Auth",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects invalid characters in username", async () => {
      const token = await signupAndGetToken(app, "a6@example.com", "user6");

      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "bad user!",
        displayName: "Bad",
      }, token);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Artist username can only contain");
    });

    it("rejects too short username", async () => {
      const token = await signupAndGetToken(app, "a7@example.com", "user7");

      const result = await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "a",
        displayName: "Short",
      }, token);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("Artist username must be between 2 and 30");
    });
  });

  describe("updateArtist", () => {
    it("updates artist fields", async () => {
      const token = await signupAndGetToken(app, "upd@example.com", "upduser");
      await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "updartist",
        displayName: "Original",
      }, token);

      const result = await gql(app, UPDATE_ARTIST_MUTATION, {
        displayName: "Updated Name",
        bio: "My bio",
        tagline: "New tagline",
        location: "Osaka, Japan",
      }, token);

      expect(result.errors).toBeUndefined();
      const artist = result.data!.updateArtist as Record<string, unknown>;
      expect(artist.displayName).toBe("Updated Name");
      expect(artist.bio).toBe("My bio");
      expect(artist.tagline).toBe("New tagline");
      expect(artist.location).toBe("Osaka, Japan");
      expect(artist.artistUsername).toBe("updartist");
    });

    it("clears fields when null is passed", async () => {
      const token = await signupAndGetToken(app, "clr@example.com", "clruser");
      await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "clrartist",
        displayName: "Original",
        tagline: "Will be cleared",
        location: "Will be cleared",
      }, token);

      const result = await gql(app, UPDATE_ARTIST_MUTATION, {
        tagline: null,
        location: null,
      }, token);

      expect(result.errors).toBeUndefined();
      const artist = result.data!.updateArtist as Record<string, unknown>;
      expect(artist.tagline).toBeNull();
      expect(artist.location).toBeNull();
      expect(artist.displayName).toBe("Original");
    });

    it("rejects if artist profile not found", async () => {
      const token = await signupAndGetToken(app, "noprof@example.com", "noprof");

      const result = await gql(app, UPDATE_ARTIST_MUTATION, {
        displayName: "No Profile",
      }, token);

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Artist profile not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, UPDATE_ARTIST_MUTATION, {
        displayName: "No Auth",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("artist query", () => {
    it("returns artist by username", async () => {
      const token = await signupAndGetToken(app, "q1@example.com", "quser1");
      await gql(app, REGISTER_ARTIST_MUTATION, {
        artistUsername: "queryartist",
        displayName: "Query Artist",
        tagline: "Hello world",
      }, token);

      const result = await gql(app, ARTIST_QUERY, { username: "queryartist" });

      expect(result.errors).toBeUndefined();
      const artist = result.data!.artist as Record<string, unknown>;
      expect(artist.artistUsername).toBe("queryartist");
      expect(artist.displayName).toBe("Query Artist");
      expect(artist.tagline).toBe("Hello world");
    });

    it("returns null for non-existent username", async () => {
      const result = await gql(app, ARTIST_QUERY, { username: "nonexistent" });

      expect(result.errors).toBeUndefined();
      expect(result.data!.artist).toBeNull();
    });
  });
});
