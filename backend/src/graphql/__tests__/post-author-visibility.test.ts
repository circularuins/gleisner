/**
 * Post author visibility hardening (Issue #250 + sec-1 + sec-4).
 *
 * Verifies that posts whose author is a child account (guardianId !== null)
 * or whose author has non-public users.profileVisibility (Layer 0) are
 * hidden from third parties across every post-returning resolver.
 *
 * Boundary matrix per resolver:
 *   1. anon viewer × public adult author       → visible
 *   2. anon viewer × private adult author      → hidden
 *   3. anon viewer × child author              → hidden
 *   4. authed viewer × self (private/child)    → visible
 *   5. authed viewer × other private           → hidden
 *
 * The recentPosts deep path (myTuneIns → TuneInType.artist → recentPosts)
 * has a dedicated test below — sec-1 made that path bypass checkArtistAccess
 * when the parent artist was prefetched without authorization.
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
  signupAndGetToken,
  switchToChildAndGetToken,
  CREATE_POST_MUTATION,
  CREATE_TRACK_MUTATION,
  REGISTER_ARTIST_MUTATION,
} from "./helpers.js";

const UPDATE_ME_MUTATION = `
  mutation UpdateMe($profileVisibility: String) {
    updateMe(profileVisibility: $profileVisibility) {
      id profileVisibility
    }
  }
`;

const POST_QUERY = `
  query Post($id: String!) {
    post(id: $id) { id author { id username } }
  }
`;

const POSTS_QUERY = `
  query Posts($trackId: String!) {
    posts(trackId: $trackId) { id author { id username } }
  }
`;

const ARTIST_POSTS_QUERY = `
  query ArtistPosts($artistId: String!) {
    artistPosts(artistId: $artistId) { id author { id username } }
  }
`;

const ARTIST_RECENT_POSTS_QUERY = `
  query ArtistRecent($username: String!) {
    artist(username: $username) {
      id
      recentPosts { id author { id username } }
    }
  }
`;

const TRACK_POSTS_QUERY = `
  query TrackPosts($trackId: String!) {
    track(id: $trackId) { id posts { id author { id username } } }
  }
`;

const TUNE_IN_TOGGLE_MUTATION = `
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) { createdAt }
  }
`;

const MY_TUNE_INS_QUERY = `
  query MyTuneIns {
    myTuneIns {
      createdAt
      artist {
        id
        recentPosts { id author { id username } }
      }
    }
  }
`;

const TOGGLE_REACTION_MUTATION = `
  mutation ToggleReaction($postId: String!, $emoji: String!) {
    toggleReaction(postId: $postId, emoji: $emoji) { id emoji }
  }
`;

const REACTIONS_QUERY = `
  query Reactions($postId: String!) {
    reactions(postId: $postId) { id emoji }
  }
`;

const CREATE_CONNECTION_MUTATION = `
  mutation CreateConnection($sourceId: String!, $targetId: String!, $connectionType: ConnectionType!) {
    createConnection(sourceId: $sourceId, targetId: $targetId, connectionType: $connectionType) {
      id
      source { id }
      target { id }
    }
  }
`;

const CONNECTIONS_QUERY = `
  query Connections($postId: String!) {
    connections(postId: $postId) {
      id
      source { id }
      target { id }
    }
  }
`;

type App = Awaited<ReturnType<typeof getTestApp>>;

interface AuthorFixture {
  token: string;
  userId: string;
  username: string;
  artistUsername: string;
  artistId: string;
  trackId: string;
  postId: string;
}

async function createAuthorWithPost(
  app: App,
  email: string,
  username: string,
  artistUsername: string,
): Promise<AuthorFixture> {
  // signup + register artist + create track + create one public post
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
    { name: `Track-${username}`, color: "#FF0000" },
    token,
  );
  const trackId = (trackResp.data!.createTrack as { id: string }).id;

  const postResp = await gql(
    app,
    CREATE_POST_MUTATION,
    { trackId, mediaType: "thought", body: `Hello from ${username}` },
    token,
  );
  const postId = (postResp.data!.createPost as { id: string }).id;

  return { token, userId, username, artistUsername, artistId, trackId, postId };
}

async function setUserPrivate(token: string, app: App): Promise<void> {
  const resp = await gql(
    app,
    UPDATE_ME_MUTATION,
    { profileVisibility: "private" },
    token,
  );
  if (resp.errors) {
    throw new Error(
      `Failed to set user private: ${JSON.stringify(resp.errors)}`,
    );
  }
}

describe("post author visibility (Issue #250)", () => {
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

  describe("public adult author (regression baseline)", () => {
    it("posts(trackId): anon viewer sees the post", async () => {
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const resp = await gql(app, POSTS_QUERY, { trackId: author.trackId });
      const list = resp.data!.posts as Array<{ id: string }>;
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe(author.postId);
    });

    it("post(id): anon viewer sees the post", async () => {
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const resp = await gql(app, POST_QUERY, { id: author.postId });
      const post = resp.data!.post as { id: string } | null;
      expect(post?.id).toBe(author.postId);
    });
  });

  describe("private adult author", () => {
    it("posts(trackId): anon viewer cannot see post", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setUserPrivate(author.token, app);

      const resp = await gql(app, POSTS_QUERY, { trackId: author.trackId });
      expect(resp.data!.posts).toEqual([]);
    });

    it("post(id): anon viewer gets null", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setUserPrivate(author.token, app);

      const resp = await gql(app, POST_QUERY, { id: author.postId });
      expect(resp.data!.post).toBeNull();
    });

    it("artistPosts: anon viewer sees empty list", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setUserPrivate(author.token, app);

      const resp = await gql(app, ARTIST_POSTS_QUERY, {
        artistId: author.artistId,
      });
      expect(resp.data!.artistPosts).toEqual([]);
    });

    it("ArtistType.recentPosts: anon viewer sees empty list when author is private", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      // Make user private. The artist row's profileVisibility is independent
      // (Layer 1) and stays public, so artist itself is still reachable.
      // recentPosts must be empty because the author (Layer 0) is hidden.
      await setUserPrivate(author.token, app);

      const resp = await gql(app, ARTIST_RECENT_POSTS_QUERY, {
        username: author.artistUsername,
      });
      const artist = resp.data!.artist as {
        id: string;
        recentPosts: Array<unknown>;
      } | null;
      expect(artist).not.toBeNull();
      expect(artist!.recentPosts).toEqual([]);
    });

    it("TrackType.posts: anon viewer sees empty list", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setUserPrivate(author.token, app);

      const resp = await gql(app, TRACK_POSTS_QUERY, {
        trackId: author.trackId,
      });
      // Private user / private artist → posts list filtered out either by
      // checkArtistAccess (artist becomes private when its user goes private?)
      // or by author visibility filter. Either way, posts should be empty.
      const track = resp.data!.track as {
        posts: Array<unknown>;
      } | null;
      // If artist itself is exposed, posts must be filtered
      if (track) {
        expect(track.posts).toEqual([]);
      } else {
        expect(track).toBeNull();
      }
    });

    it("self viewer can still see own private posts", async () => {
      const author = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      await setUserPrivate(author.token, app);

      const resp = await gql(
        app,
        POST_QUERY,
        { id: author.postId },
        author.token,
      );
      expect((resp.data!.post as { id: string } | null)?.id).toBe(
        author.postId,
      );
    });
  });

  describe("child author (ADR 019)", () => {
    async function createChildWithPost(): Promise<{
      guardianToken: string;
      childToken: string;
      childId: string;
      artistId: string;
      artistUsername: string;
      trackId: string;
      postId: string;
    }> {
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

      // Register an artist for the child (under child token)
      const artistUsername = "kiddo_artist";
      const artistResp = await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername, displayName: "Kiddo Artist" },
        childToken,
      );
      const artistId = (artistResp.data!.registerArtist as { id: string }).id;

      const trackResp = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Track-kiddo", color: "#00FF00" },
        childToken,
      );
      const trackId = (trackResp.data!.createTrack as { id: string }).id;

      const postResp = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "thought", body: "Hello from kiddo" },
        childToken,
      );
      const postId = (postResp.data!.createPost as { id: string }).id;

      return {
        guardianToken,
        childToken,
        childId,
        artistId,
        artistUsername,
        trackId,
        postId,
      };
    }

    it("post(id): anon viewer gets null (child author hidden)", async () => {
      const fix = await createChildWithPost();
      // Child's own visibility is private by default (Tier 1), but even if it
      // were public the post must still be hidden because guardianId !== null.
      const resp = await gql(app, POST_QUERY, { id: fix.postId });
      expect(resp.data!.post).toBeNull();
    });

    it("posts(trackId): anon viewer sees empty list", async () => {
      const fix = await createChildWithPost();
      const resp = await gql(app, POSTS_QUERY, { trackId: fix.trackId });
      expect(resp.data!.posts).toEqual([]);
    });

    it("artistPosts: anon viewer sees empty list", async () => {
      const fix = await createChildWithPost();
      const resp = await gql(app, ARTIST_POSTS_QUERY, {
        artistId: fix.artistId,
      });
      expect(resp.data!.artistPosts).toEqual([]);
    });

    it("child author sees their own posts via post(id)", async () => {
      const fix = await createChildWithPost();
      const resp = await gql(
        app,
        POST_QUERY,
        { id: fix.postId },
        fix.childToken,
      );
      expect((resp.data!.post as { id: string } | null)?.id).toBe(fix.postId);
    });
  });

  describe("recentPosts deep path (sec-1 regression)", () => {
    it("myTuneIns → artist.recentPosts hides private author posts", async () => {
      // Owner alice creates a public post.
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );

      // A second user bob registers as a fan and tunes in to alice.
      const bobToken = await signupAndGetToken(app, "bob@test.com", "bob_user");
      const tuneInResp = await gql(
        app,
        TUNE_IN_TOGGLE_MUTATION,
        { artistId: author.artistId },
        bobToken,
      );
      // Sanity: tune-in succeeded
      expect(tuneInResp.errors).toBeUndefined();

      // Now alice goes private.
      await setUserPrivate(author.token, app);

      // Bob fetches myTuneIns → artist → recentPosts. The deep path used to
      // bypass author visibility before sec-1; now it must return empty.
      const resp = await gql(app, MY_TUNE_INS_QUERY, undefined, bobToken);
      const tuneIns = resp.data!.myTuneIns as Array<{
        artist: { recentPosts: Array<unknown> } | null;
      }>;
      // alice's user.profileVisibility went private but artists.profileVisibility
      // stayed public, so myTuneIns still surfaces the artist row via the
      // tuneInArtistCache. recentPosts must be empty because the author is
      // now hidden by isAuthorVisibleToViewer.
      // If a future change makes private user → artist also disappear from
      // myTuneIns, the assert below will need to be relaxed; the comment is
      // intentional so the regression isn't silently weakened.
      expect(tuneIns).toHaveLength(1);
      expect(tuneIns[0].artist).not.toBeNull();
      expect(tuneIns[0].artist!.recentPosts).toEqual([]);
    });
  });

  describe("toggleReaction (sec-4)", () => {
    it("rejects reactions to private adult author posts with 'Post not found'", async () => {
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      // Make alice private AFTER fan obtained their token
      await setUserPrivate(author.token, app);

      const resp = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId: author.postId, emoji: "👍" },
        fanToken,
      );
      expect(resp.errors).toBeDefined();
      expect(resp.errors![0].message).toBe("Post not found");
    });

    it("rejects reactions to child author posts with 'Post not found'", async () => {
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
      // Child must register artist + create track before posting
      // (createPostForTest in helpers.ts assumes a registered artist).
      await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername: "kiddo_artist", displayName: "Kiddo" },
        childToken,
      );
      const trackResp = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Track-kiddo", color: "#00FF00" },
        childToken,
      );
      const trackId = (trackResp.data!.createTrack as { id: string }).id;
      const postResp = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId, mediaType: "thought", body: "child post" },
        childToken,
      );
      const postId = (postResp.data!.createPost as { id: string }).id;

      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      const resp = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId, emoji: "👍" },
        fanToken,
      );
      expect(resp.errors).toBeDefined();
      expect(resp.errors![0].message).toBe("Post not found");
    });

    it("allows reactions to public adult author posts (regression)", async () => {
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      const resp = await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId: author.postId, emoji: "👍" },
        fanToken,
      );
      expect(resp.errors).toBeUndefined();
      expect((resp.data!.toggleReaction as { emoji: string }).emoji).toBe("👍");
    });
  });

  describe("reactions(postId) query (sec-3)", () => {
    it("returns empty list for private adult author posts", async () => {
      const author = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );
      // First add a reaction while author is public
      const fanToken = await signupAndGetToken(app, "fan@test.com", "fan_user");
      await gql(
        app,
        TOGGLE_REACTION_MUTATION,
        { postId: author.postId, emoji: "👍" },
        fanToken,
      );
      // Then make author private. Existing reactions must not be enumerable.
      await setUserPrivate(author.token, app);

      const resp = await gql(
        app,
        REACTIONS_QUERY,
        { postId: author.postId },
        fanToken,
      );
      expect(resp.errors).toBeUndefined();
      expect(resp.data!.reactions).toEqual([]);
    });
  });

  describe("ConnectionObjectType.source/target (sec-2)", () => {
    it("connections(postId): hides connections where the source is a private author's post", async () => {
      // Author bob (will go private) with a post + connection to alice's post
      const bob = await createAuthorWithPost(
        app,
        "bob@test.com",
        "bob",
        "bob_artist",
      );
      const alice = await createAuthorWithPost(
        app,
        "alice@test.com",
        "alice",
        "alice_artist",
      );

      // bob creates a connection from his own post to alice's post
      const connResp = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        {
          sourceId: bob.postId,
          targetId: alice.postId,
          connectionType: "reference",
        },
        bob.token,
      );
      expect(connResp.errors).toBeUndefined();

      // Make bob private. The connection still exists but anyone querying
      // it should see source as null (bob's post is now hidden).
      await setUserPrivate(bob.token, app);

      // Anonymous viewer pulls the connections via alice's post id
      const viewResp = await gql(app, CONNECTIONS_QUERY, {
        postId: alice.postId,
      });
      const conns = viewResp.data!.connections as Array<{
        source: { id: string } | null;
        target: { id: string } | null;
      }>;
      // The connection row is still returned, but bob's post (source) is null
      const connectionToBob = conns.find((c) => c.source === null);
      expect(connectionToBob).toBeDefined();
    });

    it("createConnection: rejects targeting a child author's post with 'Target post not found'", async () => {
      // Set up child + child's post
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
      await gql(
        app,
        REGISTER_ARTIST_MUTATION,
        { artistUsername: "kiddo_artist", displayName: "Kiddo" },
        childToken,
      );
      const childTrackResp = await gql(
        app,
        CREATE_TRACK_MUTATION,
        { name: "Track-kiddo", color: "#00FF00" },
        childToken,
      );
      const childTrackId = (childTrackResp.data!.createTrack as { id: string })
        .id;
      const childPostResp = await gql(
        app,
        CREATE_POST_MUTATION,
        { trackId: childTrackId, mediaType: "thought", body: "child" },
        childToken,
      );
      const childPostId = (childPostResp.data!.createPost as { id: string }).id;

      // Adult fan with their own post tries to connect to child's post
      const fan = await createAuthorWithPost(
        app,
        "fan@test.com",
        "fan_user",
        "fan_artist",
      );
      const resp = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        {
          sourceId: fan.postId,
          targetId: childPostId,
          connectionType: "reference",
        },
        fan.token,
      );
      expect(resp.errors).toBeDefined();
      expect(resp.errors![0].message).toBe("Target post not found");
    });
  });
});
