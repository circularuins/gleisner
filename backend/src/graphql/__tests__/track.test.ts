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
      id name color createdAt updatedAt
    }
  }
`;

const UPDATE_TRACK_MUTATION = `
  mutation UpdateTrack($id: String!, $name: String, $color: String) {
    updateTrack(id: $id, name: $name, color: $color) {
      id name color
    }
  }
`;

const DELETE_TRACK_MUTATION = `
  mutation DeleteTrack($id: String!) {
    deleteTrack(id: $id) {
      id name color
    }
  }
`;

const TRACK_QUERY = `
  query Track($id: String!) {
    track(id: $id) {
      id name color createdAt updatedAt
    }
  }
`;

const TRACKS_QUERY = `
  query Tracks($artistUsername: String!) {
    tracks(artistUsername: $artistUsername) {
      id name color
    }
  }
`;

const ARTIST_WITH_TRACKS_QUERY = `
  query Artist($username: String!) {
    artist(username: $username) {
      id artistUsername
      tracks {
        id name color
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

describe("Track GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createTrack", () => {
    it("creates a track successfully", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "t1@example.com",
        "tuser1",
        "tartist1",
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#FF0000" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const track = result.data!.createTrack as Record<string, unknown>;
      expect(track.name).toBe("Music");
      expect(track.color).toBe("#FF0000");
      expect(track.id).toBeDefined();
      expect(track.createdAt).toBeDefined();
      expect(track.updatedAt).toBeDefined();
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_TRACK_MUTATION, {
        name: "Music",
        color: "#FF0000",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects if user has no artist profile", async () => {
      const token = await signupAndGetToken(app, "t2@example.com", "tuser2");

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#FF0000" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Artist profile required to create a track",
      );
    });

    it("rejects empty name", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "t3@example.com",
        "tuser3",
        "tartist3",
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "", color: "#FF0000" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Track name must be between 1 and 30",
      );
    });

    it("rejects name longer than 30 characters", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "t4@example.com",
        "tuser4",
        "tartist4",
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "a".repeat(31), color: "#FF0000" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Track name must be between 1 and 30",
      );
    });

    it("rejects duplicate track name (exact match)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "dup1@example.com",
        "dupuser1",
        "dupartist1",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#FF0000" },
        token,
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#00FF00" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "A track with this name already exists",
      );
    });

    it("rejects duplicate track name (case-insensitive)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "dup2@example.com",
        "dupuser2",
        "dupartist2",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#FF0000" },
        token,
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "MUSIC", color: "#00FF00" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "A track with this name already exists",
      );
    });

    it("allows same track name for different artists", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "dup3@example.com",
        "dupuser3",
        "dupartist3",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "dup4@example.com",
        "dupuser4",
        "dupartist4",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#FF0000" },
        token1,
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "#00FF00" },
        token2,
      );

      expect(result.errors).toBeUndefined();
      const track = result.data!.createTrack as Record<string, unknown>;
      expect(track.name).toBe("Music");
    });

    it("rejects invalid color format", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "t5@example.com",
        "tuser5",
        "tartist5",
      );

      const result = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Music", color: "red" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("valid hex color");
    });
  });

  describe("updateTrack", () => {
    it("updates track fields", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "u1@example.com",
        "uuser1",
        "uartist1",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Original", color: "#000000" },
        token,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        UPDATE_TRACK_MUTATION,
        { id: trackId, name: "Updated", color: "#FFFFFF" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const track = result.data!.updateTrack as Record<string, unknown>;
      expect(track.name).toBe("Updated");
      expect(track.color).toBe("#FFFFFF");
    });

    it("rejects update by another user", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "u2@example.com",
        "uuser2",
        "uartist2",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "u3@example.com",
        "uuser3",
        "uartist3",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Mine", color: "#000000" },
        token1,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        UPDATE_TRACK_MUTATION,
        { id: trackId, name: "Stolen" },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Not authorized to update this track",
      );
    });

    it("rejects rename to duplicate name (case-insensitive)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "udup1@example.com",
        "udupuser1",
        "udupartist1",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "First", color: "#000000" },
        token,
      );
      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Second", color: "#111111" },
        token,
      );
      const secondId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        UPDATE_TRACK_MUTATION,
        { id: secondId, name: "FIRST" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "A track with this name already exists",
      );
    });

    it("allows renaming a track to its own name (different case)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "udup2@example.com",
        "udupuser2",
        "udupartist2",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "MyTrack", color: "#000000" },
        token,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        UPDATE_TRACK_MUTATION,
        { id: trackId, name: "MYTRACK" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const track = result.data!.updateTrack as Record<string, unknown>;
      expect(track.name).toBe("MYTRACK");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, UPDATE_TRACK_MUTATION, {
        id: "00000000-0000-0000-0000-000000000000",
        name: "No Auth",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("deleteTrack", () => {
    it("deletes a track successfully", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "d1@example.com",
        "duser1",
        "dartist1",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "ToDelete", color: "#FF0000" },
        token,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        DELETE_TRACK_MUTATION,
        { id: trackId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const track = result.data!.deleteTrack as Record<string, unknown>;
      expect(track.name).toBe("ToDelete");

      // Verify it's gone
      const queryResult = await gql(app, TRACK_QUERY, { id: trackId });
      expect(queryResult.data!.track).toBeNull();
    });

    it("rejects delete by another user", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "d2@example.com",
        "duser2",
        "dartist2",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "d3@example.com",
        "duser3",
        "dartist3",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "NotYours", color: "#000000" },
        token1,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(
        app,
        DELETE_TRACK_MUTATION,
        { id: trackId },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Not authorized to delete this track",
      );
    });
  });

  describe("track query", () => {
    it("returns track by ID", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "q1@example.com",
        "quser1",
        "qartist1",
      );

      const createResult = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "QueryTrack", color: "#00FF00" },
        token,
      );
      const trackId = (
        createResult.data!.createTrack as Record<string, unknown>
      ).id as string;

      const result = await gql(app, TRACK_QUERY, { id: trackId });

      expect(result.errors).toBeUndefined();
      const track = result.data!.track as Record<string, unknown>;
      expect(track.name).toBe("QueryTrack");
      expect(track.color).toBe("#00FF00");
    });

    it("returns null for non-existent ID", async () => {
      const result = await gql(app, TRACK_QUERY, {
        id: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.track).toBeNull();
    });
  });

  describe("tracks query", () => {
    it("returns tracks for an artist", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "ql1@example.com",
        "qluser1",
        "qlartist1",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Track A", color: "#FF0000" },
        token,
      );
      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Track B", color: "#00FF00" },
        token,
      );

      const result = await gql(app, TRACKS_QUERY, {
        artistUsername: "qlartist1",
      });

      expect(result.errors).toBeUndefined();
      const tracks = result.data!.tracks as Array<Record<string, unknown>>;
      expect(tracks).toHaveLength(2);
      const names = tracks.map((t) => t.name).sort();
      expect(names).toEqual(["Track A", "Track B"]);
    });

    it("returns empty array for non-existent artist", async () => {
      const result = await gql(app, TRACKS_QUERY, {
        artistUsername: "nonexistent",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.tracks).toEqual([]);
    });
  });

  describe("Artist.tracks field", () => {
    it("returns tracks via artist query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "af1@example.com",
        "afuser1",
        "afartist1",
      );

      await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Nested Track", color: "#0000FF" },
        token,
      );

      const result = await gql(app, ARTIST_WITH_TRACKS_QUERY, {
        username: "afartist1",
        birthYearMonth: "1990-01",
      });

      expect(result.errors).toBeUndefined();
      const artist = result.data!.artist as Record<string, unknown>;
      const tracks = artist.tracks as Array<Record<string, unknown>>;
      expect(tracks).toHaveLength(1);
      expect(tracks[0].name).toBe("Nested Track");
      expect(tracks[0].color).toBe("#0000FF");
    });
  });
});
