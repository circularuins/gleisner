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

const GENRES_QUERY = `
  query Genres {
    genres {
      id name normalizedName isPromoted
    }
  }
`;

const ADD_ARTIST_GENRE_MUTATION = `
  mutation AddArtistGenre($genreId: String!, $position: Int) {
    addArtistGenre(genreId: $genreId, position: $position) {
      position
      genre { id name }
      artist { id artistUsername }
    }
  }
`;

const REMOVE_ARTIST_GENRE_MUTATION = `
  mutation RemoveArtistGenre($genreId: String!) {
    removeArtistGenre(genreId: $genreId) {
      position
      genre { id name }
    }
  }
`;

const ARTIST_WITH_GENRES_QUERY = `
  query Artist($username: String!) {
    artist(username: $username) {
      id artistUsername
      genres {
        position
        genre { id name }
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

// Insert test genres directly via DB
async function seedGenres() {
  await db.execute(sql`TRUNCATE genres CASCADE`);
  await db.execute(sql`
    INSERT INTO genres (id, name, normalized_name, is_promoted) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Electronic', 'electronic', true),
    ('22222222-2222-2222-2222-222222222222', 'Jazz', 'jazz', false),
    ('33333333-3333-3333-3333-333333333333', 'Hip Hop', 'hip-hop', true)
  `);
}

describe("Genre / ArtistGenre GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
    await seedGenres();
  });

  describe("genres query", () => {
    it("returns all genres", async () => {
      const result = await gql(app, GENRES_QUERY);

      expect(result.errors).toBeUndefined();
      const genres = result.data!.genres as Array<Record<string, unknown>>;
      expect(genres).toHaveLength(3);
      const names = genres.map((g) => g.name).sort();
      expect(names).toEqual(["Electronic", "Hip Hop", "Jazz"]);
    });
  });

  describe("addArtistGenre", () => {
    it("adds a genre to artist profile", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "g1@example.com",
        "guser1",
        "gartist1",
      );

      const result = await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        {
          genreId: "11111111-1111-1111-1111-111111111111",
          position: 1,
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const ag = result.data!.addArtistGenre as Record<string, unknown>;
      expect(ag.position).toBe(1);
      expect((ag.genre as Record<string, unknown>).name).toBe("Electronic");
      expect((ag.artist as Record<string, unknown>).artistUsername).toBe(
        "gartist1",
      );
    });

    it("rejects duplicate genre", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "g2@example.com",
        "guser2",
        "gartist2",
      );

      await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      const result = await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("already added or failed");
    });

    it("rejects non-existent genre", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "g3@example.com",
        "guser3",
        "gartist3",
      );

      const result = await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "00000000-0000-0000-0000-000000000000" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Genre not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, ADD_ARTIST_GENRE_MUTATION, {
        genreId: "11111111-1111-1111-1111-111111111111",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects if user has no artist profile", async () => {
      const token = await signupAndGetToken(app, "g4@example.com", "guser4");

      const result = await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Artist profile required");
    });
  });

  describe("removeArtistGenre", () => {
    it("removes a genre from artist profile", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r1@example.com",
        "ruser1",
        "rartist1",
      );

      await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      const result = await gql(
        app,
        REMOVE_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(
        (
          (result.data!.removeArtistGenre as Record<string, unknown>)
            .genre as Record<string, unknown>
        ).name,
      ).toBe("Electronic");

      // Verify gone
      const artistResult = await gql(app, ARTIST_WITH_GENRES_QUERY, {
        username: "rartist1",
        birthYearMonth: "1990-01",
      });
      const artist = artistResult.data!.artist as Record<string, unknown>;
      expect(artist.genres).toEqual([]);
    });

    it("rejects removing genre not in profile", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "r2@example.com",
        "ruser2",
        "rartist2",
      );

      const result = await gql(
        app,
        REMOVE_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Genre not found in your profile");
    });
  });

  describe("Artist.genres field", () => {
    it("returns genres via artist query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "af1@example.com",
        "afuser1",
        "afartist1",
      );

      await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "11111111-1111-1111-1111-111111111111", position: 0 },
        token,
      );
      await gql(
        app,
        ADD_ARTIST_GENRE_MUTATION,
        { genreId: "22222222-2222-2222-2222-222222222222", position: 1 },
        token,
      );

      const result = await gql(app, ARTIST_WITH_GENRES_QUERY, {
        username: "afartist1",
        birthYearMonth: "1990-01",
      });

      expect(result.errors).toBeUndefined();
      const artist = result.data!.artist as Record<string, unknown>;
      const genres = artist.genres as Array<Record<string, unknown>>;
      expect(genres).toHaveLength(2);
    });
  });
});
