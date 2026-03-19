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

const REGISTER_ARTIST_MUTATION = `
  mutation RegisterArtist($artistUsername: String!, $displayName: String!) {
    registerArtist(artistUsername: $artistUsername, displayName: $displayName) {
      id artistUsername
    }
  }
`;

const CREATE_ARTIST_LINK_MUTATION = `
  mutation CreateArtistLink(
    $linkCategory: LinkCategory!,
    $platform: String!,
    $url: String!,
    $position: Int
  ) {
    createArtistLink(
      linkCategory: $linkCategory,
      platform: $platform,
      url: $url,
      position: $position
    ) {
      id linkCategory platform url position createdAt
    }
  }
`;

const UPDATE_ARTIST_LINK_MUTATION = `
  mutation UpdateArtistLink(
    $id: String!,
    $linkCategory: LinkCategory,
    $platform: String,
    $url: String,
    $position: Int
  ) {
    updateArtistLink(
      id: $id,
      linkCategory: $linkCategory,
      platform: $platform,
      url: $url,
      position: $position
    ) {
      id linkCategory platform url position
    }
  }
`;

const DELETE_ARTIST_LINK_MUTATION = `
  mutation DeleteArtistLink($id: String!) {
    deleteArtistLink(id: $id) {
      id platform
    }
  }
`;

const ARTIST_LINKS_QUERY = `
  query ArtistLinks($artistId: String!) {
    artistLinks(artistId: $artistId) {
      id linkCategory platform url position
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
  const result = await gql(
    app,
    REGISTER_ARTIST_MUTATION,
    { artistUsername, displayName: `Artist ${artistUsername}` },
    token,
  );
  const artistId = (result.data!.registerArtist as { id: string }).id;
  return { token, artistId };
}

describe("ArtistLink GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createArtistLink", () => {
    it("creates a link successfully", async () => {
      const { token } = await signupAndRegisterArtist(
        app,
        "l1@example.com",
        "luser1",
        "lartist1",
      );

      const result = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/test",
          position: 1,
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const link = result.data!.createArtistLink as Record<string, unknown>;
      expect(link.id).toBeDefined();
      expect(link.linkCategory).toBe("social");
      expect(link.platform).toBe("Twitter");
      expect(link.url).toBe("https://twitter.com/test");
      expect(link.position).toBe(1);
    });

    it("rejects invalid URL scheme", async () => {
      const { token } = await signupAndRegisterArtist(
        app,
        "l2@example.com",
        "luser2",
        "lartist2",
      );

      const result = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "website",
          platform: "Evil",
          url: "javascript:alert(1)",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("URL must use http or https");
    });

    it("rejects invalid URL format", async () => {
      const { token } = await signupAndRegisterArtist(
        app,
        "l3@example.com",
        "luser3",
        "lartist3",
      );

      const result = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "website",
          platform: "Bad",
          url: "not-a-url",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Invalid URL format");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_ARTIST_LINK_MUTATION, {
        linkCategory: "social",
        platform: "Twitter",
        url: "https://twitter.com/test",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects if user has no artist profile", async () => {
      const token = await signupAndGetToken(app, "l4@example.com", "luser4");

      const result = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/test",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Artist profile required");
    });
  });

  describe("updateArtistLink", () => {
    it("updates link fields", async () => {
      const { token } = await signupAndRegisterArtist(
        app,
        "u1@example.com",
        "uuser1",
        "uartist1",
      );

      const createResult = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/old",
        },
        token,
      );
      const linkId = (createResult.data!.createArtistLink as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_ARTIST_LINK_MUTATION,
        {
          id: linkId,
          platform: "X",
          url: "https://x.com/new",
          linkCategory: "website",
        },
        token,
      );

      expect(result.errors).toBeUndefined();
      const link = result.data!.updateArtistLink as Record<string, unknown>;
      expect(link.platform).toBe("X");
      expect(link.url).toBe("https://x.com/new");
      expect(link.linkCategory).toBe("website");
    });

    it("rejects update by another user", async () => {
      const { token: token1 } = await signupAndRegisterArtist(
        app,
        "u2a@example.com",
        "uuser2a",
        "uartist2a",
      );
      const { token: token2 } = await signupAndRegisterArtist(
        app,
        "u2b@example.com",
        "uuser2b",
        "uartist2b",
      );

      const createResult = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/test",
        },
        token1,
      );
      const linkId = (createResult.data!.createArtistLink as { id: string }).id;

      const result = await gql(
        app,
        UPDATE_ARTIST_LINK_MUTATION,
        { id: linkId, platform: "Stolen" },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Link not found");
    });
  });

  describe("deleteArtistLink", () => {
    it("deletes own link", async () => {
      const { token, artistId } = await signupAndRegisterArtist(
        app,
        "d1@example.com",
        "duser1",
        "dartist1",
      );

      const createResult = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "music",
          platform: "Spotify",
          url: "https://spotify.com/test",
        },
        token,
      );
      const linkId = (createResult.data!.createArtistLink as { id: string }).id;

      const result = await gql(
        app,
        DELETE_ARTIST_LINK_MUTATION,
        { id: linkId },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(
        (result.data!.deleteArtistLink as Record<string, unknown>).platform,
      ).toBe("Spotify");

      // Verify gone
      const queryResult = await gql(app, ARTIST_LINKS_QUERY, { artistId });
      expect(queryResult.data!.artistLinks).toEqual([]);
    });

    it("rejects delete by another user", async () => {
      const { token: token1 } = await signupAndRegisterArtist(
        app,
        "d2a@example.com",
        "duser2a",
        "dartist2a",
      );
      const { token: token2 } = await signupAndRegisterArtist(
        app,
        "d2b@example.com",
        "duser2b",
        "dartist2b",
      );

      const createResult = await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/test",
        },
        token1,
      );
      const linkId = (createResult.data!.createArtistLink as { id: string }).id;

      const result = await gql(
        app,
        DELETE_ARTIST_LINK_MUTATION,
        { id: linkId },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Link not found");
    });
  });

  describe("artistLinks query", () => {
    it("returns links for an artist", async () => {
      const { token, artistId } = await signupAndRegisterArtist(
        app,
        "q1@example.com",
        "quser1",
        "qartist1",
      );

      await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "social",
          platform: "Twitter",
          url: "https://twitter.com/test",
        },
        token,
      );
      await gql(
        app,
        CREATE_ARTIST_LINK_MUTATION,
        {
          linkCategory: "music",
          platform: "Spotify",
          url: "https://spotify.com/test",
        },
        token,
      );

      const result = await gql(app, ARTIST_LINKS_QUERY, { artistId });

      expect(result.errors).toBeUndefined();
      const links = result.data!.artistLinks as Array<Record<string, unknown>>;
      expect(links).toHaveLength(2);
    });

    it("returns empty array for artist with no links", async () => {
      const { artistId } = await signupAndRegisterArtist(
        app,
        "q2@example.com",
        "quser2",
        "qartist2",
      );

      const result = await gql(app, ARTIST_LINKS_QUERY, { artistId });

      expect(result.errors).toBeUndefined();
      expect(result.data!.artistLinks).toEqual([]);
    });
  });
});
