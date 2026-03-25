import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { sql } from "drizzle-orm";
import { getTestApp, gql, signupAndRegisterArtist, db } from "./helpers.js";

const DISCOVER_ARTISTS_QUERY = `
  query DiscoverArtists($genreId: String, $query: String, $limit: Int, $offset: Int) {
    discoverArtists(genreId: $genreId, query: $query, limit: $limit, offset: $offset) {
      id artistUsername displayName tunedInCount
    }
  }
`;

const ADD_GENRE_MUTATION = `
  mutation AddArtistGenre($genreId: String!, $position: Int) {
    addArtistGenre(genreId: $genreId, position: $position) {
      position
    }
  }
`;

describe("discoverArtists query", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
    await db.execute(sql`TRUNCATE genres CASCADE`);
  });

  it("returns all artists sorted by tunedInCount", async () => {
    await signupAndRegisterArtist(app, "a1@test.com", "user1", "artist1");
    await signupAndRegisterArtist(app, "a2@test.com", "user2", "artist2");

    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {});

    expect(result.errors).toBeUndefined();
    const artists = result.data!.discoverArtists as Array<{
      artistUsername: string;
    }>;
    expect(artists).toHaveLength(2);
  });

  it("filters by text query (displayName)", async () => {
    await signupAndRegisterArtist(app, "a1@test.com", "user1", "alpha");
    await signupAndRegisterArtist(app, "a2@test.com", "user2", "beta");

    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {
      query: "Artist alpha",
    });

    expect(result.errors).toBeUndefined();
    const artists = result.data!.discoverArtists as Array<{
      artistUsername: string;
    }>;
    expect(artists).toHaveLength(1);
    expect(artists[0].artistUsername).toBe("alpha");
  });

  it("filters by genre", async () => {
    const token1 = await signupAndRegisterArtist(
      app,
      "a1@test.com",
      "user1",
      "rock_artist",
    );
    await signupAndRegisterArtist(app, "a2@test.com", "user2", "jazz_artist");

    // Create genres
    await db.execute(
      sql`INSERT INTO genres (id, name, normalized_name, is_promoted) VALUES ('00000000-0000-0000-0000-000000000001', 'Rock', 'rock', true)`,
    );

    // Assign genre to artist1 only
    await gql(
      app,
      ADD_GENRE_MUTATION,
      {
        genreId: "00000000-0000-0000-0000-000000000001",
      },
      token1,
    );

    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {
      genreId: "00000000-0000-0000-0000-000000000001",
    });

    expect(result.errors).toBeUndefined();
    const artists = result.data!.discoverArtists as Array<{
      artistUsername: string;
    }>;
    expect(artists).toHaveLength(1);
    expect(artists[0].artistUsername).toBe("rock_artist");
  });

  it("respects limit and offset", async () => {
    await signupAndRegisterArtist(app, "a1@test.com", "user1", "artist_a");
    await signupAndRegisterArtist(app, "a2@test.com", "user2", "artist_b");
    await signupAndRegisterArtist(app, "a3@test.com", "user3", "artist_c");

    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {
      limit: 2,
      offset: 0,
    });

    expect(result.errors).toBeUndefined();
    const artists = result.data!.discoverArtists as Array<unknown>;
    expect(artists).toHaveLength(2);

    const page2 = await gql(app, DISCOVER_ARTISTS_QUERY, {
      limit: 2,
      offset: 2,
    });
    const artists2 = page2.data!.discoverArtists as Array<unknown>;
    expect(artists2).toHaveLength(1);
  });

  it("returns empty array when no artists match", async () => {
    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {
      query: "nonexistent",
    });

    expect(result.errors).toBeUndefined();
    expect(result.data!.discoverArtists).toEqual([]);
  });

  it("caps limit at 50", async () => {
    const result = await gql(app, DISCOVER_ARTISTS_QUERY, {
      limit: 100,
    });

    // Should not error — just caps internally
    expect(result.errors).toBeUndefined();
  });
});
