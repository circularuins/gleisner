import "dotenv/config";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
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
export const db = drizzle(client);

/** Close the shared DB connection. Call in afterAll to prevent pool exhaustion. */
export async function closeTestDb(): Promise<void> {
  await client.end();
}

let app: ReturnType<typeof createTestApp> | null = null;
let initialized = false;

function createTestApp() {
  const schema = builder.toSchema();
  const yoga = createYoga<{ authUser?: AuthUser }>({
    schema,
    maskedErrors: false,
  });

  const hono = new Hono<{ Variables: { authUser?: AuthUser } }>();
  hono.use(authMiddleware);
  hono.on(["GET", "POST"], "/graphql", async (c) => {
    const authUser = c.get("authUser");
    const response = await yoga.handleRequest(c.req.raw, { authUser });
    return response;
  });
  return hono;
}

/**
 * Returns a singleton test app instance. Assumes serial test execution
 * (vitest fileParallelism: false) — not safe for parallel test files.
 */
export async function getTestApp() {
  if (!initialized) {
    await initJwtKeys();
    initialized = true;
  }
  if (!app) {
    app = createTestApp();
  }
  return app;
}

export async function gql(
  testApp: ReturnType<typeof createTestApp>,
  query: string,
  variables?: Record<string, unknown>,
  token?: string,
) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await testApp.request("/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  });
  return res.json() as Promise<{
    data?: Record<string, unknown>;
    errors?: Array<{ message: string }>;
  }>;
}

export const SIGNUP_MUTATION = `
  mutation Signup($email: String!, $password: String!, $username: String!, $birthYearMonth: String!) {
    signup(email: $email, password: $password, username: $username, birthYearMonth: $birthYearMonth) {
      token
      user { id }
    }
  }
`;

export const REGISTER_ARTIST_MUTATION = `
  mutation RegisterArtist($artistUsername: String!, $displayName: String!) {
    registerArtist(artistUsername: $artistUsername, displayName: $displayName) {
      id artistUsername
    }
  }
`;

export const CREATE_TRACK_MUTATION = `
  mutation CreateTrack($name: String!, $color: String!) {
    createTrack(name: $name, color: $color) {
      id name color
    }
  }
`;

export const CREATE_POST_MUTATION = `
  mutation CreatePost($trackId: String!, $mediaType: MediaType!) {
    createPost(trackId: $trackId, mediaType: $mediaType) {
      id
    }
  }
`;

export async function signupAndGetTokenAndId(
  testApp: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
) {
  const result = await gql(testApp, SIGNUP_MUTATION, {
    email,
    password: "password123",
    username,
    birthYearMonth: "1990-01",
  });
  const signup = result.data!.signup as { token: string; user: { id: string } };
  return { token: signup.token, userId: signup.user.id };
}

export async function signupAndGetToken(
  testApp: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
) {
  const { token } = await signupAndGetTokenAndId(testApp, email, username);
  return token;
}

export async function signupAndRegisterArtist(
  testApp: ReturnType<typeof createTestApp>,
  email: string,
  username: string,
  artistUsername: string,
) {
  const token = await signupAndGetToken(testApp, email, username);
  await gql(
    testApp,
    REGISTER_ARTIST_MUTATION,
    { artistUsername, displayName: `Artist ${artistUsername}` },
    token,
  );
  return token;
}

export const CREATE_CHILD_MUTATION = `
  mutation CreateChildAccount($username: String!, $displayName: String, $birthYearMonth: String!, $guardianPassword: String!) {
    createChildAccount(username: $username, displayName: $displayName, birthYearMonth: $birthYearMonth, guardianPassword: $guardianPassword) {
      id username displayName birthYearMonth isChildAccount
    }
  }
`;

export const SWITCH_TO_CHILD_MUTATION = `
  mutation SwitchToChild($childId: String!) {
    switchToChild(childId: $childId) {
      token
      user { id username isChildAccount }
    }
  }
`;

export const SWITCH_BACK_MUTATION = `
  mutation SwitchBackToGuardian {
    switchBackToGuardian {
      token
      user { id username isChildAccount }
    }
  }
`;

export const MY_CHILDREN_QUERY = `
  query MyChildren {
    myChildren { id username displayName birthYearMonth createdAt }
  }
`;

export async function signupAndCreateChild(
  testApp: ReturnType<typeof createTestApp>,
  guardianEmail: string,
  guardianUsername: string,
  childUsername: string,
  birthYearMonth: string = "2020-01",
) {
  const { token: guardianToken, userId: guardianId } =
    await signupAndGetTokenAndId(testApp, guardianEmail, guardianUsername);
  const result = await gql(
    testApp,
    CREATE_CHILD_MUTATION,
    {
      username: childUsername,
      displayName: `Child ${childUsername}`,
      birthYearMonth,
      guardianPassword: "password123",
    },
    guardianToken,
  );
  const child = result.data!.createChildAccount as {
    id: string;
    username: string;
  };
  return {
    guardianToken,
    guardianId,
    childId: child.id,
    childUsername: child.username,
  };
}

export async function switchToChildAndGetToken(
  testApp: ReturnType<typeof createTestApp>,
  guardianToken: string,
  childId: string,
) {
  const result = await gql(
    testApp,
    SWITCH_TO_CHILD_MUTATION,
    { childId },
    guardianToken,
  );
  return (result.data!.switchToChild as { token: string }).token;
}

export async function createPostForTest(
  testApp: ReturnType<typeof createTestApp>,
  token: string,
) {
  const trackResult = await gql(
    testApp,
    CREATE_TRACK_MUTATION,
    { name: `Track_${crypto.randomUUID().slice(0, 8)}`, color: "#FF0000" },
    token,
  );
  const trackId = (trackResult.data!.createTrack as { id: string }).id;

  const postResult = await gql(
    testApp,
    CREATE_POST_MUTATION,
    { trackId, mediaType: "text" },
    token,
  );
  return (postResult.data!.createPost as { id: string }).id;
}
