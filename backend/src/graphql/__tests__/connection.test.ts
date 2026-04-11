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
      id
    }
  }
`;

const CREATE_POST_MUTATION = `
  mutation CreatePost($trackId: String!, $mediaType: MediaType!) {
    createPost(trackId: $trackId, mediaType: $mediaType) {
      id
    }
  }
`;

const UPDATE_POST_MUTATION = `
  mutation UpdatePost($id: String!, $visibility: String) {
    updatePost(id: $id, visibility: $visibility) {
      id visibility
    }
  }
`;

const CREATE_CONNECTION_MUTATION = `
  mutation CreateConnection(
    $sourceId: String!,
    $targetId: String!,
    $connectionType: ConnectionType!,
    $groupId: String
  ) {
    createConnection(
      sourceId: $sourceId,
      targetId: $targetId,
      connectionType: $connectionType,
      groupId: $groupId
    ) {
      id connectionType groupId createdAt
    }
  }
`;

const DELETE_CONNECTION_MUTATION = `
  mutation DeleteConnection($id: String!) {
    deleteConnection(id: $id) {
      id connectionType
    }
  }
`;

const CONNECTIONS_QUERY = `
  query Connections($postId: String!) {
    connections(postId: $postId) {
      id connectionType groupId
      source { id }
      target { id }
    }
  }
`;

const POST_WITH_CONNECTIONS_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id
      outgoingConnections {
        id connectionType
        target { id }
      }
      incomingConnections {
        id connectionType
        source { id }
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

async function createPostForTest(
  app: ReturnType<typeof createTestApp>,
  token: string,
  trackId?: string,
) {
  if (!trackId) {
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: `Track_${crypto.randomUUID().slice(0, 8)}`, color: "#FF0000" },
      token,
    );
    trackId = (trackResult.data!.createTrack as { id: string }).id;
  }

  const postResult = await gql(
    app,
    CREATE_POST_MUTATION,
    { trackId, mediaType: "thought" },
    token,
  );
  return (postResult.data!.createPost as { id: string }).id;
}

describe("Connection GraphQL integration", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  describe("createConnection", () => {
    it("creates a connection successfully", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cn1@example.com",
        "cnuser1",
        "cnartist1",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const conn = result.data!.createConnection as Record<string, unknown>;
      expect(conn.id).toBeDefined();
      expect(conn.connectionType).toBe("reference");
      expect(conn.groupId).toBeNull();
      expect(conn.createdAt).toBeDefined();
    });

    it("creates a connection with groupId", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cn2@example.com",
        "cnuser2",
        "cnartist2",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);
      const groupId = "00000000-0000-0000-0000-000000000001";

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "remix", groupId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const conn = result.data!.createConnection as Record<string, unknown>;
      expect(conn.connectionType).toBe("remix");
      expect(conn.groupId).toBe(groupId);
    });

    it("allows connecting to another user's post", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "cn3a@example.com",
        "cnuser3a",
        "cnartist3a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "cn3b@example.com",
        "cnuser3b",
        "cnartist3b",
      );
      const sourceId = await createPostForTest(app, token1);
      const targetId = await createPostForTest(app, token2);

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reply" },
        token1,
      );

      expect(result.errors).toBeUndefined();
      const conn = result.data!.createConnection as Record<string, unknown>;
      expect(conn.connectionType).toBe("reply");
    });

    it("rejects self-reference", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cn4@example.com",
        "cnuser4",
        "cnartist4",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postId, targetId: postId, connectionType: "reference" },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Source and target posts must be different",
      );
    });

    it("rejects when source post is not owned by user", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "cn5a@example.com",
        "cnuser5a",
        "cnartist5a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "cn5b@example.com",
        "cnuser5b",
        "cnartist5b",
      );
      const otherPostId = await createPostForTest(app, token1);
      const myPostId = await createPostForTest(app, token2);

      // token2 tries to create connection with token1's post as source
      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        {
          sourceId: otherPostId,
          targetId: myPostId,
          connectionType: "reference",
        },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Source post not found");
    });

    it("rejects when target post does not exist", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cn6@example.com",
        "cnuser6",
        "cnartist6",
      );
      const sourceId = await createPostForTest(app, token);

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        {
          sourceId,
          targetId: "00000000-0000-0000-0000-000000000000",
          connectionType: "reference",
        },
        token,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Target post not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_CONNECTION_MUTATION, {
        sourceId: "00000000-0000-0000-0000-000000000000",
        targetId: "00000000-0000-0000-0000-000000000001",
        connectionType: "reference",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("rejects connection to another user's draft post", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "cn7a@example.com",
        "cnuser7a",
        "cnartist7a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "cn7b@example.com",
        "cnuser7b",
        "cnartist7b",
      );

      const sourceId = await createPostForTest(app, token1);
      const targetId = await createPostForTest(app, token2);

      // Make target post a draft
      await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: targetId, visibility: "draft" },
        token2,
      );

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token1,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Target post not found");
    });

    it("allows connection to own draft post", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cn8@example.com",
        "cnuser8",
        "cnartist8",
      );

      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      // Make target post a draft
      await gql(
        app,
        UPDATE_POST_MUTATION,
        { id: targetId, visibility: "draft" },
        token,
      );

      const result = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );

      expect(result.errors).toBeUndefined();
      expect(
        (result.data!.createConnection as { connectionType: string })
          .connectionType,
      ).toBe("reference");
    });
  });

  describe("deleteConnection", () => {
    it("deletes own connection", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "dc1@example.com",
        "dcuser1",
        "dcartist1",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      const createResult = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );
      const connId = (createResult.data!.createConnection as { id: string }).id;

      const result = await gql(
        app,
        DELETE_CONNECTION_MUTATION,
        { id: connId },
        token,
      );

      expect(result.errors).toBeUndefined();
      const conn = result.data!.deleteConnection as Record<string, unknown>;
      expect(conn.connectionType).toBe("reference");

      // Verify it's gone
      const queryResult = await gql(app, CONNECTIONS_QUERY, {
        postId: sourceId,
      });
      expect(queryResult.data!.connections).toEqual([]);
    });

    it("rejects delete by non-owner of source post", async () => {
      const token1 = await signupAndRegisterArtist(
        app,
        "dc2a@example.com",
        "dcuser2a",
        "dcartist2a",
      );
      const token2 = await signupAndRegisterArtist(
        app,
        "dc2b@example.com",
        "dcuser2b",
        "dcartist2b",
      );
      const sourceId = await createPostForTest(app, token1);
      const targetId = await createPostForTest(app, token1);

      const createResult = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token1,
      );
      const connId = (createResult.data!.createConnection as { id: string }).id;

      const result = await gql(
        app,
        DELETE_CONNECTION_MUTATION,
        { id: connId },
        token2,
      );

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Connection not found");
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, DELETE_CONNECTION_MUTATION, {
        id: "00000000-0000-0000-0000-000000000000",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });
  });

  describe("connections query", () => {
    it("returns connections for a post (as source and target)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cq1@example.com",
        "cquser1",
        "cqartist1",
      );
      const postA = await createPostForTest(app, token);
      const postB = await createPostForTest(app, token);
      const postC = await createPostForTest(app, token);

      // A → B (outgoing from A)
      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postA, targetId: postB, connectionType: "reference" },
        token,
      );
      // C → A (incoming to A)
      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postC, targetId: postA, connectionType: "reply" },
        token,
      );

      const result = await gql(app, CONNECTIONS_QUERY, { postId: postA });

      expect(result.errors).toBeUndefined();
      const connections = result.data!.connections as Array<
        Record<string, unknown>
      >;
      expect(connections).toHaveLength(2);
    });

    it("returns empty array for post with no connections", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cq2@example.com",
        "cquser2",
        "cqartist2",
      );
      const postId = await createPostForTest(app, token);

      const result = await gql(app, CONNECTIONS_QUERY, { postId });

      expect(result.errors).toBeUndefined();
      expect(result.data!.connections).toEqual([]);
    });
  });

  describe("Post.outgoingConnections and Post.incomingConnections", () => {
    it("returns connections via post query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "pc1@example.com",
        "pcuser1",
        "pcartist1",
      );
      const postA = await createPostForTest(app, token);
      const postB = await createPostForTest(app, token);
      const postC = await createPostForTest(app, token);

      // A → B
      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postA, targetId: postB, connectionType: "evolution" },
        token,
      );
      // C → A
      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId: postC, targetId: postA, connectionType: "remix" },
        token,
      );

      const result = await gql(app, POST_WITH_CONNECTIONS_QUERY, {
        id: postA,
      });

      expect(result.errors).toBeUndefined();
      const post = result.data!.post as Record<string, unknown>;

      const outgoing = post.outgoingConnections as Array<
        Record<string, unknown>
      >;
      expect(outgoing).toHaveLength(1);
      expect(outgoing[0].connectionType).toBe("evolution");
      expect((outgoing[0].target as { id: string }).id).toBe(postB);

      const incoming = post.incomingConnections as Array<
        Record<string, unknown>
      >;
      expect(incoming).toHaveLength(1);
      expect(incoming[0].connectionType).toBe("remix");
      expect((incoming[0].source as { id: string }).id).toBe(postC);
    });
  });

  describe("Connection.source and Connection.target fields", () => {
    it("returns source and target posts via connections query", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "cr1@example.com",
        "cruser1",
        "crartist1",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );

      const result = await gql(app, CONNECTIONS_QUERY, { postId: sourceId });

      expect(result.errors).toBeUndefined();
      const connections = result.data!.connections as Array<
        Record<string, unknown>
      >;
      expect(connections).toHaveLength(1);
      const conn = connections[0];
      expect((conn.source as { id: string }).id).toBe(sourceId);
      expect((conn.target as { id: string }).id).toBe(targetId);
    });
  });

  describe("unique constraint", () => {
    it("rejects duplicate connection (same source, target, type)", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "uc1@example.com",
        "ucuser1",
        "ucartist1",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      // First creation succeeds
      const result1 = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );
      expect(result1.errors).toBeUndefined();

      // Duplicate creation fails
      const result2 = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );
      expect(result2.errors).toBeDefined();
    });

    it("allows same pair with different connection type", async () => {
      const token = await signupAndRegisterArtist(
        app,
        "uc2@example.com",
        "ucuser2",
        "ucartist2",
      );
      const sourceId = await createPostForTest(app, token);
      const targetId = await createPostForTest(app, token);

      const result1 = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reference" },
        token,
      );
      expect(result1.errors).toBeUndefined();

      const result2 = await gql(
        app,
        CREATE_CONNECTION_MUTATION,
        { sourceId, targetId, connectionType: "reply" },
        token,
      );
      expect(result2.errors).toBeUndefined();
    });
  });
});
