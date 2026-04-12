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
      user { id email }
    }
  }
`;

const ME_QUERY = `
  query Me {
    me {
      id email username did
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

const REACTIONS_WITH_USER_QUERY = `
  query Reactions($postId: String!) {
    reactions(postId: $postId) {
      id
      user { id username did displayName bio avatarUrl createdAt }
    }
  }
`;

const REACTIONS_WITH_EMAIL_QUERY = `
  query Reactions($postId: String!) {
    reactions(postId: $postId) {
      id
      user { id email }
    }
  }
`;

const COMMENTS_WITH_EMAIL_QUERY = `
  query Comments($postId: String!) {
    comments(postId: $postId) {
      id
      user { id email }
    }
  }
`;

const POST_AUTHOR_EMAIL_QUERY = `
  query Post($id: String!) {
    post(id: $id) {
      id
      author { id email }
    }
  }
`;

const FOLLOWERS_WITH_EMAIL_QUERY = `
  query Followers($userId: String!) {
    followers(userId: $userId) {
      follower { id email }
    }
  }
`;

async function signupAndGetTokenAndId(
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
  const signup = result.data!.signup as { token: string; user: { id: string } };
  return { token: signup.token, userId: signup.user.id };
}

describe("PublicUserType email exposure prevention", () => {
  let app: ReturnType<typeof createTestApp>;

  beforeAll(async () => {
    await initJwtKeys();
    app = createTestApp();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  it("me query returns email (UserType)", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "pub1@example.com",
      "pubuser1",
    );

    const result = await gql(app, ME_QUERY, {}, token);

    expect(result.errors).toBeUndefined();
    const me = result.data!.me as Record<string, unknown>;
    expect(me.email).toBe("pub1@example.com");
    expect(me.username).toBe("pubuser1");
  });

  it("signup returns email (UserType via AuthPayload)", async () => {
    const result = await gql(app, SIGNUP_MUTATION, {
      email: "pub2@example.com",
      password: "password123",
      username: "pubuser2",
      birthYearMonth: "1990-01",
    });

    expect(result.errors).toBeUndefined();
    const user = (result.data!.signup as { user: Record<string, unknown> })
      .user;
    expect(user.email).toBe("pub2@example.com");
  });

  it("reactions query user does not expose email (PublicUserType)", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "pub3@example.com",
      "pubuser3",
    );
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "pubart3", displayName: "Artist 3" },
      token,
    );
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: "Track", color: "#FF0000" },
      token,
    );
    const trackId = (trackResult.data!.createTrack as { id: string }).id;
    const postResult = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postId = (postResult.data!.createPost as { id: string }).id;

    // Add a reaction
    await gql(
      app,
      `mutation { toggleReaction(postId: "${postId}", emoji: "👍") { id } }`,
      {},
      token,
    );

    // Query reactions — email should not be available on PublicUser
    const result = await gql(
      app,
      REACTIONS_WITH_EMAIL_QUERY,
      { postId },
      token,
    );

    expect(result.errors).toBeDefined();
    expect(result.errors![0].message).toContain("email");
  });

  it("reactions query user exposes public fields", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "pub4@example.com",
      "pubuser4",
    );
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "pubart4", displayName: "Artist 4" },
      token,
    );
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: "Track", color: "#FF0000" },
      token,
    );
    const trackId = (trackResult.data!.createTrack as { id: string }).id;
    const postResult = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postId = (postResult.data!.createPost as { id: string }).id;

    await gql(
      app,
      `mutation { toggleReaction(postId: "${postId}", emoji: "👍") { id } }`,
      {},
      token,
    );

    const result = await gql(app, REACTIONS_WITH_USER_QUERY, { postId }, token);

    expect(result.errors).toBeUndefined();
    const reactions = result.data!.reactions as Array<Record<string, unknown>>;
    expect(reactions).toHaveLength(1);
    const user = reactions[0].user as Record<string, unknown>;
    expect(user.username).toBe("pubuser4");
    expect(user.id).toBeDefined();
    expect(user.did).toBeDefined();
    expect(user.createdAt).toBeDefined();
  });

  it("comments query user does not expose email", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "pub5@example.com",
      "pubuser5",
    );
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "pubart5", displayName: "Artist 5" },
      token,
    );
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: "Track", color: "#FF0000" },
      token,
    );
    const trackId = (trackResult.data!.createTrack as { id: string }).id;
    const postResult = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postId = (postResult.data!.createPost as { id: string }).id;

    await gql(
      app,
      `mutation { createComment(postId: "${postId}", body: "test") { id } }`,
      {},
      token,
    );

    const result = await gql(app, COMMENTS_WITH_EMAIL_QUERY, { postId });

    expect(result.errors).toBeDefined();
    expect(result.errors![0].message).toContain("email");
  });

  it("post author does not expose email", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "pub6@example.com",
      "pubuser6",
    );
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "pubart6", displayName: "Artist 6" },
      token,
    );
    const trackResult = await gql(
      app,
      CREATE_TRACK_MUTATION,
      { name: "Track", color: "#FF0000" },
      token,
    );
    const trackId = (trackResult.data!.createTrack as { id: string }).id;
    const postResult = await gql(
      app,
      CREATE_POST_MUTATION,
      { trackId, mediaType: "thought" },
      token,
    );
    const postId = (postResult.data!.createPost as { id: string }).id;

    const result = await gql(app, POST_AUTHOR_EMAIL_QUERY, { id: postId });

    expect(result.errors).toBeDefined();
    expect(result.errors![0].message).toContain("email");
  });

  it("followers query does not expose email", async () => {
    const { userId: userId1 } = await signupAndGetTokenAndId(
      app,
      "pub7a@example.com",
      "pubuser7a",
    );
    const { token: token2 } = await signupAndGetTokenAndId(
      app,
      "pub7b@example.com",
      "pubuser7b",
    );

    // user2 follows user1
    await gql(
      app,
      `mutation { toggleFollow(userId: "${userId1}") { createdAt } }`,
      {},
      token2,
    );

    const result = await gql(app, FOLLOWERS_WITH_EMAIL_QUERY, {
      userId: userId1,
    });

    expect(result.errors).toBeDefined();
    expect(result.errors![0].message).toContain("email");
  });
});
