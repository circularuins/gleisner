/**
 * Artist / track read authorization (Issue #350 + sec-3 + G5).
 *
 * Verifies that tracks owned by an artist whose `artists.profileVisibility`
 * (Layer 1) is `"private"` are hidden from third parties on every
 * track-returning resolver, and that malformed UUIDs are rejected before
 * reaching the DB.
 *
 * Boundary matrix (per resolver):
 *   1. anon viewer × public artist          → visible (regression)
 *   2. anon viewer × private artist         → hidden
 *   3. authed other × private artist        → hidden
 *   4. authed self × own private artist     → visible
 *   5. authed tunedIn × private artist      → visible
 *
 * The `tunedIn` row is reached by tuning in while the artist is still public,
 * then flipping the artist private — `toggleTuneIn` does not yet enforce
 * artist accessibility (PR-C / sec-2 territory), so this state is reachable
 * without test gymnastics.
 *
 * Scope note: PR-B keeps `checkArtistAccess` unchanged, so child-owned
 * (`users.guardianId IS NOT NULL`) artists with `profileVisibility = 'public'`
 * still leak their tracks here. PR-C extends `checkArtistAccess` with the
 * guardian check (sec-2 + #358) and closes that path. Adding child-author
 * cases to this file before PR-C lands would falsely advertise coverage.
 */
import { describe, it, expect, beforeAll, beforeEach, afterAll } from "vitest";
import "dotenv/config";
import { sql } from "drizzle-orm";
import {
  closeTestDb,
  db,
  getTestApp,
  gql,
  signupAndGetToken,
  CREATE_TRACK_MUTATION,
  REGISTER_ARTIST_MUTATION,
} from "./helpers.js";

// updateArtist is the production path for flipping artists.profileVisibility,
// kept locally so this file stays self-contained (helpers.ts intentionally
// keeps its surface narrow).
const UPDATE_ARTIST_MUTATION = `
  mutation UpdateArtist($profileVisibility: String) {
    updateArtist(profileVisibility: $profileVisibility) {
      id profileVisibility
    }
  }
`;

const TUNE_IN_TOGGLE_MUTATION = `
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) { createdAt }
  }
`;

const TRACK_QUERY = `
  query Track($id: String!) {
    track(id: $id) { id name }
  }
`;

const TRACKS_QUERY = `
  query Tracks($artistUsername: String!) {
    tracks(artistUsername: $artistUsername) { id name }
  }
`;

// ArtistType.tracks is reached via the public `artist(username)` resolver,
// which is itself gated by `artists.profileVisibility`. The defense-in-depth
// guard added in PR-B fires when an authed viewer can still resolve
// ArtistType (e.g. self-view of a private artist) but downstream callers
// shouldn't see tracks they aren't entitled to.
const ARTIST_TRACKS_QUERY = `
  query ArtistTracks($username: String!) {
    artist(username: $username) {
      id
      tracks { id name }
    }
  }
`;

const POST_BY_ID_QUERY = `
  query Post($id: String!) {
    post(id: $id) { id }
  }
`;

type App = Awaited<ReturnType<typeof getTestApp>>;

interface ArtistFixture {
  token: string;
  userId: string;
  username: string;
  artistUsername: string;
  artistId: string;
  trackId: string;
  trackName: string;
}

async function createPublicArtistWithTrack(
  app: App,
  email: string,
  username: string,
  artistUsername: string,
  trackName = `Track-${username}`,
): Promise<ArtistFixture> {
  const signupResp = await gql(
    app,
    `mutation($email: String!, $password: String!, $username: String!, $birthYearMonth: String!) {
       signup(email: $email, password: $password, username: $username, birthYearMonth: $birthYearMonth) {
         token user { id }
       }
     }`,
    {
      email,
      password: "password123",
      username,
      birthYearMonth: "1990-01",
    },
  );
  const signup = signupResp.data!.signup as {
    token: string;
    user: { id: string };
  };
  const token = signup.token;
  const userId = signup.user.id;

  const artistResp = await gql(
    app,
    REGISTER_ARTIST_MUTATION,
    { artistUsername, displayName: `Artist ${artistUsername}` },
    token,
  );
  const artistId = (artistResp.data!.registerArtist as { id: string }).id;

  const trackResp = await gql(
    app,
    CREATE_TRACK_MUTATION,
    { name: trackName, color: "#FF00AA" },
    token,
  );
  const trackId = (trackResp.data!.createTrack as { id: string }).id;

  return {
    token,
    userId,
    username,
    artistUsername,
    artistId,
    trackId,
    trackName,
  };
}

async function setArtistPrivate(token: string, app: App): Promise<void> {
  const resp = await gql(
    app,
    UPDATE_ARTIST_MUTATION,
    { profileVisibility: "private" },
    token,
  );
  if (resp.errors) {
    throw new Error(
      `Failed to set artist private: ${JSON.stringify(resp.errors)}`,
    );
  }
}

describe("artist / track read authorization (Issue #350 + sec-3)", () => {
  let app: App;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestDb();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("track(id) — #350", () => {
    it("anon viewer sees track of public artist (regression baseline)", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const resp = await gql(app, TRACK_QUERY, { id: owner.trackId });
      const track = resp.data!.track as { id: string } | null;
      expect(track?.id).toBe(owner.trackId);
    });

    it("anon viewer gets null when track belongs to a private artist", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(app, TRACK_QUERY, { id: owner.trackId });
      // null (not an error) keeps the response shape identical to "track does
      // not exist", closing the enumeration oracle on track UUIDs.
      expect(resp.data!.track).toBeNull();
      expect(resp.errors).toBeUndefined();
    });

    it("authed third-party viewer also gets null for private artist", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const otherToken = await signupAndGetToken(
        app,
        "stranger@test.com",
        "stranger",
      );
      const resp = await gql(
        app,
        TRACK_QUERY,
        { id: owner.trackId },
        otherToken,
      );
      expect(resp.data!.track).toBeNull();
    });

    it("self viewer sees own private artist's track", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(
        app,
        TRACK_QUERY,
        { id: owner.trackId },
        owner.token,
      );
      expect((resp.data!.track as { id: string } | null)?.id).toBe(
        owner.trackId,
      );
    });

    it("tunedIn viewer sees track even after artist goes private", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      // Tune in while the artist is still public; toggleTuneIn does not yet
      // enforce artist visibility (PR-C / sec-2). The authorization fix here
      // is purely on the read path.
      const tuneInResp = await gql(
        app,
        TUNE_IN_TOGGLE_MUTATION,
        { artistId: owner.artistId },
        fanToken,
      );
      expect(tuneInResp.errors).toBeUndefined();

      await setArtistPrivate(owner.token, app);

      const resp = await gql(app, TRACK_QUERY, { id: owner.trackId }, fanToken);
      expect((resp.data!.track as { id: string } | null)?.id).toBe(
        owner.trackId,
      );
    });

    it("returns null for a syntactically valid but unknown UUID", async () => {
      // Distinct from the malformed-UUID rejection path: a well-formed UUID
      // that doesn't match any track must still come back as null (not an
      // error) so the enumeration oracle stays closed.
      const resp = await gql(app, TRACK_QUERY, {
        id: "00000000-0000-4000-8000-000000000000",
      });
      expect(resp.data!.track).toBeNull();
      expect(resp.errors).toBeUndefined();
    });
  });

  describe("tracks(artistUsername) — sec-3", () => {
    it("anon viewer sees tracks of public artist (regression baseline)", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const resp = await gql(app, TRACKS_QUERY, {
        artistUsername: owner.artistUsername,
      });
      const list = resp.data!.tracks as Array<{ id: string }>;
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe(owner.trackId);
    });

    it("anon viewer sees empty list for private artist", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(app, TRACKS_QUERY, {
        artistUsername: owner.artistUsername,
      });
      expect(resp.data!.tracks).toEqual([]);
    });

    it("authed third-party viewer sees empty list for private artist", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const otherToken = await signupAndGetToken(
        app,
        "stranger@test.com",
        "stranger",
      );
      const resp = await gql(
        app,
        TRACKS_QUERY,
        { artistUsername: owner.artistUsername },
        otherToken,
      );
      expect(resp.data!.tracks).toEqual([]);
    });

    it("self viewer sees own private artist's tracks", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(
        app,
        TRACKS_QUERY,
        { artistUsername: owner.artistUsername },
        owner.token,
      );
      const list = resp.data!.tracks as Array<{ id: string }>;
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe(owner.trackId);
    });

    it("tunedIn viewer sees tracks of artist that turned private", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      await gql(
        app,
        TUNE_IN_TOGGLE_MUTATION,
        { artistId: owner.artistId },
        fanToken,
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(
        app,
        TRACKS_QUERY,
        { artistUsername: owner.artistUsername },
        fanToken,
      );
      const list = resp.data!.tracks as Array<{ id: string }>;
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe(owner.trackId);
    });

    it("nonexistent artist also returns empty list (parity with private)", async () => {
      // Same response shape as "private artist" — the enumeration oracle
      // would be reopened if the response distinguished missing from private.
      const resp = await gql(app, TRACKS_QUERY, {
        artistUsername: "ghost_username_that_doesnt_exist",
      });
      expect(resp.data!.tracks).toEqual([]);
      expect(resp.errors).toBeUndefined();
    });
  });

  describe("ArtistType.tracks (defense-in-depth)", () => {
    it("anon viewer sees tracks via artist(username) for public artist (regression)", async () => {
      const owner = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const resp = await gql(app, ARTIST_TRACKS_QUERY, {
        username: owner.artistUsername,
      });
      const artist = resp.data!.artist as {
        tracks: Array<{ id: string }>;
      } | null;
      expect(artist).not.toBeNull();
      expect(artist!.tracks).toHaveLength(1);
      expect(artist!.tracks[0].id).toBe(owner.trackId);
    });

    it("self viewer sees own private artist's tracks via the field resolver", async () => {
      // Self-view is the path that actually exercises the field-level guard:
      // top-level `artist(username)` continues to return the artist for the
      // owner, so ArtistType.tracks is reached and must check accessibility
      // again rather than returning the row blindly.
      const owner = await createPublicArtistWithTrack(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setArtistPrivate(owner.token, app);

      const resp = await gql(
        app,
        ARTIST_TRACKS_QUERY,
        { username: owner.artistUsername },
        owner.token,
      );
      const artist = resp.data!.artist as {
        tracks: Array<{ id: string }>;
      } | null;
      expect(artist).not.toBeNull();
      expect(artist!.tracks).toHaveLength(1);
      expect(artist!.tracks[0].id).toBe(owner.trackId);
    });
  });

  describe("validateUUID rejection (G5)", () => {
    // Resolver-level smoke tests; the exhaustive coverage of validateUUID
    // itself lives in `validators.test.ts`.
    it("track(id) rejects malformed UUID with 'Invalid track id'", async () => {
      const resp = await gql(app, TRACK_QUERY, { id: "not-a-uuid" });
      expect(resp.errors).toBeDefined();
      expect(resp.errors![0].message).toBe("Invalid track id");
      // Wire-level contract: clients should branch on `extensions.code`,
      // not the message string. Asserting it here catches regressions
      // where yoga's error masking strips the code in production mode.
      expect(resp.errors![0].extensions?.code).toBe("BAD_USER_INPUT");
    });

    it("post(id) rejects malformed UUID with 'Invalid post id'", async () => {
      const resp = await gql(app, POST_BY_ID_QUERY, {
        id: "00000000-bogus-bogus-bogus-not-a-uuid",
      });
      expect(resp.errors).toBeDefined();
      expect(resp.errors![0].message).toBe("Invalid post id");
      expect(resp.errors![0].extensions?.code).toBe("BAD_USER_INPUT");
    });
  });
});
