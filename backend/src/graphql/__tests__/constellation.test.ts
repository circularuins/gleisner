import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { sql } from "drizzle-orm";
import {
  db,
  getTestApp,
  gql,
  signupAndRegisterArtist,
  createPostForTest,
  CREATE_TRACK_MUTATION,
  CREATE_POST_MUTATION,
} from "./helpers.js";

const CREATE_CONNECTION_MUTATION = `
  mutation CreateConnection($sourceId: String!, $targetId: String!, $connectionType: ConnectionType!) {
    createConnection(sourceId: $sourceId, targetId: $targetId, connectionType: $connectionType) { id }
  }
`;

const NAME_CONSTELLATION_MUTATION = `
  mutation NameConstellation($postId: String!, $name: String!) {
    nameConstellation(postId: $postId, name: $name) {
      id name anchorPostId
    }
  }
`;

const RENAME_CONSTELLATION_MUTATION = `
  mutation RenameConstellation($id: String!, $name: String!) {
    renameConstellation(id: $id, name: $name) {
      id name
    }
  }
`;

const POST_WITH_CONSTELLATION_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id
      constellation { id name anchorPostId }
    }
  }
`;

describe("Constellation GraphQL integration", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  async function setupConnectedPosts(token: string) {
    // Create track + 3 posts + 2 connections (A → B → C)
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: "TestTrack", color: "#FF0000" },
      token,
    );
    const trackId = (trackResult.data!.createTrack as { id: string }).id;

    const postA = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postB = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postC = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const idA = (postA.data!.createPost as { id: string }).id;
    const idB = (postB.data!.createPost as { id: string }).id;
    const idC = (postC.data!.createPost as { id: string }).id;

    await gql(
      app,
      CREATE_CONNECTION_MUTATION,
      { sourceId: idA, targetId: idB, connectionType: "reference" },
      token,
    );
    await gql(
      app,
      CREATE_CONNECTION_MUTATION,
      { sourceId: idB, targetId: idC, connectionType: "reference" },
      token,
    );

    return { idA, idB, idC };
  }

  describe("nameConstellation", () => {
    it("creates a new constellation", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cs1@test.com",
        "csuser1",
        "csartist1",
      );
      const { idA } = await setupConnectedPosts(token);

      const result = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "Test Constellation" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const constellation = result.data!.nameConstellation as Record<
        string,
        unknown
      >;
      expect(constellation.name).toBe("Test Constellation");
      expect(constellation.anchorPostId).toBe(idA);
    });

    it("updates existing constellation name when called from same component", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cs2@test.com",
        "csuser2",
        "csartist2",
      );
      const { idA, idC } = await setupConnectedPosts(token);

      // Name from post A
      const result1 = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "Original" },
        token,
      );
      const id1 = (result1.data!.nameConstellation as { id: string }).id;

      // Rename from post C (same constellation)
      const result2 = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idC, name: "Renamed" },
        token,
      );

      expect(result2.errors).toBeUndefined();
      const c2 = result2.data!.nameConstellation as Record<string, unknown>;
      expect(c2.id).toBe(id1); // Same constellation record
      expect(c2.name).toBe("Renamed");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, NAME_CONSTELLATION_MUTATION, {
        postId: "00000000-0000-0000-0000-000000000000",
        name: "Test",
      });
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects when post is not owned by user", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "cs3a@test.com",
        "csuser3a",
        "csartist3a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "cs3b@test.com",
        "csuser3b",
        "csartist3b",
      );
      const postId = await createPostForTest(app, token1);

      const result = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId, name: "Hijack" },
        token2,
      );
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Post not found");
    });

    it("does not allow renaming another artist's constellation", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "cs4a@test.com",
        "csuser4a",
        "csartist4a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "cs4b@test.com",
        "csuser4b",
        "csartist4b",
      );

      // Artist 1 creates posts + connection + names constellation
      const { idA } = await setupConnectedPosts(token1);
      await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "Artist1 Constellation" },
        token1,
      );

      // Artist 2 creates their own post and connects to artist 1's post
      const postB2 = await createPostForTest(app, token2);
      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postB2, targetId: idA, connectionType: "reference" },
        token2,
      );

      // Artist 2 tries to name — should create their own, not overwrite artist 1's
      const result = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: postB2, name: "Artist2 Constellation" },
        token2,
      );

      expect(result.errors).toBeUndefined();
      const c = result.data!.nameConstellation as Record<string, unknown>;
      expect(c.name).toBe("Artist2 Constellation");
      expect(c.anchorPostId).toBe(postB2); // Own anchor, not artist 1's
    });

    it("rejects empty name", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cs5@test.com",
        "csuser5",
        "csartist5",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId, name: "   " },
        token,
      );
      expect(result.errors).toBeDefined();
    });
  });

  describe("renameConstellation", () => {
    it("renames an existing constellation", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "rc1@test.com",
        "rcuser1",
        "rcartist1",
      );
      const { idA } = await setupConnectedPosts(token);

      const createResult = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "Original" },
        token,
      );
      const cId = (createResult.data!.nameConstellation as { id: string }).id;

      const result = await gql(
        app,
        RENAME_CONSTELLATION_MUTATION,
        { id: cId, name: "Updated" },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(
        (result.data!.renameConstellation as Record<string, unknown>).name,
      ).toBe("Updated");
    });

    it("rejects rename by non-owner", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "rc2a@test.com",
        "rcuser2a",
        "rcartist2a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "rc2b@test.com",
        "rcuser2b",
        "rcartist2b",
      );
      const { idA } = await setupConnectedPosts(token1);

      const createResult = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "Original" },
        token1,
      );
      const cId = (createResult.data!.nameConstellation as { id: string }).id;

      const result = await gql(
        app,
        RENAME_CONSTELLATION_MUTATION,
        { id: cId, name: "Hijacked" },
        token2,
      );
      expect(result.errors).toBeDefined();
    });
  });

  describe("Post.constellation field", () => {
    it("returns constellation for a connected post", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "pc1@test.com",
        "pcuser1",
        "pcartist1",
      );
      const { idA, idC } = await setupConnectedPosts(token);

      await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "My Constellation" },
        token,
      );

      // Query from post C — should find the constellation via BFS
      const result = await gql(
        app,
        POST_WITH_CONSTELLATION_QUERY,
        { id: idC },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      const constellation = post.constellation as Record<string, unknown>;
      expect(constellation).not.toBeNull();
      expect(constellation.name).toBe("My Constellation");
    });

    it("returns null for an unconnected post", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "pc2@test.com",
        "pcuser2",
        "pcartist2",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        POST_WITH_CONSTELLATION_QUERY,
        { id: postId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;
      expect(post.constellation).toBeNull();
    });
  });

  describe("deleteConstellation", () => {
    const DELETE_CONSTELLATION = `
      mutation DeleteConstellation($id: String!) {
        deleteConstellation(id: $id)
      }
    `;

    it("deletes an owned constellation", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "del1@test.com",
        "deluser1",
        "delartist1",
      );
      const { idA } = await setupConnectedPosts(token);

      // Name it first
      const nameResult = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "ToDelete" },
        token,
      );
      const constellationId = (
        nameResult.data!.nameConstellation as { id: string }
      ).id;

      // Delete it
      const result = await gql(
        app,
        DELETE_CONSTELLATION,
        { id: constellationId },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(result.data!.deleteConstellation).toBe(true);
    });

    it("rejects deletion by non-owner", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "del2@test.com",
        "deluser2",
        "delartist2",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "del3@test.com",
        "deluser3",
        "delartist3",
      );
      const { idA } = await setupConnectedPosts(token1);

      const nameResult = await gql(
        app,
        NAME_CONSTELLATION_MUTATION,
        { postId: idA, name: "NotYours" },
        token1,
      );
      const constellationId = (
        nameResult.data!.nameConstellation as { id: string }
      ).id;

      // Try to delete with different user
      const result = await gql(
        app,
        DELETE_CONSTELLATION,
        { id: constellationId },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("not authorized");
    });

    it("returns error for non-existent constellation", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "del4@test.com",
        "deluser4",
        "delartist4",
      );

      const result = await gql(
        app,
        DELETE_CONSTELLATION,
        { id: "00000000-0000-0000-0000-000000000000" },
        token,
      );

      expect(result.errors).toBeDefined();
    });
  });
});
