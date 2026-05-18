/**
 * Activity heatmap authorization matrix (Idea 032).
 *
 * Verifies that `Artist.activitySeries` and `Artist.lastPostedAt` enforce the
 * exact same authorization chain as `recentPosts` / `artistPosts`. The pulse
 * beacon and star calendar must never reveal activity that the post
 * resolvers would hide; otherwise the timestamp / count surface becomes a
 * side channel for private posts and child accounts (#250 sec-1 analogue).
 *
 * Coverage:
 *   - Layer 1: artists.profileVisibility (public / private + tuned-in / private + non-tuned-in)
 *   - Layer 0: users.profileVisibility (public / private)
 *   - Post visibility: 'public' vs 'draft' — non-self viewers only see public
 *   - Track scope: trackId IS NOT NULL (unassigned posts excluded, matches recentPosts #67)
 *   - Deep path: myTuneIns → TuneInType.artist → activitySeries / lastPostedAt
 *   - Discover prefetch: lastPostedAt is filtered to public + public-author + assigned
 */
import { describe, it, expect, beforeAll, beforeEach, afterAll } from "vitest";
import "dotenv/config";
import { sql } from "drizzle-orm";
import {
  closeTestDb,
  db,
  getTestApp,
  gql,
  signupAndCreateChild,
  signupAndGetTokenAndId,
  switchToChildAndGetToken,
  CREATE_POST_MUTATION,
  CREATE_TRACK_MUTATION,
  REGISTER_ARTIST_MUTATION,
} from "./helpers.js";

type App = Awaited<ReturnType<typeof getTestApp>>;

const UPDATE_ME_MUTATION = `
  mutation UpdateMe($profileVisibility: String) {
    updateMe(profileVisibility: $profileVisibility) { id profileVisibility }
  }
`;

const UPDATE_ARTIST_VISIBILITY_MUTATION = `
  mutation UpdateArtist($profileVisibility: String) {
    updateArtist(profileVisibility: $profileVisibility) { id profileVisibility }
  }
`;

const TOGGLE_TUNE_IN_MUTATION = `
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) { createdAt }
  }
`;

const ARTIST_ACTIVITY_QUERY = `
  query ArtistActivity($username: String!) {
    artist(username: $username) {
      id
      activitySeries { date count }
      lastPostedAt
    }
  }
`;

const MY_TUNE_INS_ACTIVITY_QUERY = `
  query MyTuneInsActivity {
    myTuneIns {
      artist {
        id
        artistUsername
        activitySeries { date count }
        lastPostedAt
      }
    }
  }
`;

const DISCOVER_ARTISTS_QUERY = `
  query DiscoverArtists {
    discoverArtists { id artistUsername lastPostedAt }
  }
`;

interface AuthorFixture {
  token: string;
  userId: string;
  artistId: string;
  artistUsername: string;
  trackId: string;
}

async function createPublicArtistWithTrack(
  app: App,
  email: string,
  username: string,
  artistUsername: string,
): Promise<AuthorFixture> {
  const { token, userId } = await signupAndGetTokenAndId(app, email, username);
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
    { name: `Track-${username}`, color: "#FF0000" },
    token,
  );
  const trackId = (trackResp.data!.createTrack as { id: string }).id;
  return { token, userId, artistId, artistUsername, trackId };
}

async function createPost(
  app: App,
  token: string,
  trackId: string,
  body: string,
  visibility: "public" | "draft" = "public",
): Promise<string> {
  const resp = await gql(
    app,
    CREATE_POST_MUTATION,
    { trackId, mediaType: "thought", body, visibility },
    token,
  );
  if (resp.errors) {
    throw new Error(`createPost failed: ${JSON.stringify(resp.errors)}`);
  }
  return (resp.data!.createPost as { id: string }).id;
}

async function setUserPrivate(app: App, token: string): Promise<void> {
  const resp = await gql(
    app,
    UPDATE_ME_MUTATION,
    { profileVisibility: "private" },
    token,
  );
  if (resp.errors) {
    throw new Error(`setUserPrivate failed: ${JSON.stringify(resp.errors)}`);
  }
}

async function setArtistPrivate(app: App, token: string): Promise<void> {
  const resp = await gql(
    app,
    UPDATE_ARTIST_VISIBILITY_MUTATION,
    { profileVisibility: "private" },
    token,
  );
  if (resp.errors) {
    throw new Error(`setArtistPrivate failed: ${JSON.stringify(resp.errors)}`);
  }
}

describe("artist activity heatmap authorization (Idea 032)", () => {
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

  describe("public artist + public user (baseline)", () => {
    it("anon viewer sees activitySeries and lastPostedAt for public posts", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await createPost(app, author.token, author.trackId, "post two");

      const resp = await gql(app, ARTIST_ACTIVITY_QUERY, {
        username: author.artistUsername,
      });
      expect(resp.errors).toBeUndefined();
      const artist = resp.data!.artist as {
        activitySeries: Array<{ date: string; count: number }>;
        lastPostedAt: string | null;
      };
      expect(artist.activitySeries).toHaveLength(1);
      expect(artist.activitySeries[0].count).toBe(2);
      expect(artist.lastPostedAt).not.toBeNull();
    });

    it("excludes draft posts for non-self viewers", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "public", "public");
      await createPost(app, author.token, author.trackId, "draft", "draft");

      const resp = await gql(app, ARTIST_ACTIVITY_QUERY, {
        username: author.artistUsername,
      });
      const artist = resp.data!.artist as {
        activitySeries: Array<{ count: number }>;
      };
      expect(artist.activitySeries[0].count).toBe(1);
    });

    it("self viewer sees draft posts in their own count", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "public", "public");
      await createPost(app, author.token, author.trackId, "draft", "draft");

      const resp = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        author.token,
      );
      const artist = resp.data!.artist as {
        activitySeries: Array<{ count: number }>;
      };
      expect(artist.activitySeries[0].count).toBe(2);
    });
  });

  describe("private artist (Layer 1)", () => {
    it("non-tuned-in viewer cannot see activity at all", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await setArtistPrivate(app, author.token);

      // Anon viewer: artist query returns null entirely, so activity is unreachable
      const respAnon = await gql(app, ARTIST_ACTIVITY_QUERY, {
        username: author.artistUsername,
      });
      expect(respAnon.data!.artist).toBeNull();

      // Authed third party: same — checkArtistAccess gates the artist query
      const { token: otherToken } = await signupAndGetTokenAndId(
        app,
        "bob@test.com",
        "bob",
      );
      const respOther = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        otherToken,
      );
      expect(respOther.data!.artist).toBeNull();
    });

    it("tuned-in viewer sees public posts only, not drafts", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "public", "public");
      await createPost(app, author.token, author.trackId, "draft", "draft");
      await setArtistPrivate(app, author.token);

      const { token: fanToken } = await signupAndGetTokenAndId(
        app,
        "fan@test.com",
        "fan",
      );
      await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId: author.artistId },
        fanToken,
      );

      const resp = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        fanToken,
      );
      const artist = resp.data!.artist as {
        activitySeries: Array<{ count: number }>;
      };
      expect(artist).not.toBeNull();
      expect(artist.activitySeries[0].count).toBe(1);
    });
  });

  describe("private user / child author (Layer 0)", () => {
    it("private adult author hidden from anon viewer", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await setUserPrivate(app, author.token);

      const resp = await gql(app, ARTIST_ACTIVITY_QUERY, {
        username: author.artistUsername,
      });
      const artist = resp.data!.artist as {
        activitySeries: Array<unknown>;
        lastPostedAt: string | null;
      };
      // Artist row still resolvable (artists.profileVisibility=public by default),
      // but activity is blanked because the *user* is private.
      expect(artist.activitySeries).toEqual([]);
      expect(artist.lastPostedAt).toBeNull();
    });

    it("private adult author still sees their own activity (self path)", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await setUserPrivate(app, author.token);

      const resp = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        author.token,
      );
      const artist = resp.data!.artist as {
        activitySeries: Array<{ count: number }>;
        lastPostedAt: string | null;
      };
      expect(artist.activitySeries[0].count).toBe(1);
      expect(artist.lastPostedAt).not.toBeNull();
    });

    it("child author's activity hidden from third party even when artist is public", async () => {
      const { guardianToken, childId } = await signupAndCreateChild(
        app,
        "guardian@test.com",
        "guardian",
        "kiddo",
      );
      const childToken = await switchToChildAndGetToken(
        app,
        guardianToken,
        childId,
      );
      const artistResp = await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername: "kiddo_artist", displayName: "Kiddo Artist" },
        childToken,
      );
      const trackResp = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Kiddo Track", color: "#00FF00" },
        childToken,
      );
      const trackId = (trackResp.data!.createTrack as { id: string }).id;
      await createPost(app, childToken, trackId, "child post");

      // Even an anon viewer should see empty activity. (artist row may be
      // unreachable depending on Tier setting, but if reachable the
      // activity must be empty.)
      void (artistResp.data!.registerArtist as { id: string });
      const resp = await gql(app, ARTIST_ACTIVITY_QUERY, {
        username: "kiddo_artist",
      });
      const artist = resp.data!.artist;
      if (artist !== null) {
        const a = artist as {
          activitySeries: unknown[];
          lastPostedAt: string | null;
        };
        expect(a.activitySeries).toEqual([]);
        expect(a.lastPostedAt).toBeNull();
      }
    });
  });

  describe("track scope (unassigned posts excluded)", () => {
    it("trackId=NULL posts are not counted", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      // Detach the post from the track by deleting the track (ON DELETE SET NULL)
      await db.execute(sql`UPDATE posts SET track_id = NULL`);

      const resp = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        author.token,
      );
      const artist = resp.data!.artist as {
        activitySeries: unknown[];
        lastPostedAt: string | null;
      };
      expect(artist.activitySeries).toEqual([]);
      expect(artist.lastPostedAt).toBeNull();
    });
  });

  describe("deep path (#250 sec-1 analogue)", () => {
    it("myTuneIns → artist → activitySeries respects auth on tuned-in private artist", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "public", "public");
      await createPost(app, author.token, author.trackId, "draft", "draft");
      await setArtistPrivate(app, author.token);

      const { token: fanToken } = await signupAndGetTokenAndId(
        app,
        "fan@test.com",
        "fan",
      );
      await gql(
        app,
        TOGGLE_TUNE_IN_MUTATION,
        { artistId: author.artistId },
        fanToken,
      );

      const resp = await gql(app, MY_TUNE_INS_ACTIVITY_QUERY, {}, fanToken);
      const tuneIns = resp.data!.myTuneIns as Array<{
        artist: {
          artistUsername: string;
          activitySeries: Array<{ count: number }>;
          lastPostedAt: string | null;
        };
      }>;
      expect(tuneIns).toHaveLength(1);
      // Drafts must NOT leak through the deep path either — both
      // activitySeries.count and lastPostedAt are reached via the same
      // `resolveActivityAccess` helper, but assert both explicitly so a
      // future split of the helper into per-field auth paths cannot
      // silently regress one without the other.
      expect(tuneIns[0].artist.activitySeries[0].count).toBe(1);
      expect(tuneIns[0].artist.lastPostedAt).not.toBeNull();
    });
  });

  describe("discoverArtists prefetch", () => {
    it("returns lastPostedAt filtered to public posts only", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "public", "public");
      // A later draft must NOT advance lastPostedAt for non-self viewers.
      await createPost(app, author.token, author.trackId, "draft", "draft");

      const resp = await gql(app, DISCOVER_ARTISTS_QUERY);
      const artistsRet = resp.data!.discoverArtists as Array<{
        artistUsername: string;
        lastPostedAt: string | null;
      }>;
      const target = artistsRet.find(
        (a) => a.artistUsername === author.artistUsername,
      );
      expect(target?.lastPostedAt).not.toBeNull();
      // The latest *public* post timestamp is what should be returned; we
      // can't compare exact times, but lastPostedAt must match the public
      // post (first one), not the draft. Verifying via the per-artist
      // resolver from a third-party viewer should yield the same value.
      const { token: otherToken } = await signupAndGetTokenAndId(
        app,
        "carol@test.com",
        "carol",
      );
      const detail = await gql(
        app,
        ARTIST_ACTIVITY_QUERY,
        { username: author.artistUsername },
        otherToken,
      );
      const detailArtist = detail.data!.artist as { lastPostedAt: string };
      expect(target!.lastPostedAt).toBe(detailArtist.lastPostedAt);
    });

    it("returns null lastPostedAt when author has only drafts", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "draft", "draft");

      const resp = await gql(app, DISCOVER_ARTISTS_QUERY);
      const artistsRet = resp.data!.discoverArtists as Array<{
        artistUsername: string;
        lastPostedAt: string | null;
      }>;
      const target = artistsRet.find(
        (a) => a.artistUsername === author.artistUsername,
      );
      expect(target?.lastPostedAt).toBeNull();
    });

    it("does not list private artists at all (no row, no prefetch)", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await setArtistPrivate(app, author.token);

      const resp = await gql(app, DISCOVER_ARTISTS_QUERY);
      const artistsRet = resp.data!.discoverArtists as Array<{
        artistUsername: string;
      }>;
      // The whole row is omitted from discoverArtists — pulse beacon can
      // never be rendered for a private artist because the artist isn't
      // listed in the first place.
      expect(
        artistsRet.find((a) => a.artistUsername === author.artistUsername),
      ).toBeUndefined();
    });

    it("does not leak private user activity via prefetch", async () => {
      const author = await createPublicArtistWithTrack(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      await createPost(app, author.token, author.trackId, "post one");
      await setUserPrivate(app, author.token);

      const resp = await gql(app, DISCOVER_ARTISTS_QUERY);
      const artistsRet = resp.data!.discoverArtists as Array<{
        artistUsername: string;
        lastPostedAt: string | null;
      }>;
      const target = artistsRet.find(
        (a) => a.artistUsername === author.artistUsername,
      );
      expect(target?.lastPostedAt).toBeNull();
    });
  });
});
