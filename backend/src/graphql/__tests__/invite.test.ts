import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
  afterAll,
  afterEach,
} from "vitest";
import { sql, eq } from "drizzle-orm";
import {
  getTestApp,
  gql,
  db,
  signupAndGetToken,
  closeTestDb,
} from "./helpers.js";
import { invites } from "../../db/schema/index.js";
import { env } from "../../env.js";

const CREATE_INVITE_MUTATION = `
  mutation CreateInvite($email: String, $expiresInDays: Int) {
    createInvite(email: $email, expiresInDays: $expiresInDays) {
      id code email isUsed expiresAt createdAt
    }
  }
`;

const MY_INVITES_QUERY = `
  query MyInvites {
    myInvites {
      id code email isUsed usedBy
    }
  }
`;

const SIGNUP_WITH_INVITE = `
  mutation Signup($email: String!, $password: String!, $username: String!, $birthYearMonth: String!, $inviteCode: String) {
    signup(email: $email, password: $password, username: $username, birthYearMonth: $birthYearMonth, inviteCode: $inviteCode) {
      token
      user { id }
    }
  }
`;

describe("Invite system", () => {
  let app: Awaited<ReturnType<typeof getTestApp>>;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestDb();
  });

  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
    await db.execute(sql`TRUNCATE invites CASCADE`);
  });

  describe("createInvite mutation", () => {
    it("creates an invite code", async () => {
      const token = await signupAndGetToken(app, "inv1@test.com", "invuser1");

      const result = await gql(app, CREATE_INVITE_MUTATION, {}, token);

      expect(result.errors).toBeUndefined();
      const invite = result.data!.createInvite as Record<string, unknown>;
      expect(invite.code).toBeDefined();
      expect((invite.code as string).length).toBe(20); // 10 bytes hex
      expect(invite.isUsed).toBe(false);
      expect(invite.email).toBeNull();
      expect(invite.expiresAt).toBeNull();
    });

    it("creates an invite with email restriction", async () => {
      const token = await signupAndGetToken(app, "inv2@test.com", "invuser2");

      const result = await gql(
        app,
        CREATE_INVITE_MUTATION,
        { email: "friend@example.com" },
        token,
      );

      expect(result.errors).toBeUndefined();
      const invite = result.data!.createInvite as Record<string, unknown>;
      expect(invite.email).toBe("friend@example.com");
    });

    it("creates an invite with expiry", async () => {
      const token = await signupAndGetToken(app, "inv3@test.com", "invuser3");

      const result = await gql(
        app,
        CREATE_INVITE_MUTATION,
        { expiresInDays: 7 },
        token,
      );

      expect(result.errors).toBeUndefined();
      const invite = result.data!.createInvite as Record<string, unknown>;
      expect(invite.expiresAt).toBeDefined();
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, CREATE_INVITE_MUTATION, {});
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Authentication required");
    });

    it("enforces per-user invite limit", async () => {
      const token = await signupAndGetToken(app, "inv4@test.com", "invuser4");

      // Create 10 invites (the limit)
      for (let i = 0; i < 10; i++) {
        const result = await gql(app, CREATE_INVITE_MUTATION, {}, token);
        expect(result.errors).toBeUndefined();
      }

      // 11th should fail
      const result = await gql(app, CREATE_INVITE_MUTATION, {}, token);
      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain("up to 10");
    });
  });

  describe("myInvites query", () => {
    it("returns invites created by the user", async () => {
      const token = await signupAndGetToken(app, "mi1@test.com", "miuser1");

      await gql(app, CREATE_INVITE_MUTATION, {}, token);
      await gql(app, CREATE_INVITE_MUTATION, { email: "a@b.com" }, token);

      const result = await gql(app, MY_INVITES_QUERY, {}, token);

      expect(result.errors).toBeUndefined();
      const list = result.data!.myInvites as Array<Record<string, unknown>>;
      expect(list).toHaveLength(2);
    });

    it("rejects unauthenticated request", async () => {
      const result = await gql(app, MY_INVITES_QUERY, {});
      expect(result.errors).toBeDefined();
    });
  });

  describe("signup with REQUIRE_INVITE=true", () => {
    const origRequireInvite = env.REQUIRE_INVITE;

    beforeEach(() => {
      // Temporarily enable invite requirement
      (env as Record<string, unknown>).REQUIRE_INVITE = true;
    });

    afterEach(() => {
      (env as Record<string, unknown>).REQUIRE_INVITE = origRequireInvite;
    });

    it("rejects signup without invite code", async () => {
      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "new1@test.com",
        password: "password123",
        username: "newuser1",
        birthYearMonth: "1990-01",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe("Invite code is required");
    });

    it("rejects signup with invalid invite code", async () => {
      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "new2@test.com",
        password: "password123",
        username: "newuser2",
        birthYearMonth: "1990-01",
        inviteCode: "nonexistent",
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Invalid or already used invite code",
      );
    });

    it("accepts signup with valid invite code", async () => {
      // Create an invite first (need a user to create it)
      (env as Record<string, unknown>).REQUIRE_INVITE = false;
      const adminToken = await signupAndGetToken(
        app,
        "admin@test.com",
        "adminuser",
      );
      (env as Record<string, unknown>).REQUIRE_INVITE = true;

      const inviteResult = await gql(
        app,
        CREATE_INVITE_MUTATION,
        {},
        adminToken,
      );
      const code = (inviteResult.data!.createInvite as { code: string }).code;

      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "new3@test.com",
        password: "password123",
        username: "newuser3",
        birthYearMonth: "1990-01",
        inviteCode: code,
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.signup).toBeDefined();

      // Verify invite is marked as used
      const [invite] = await db
        .select()
        .from(invites)
        .where(eq(invites.code, code))
        .limit(1);
      expect(invite.usedBy).not.toBeNull();
      expect(invite.usedAt).not.toBeNull();
    });

    it("rejects reuse of already-used invite code", async () => {
      (env as Record<string, unknown>).REQUIRE_INVITE = false;
      const adminToken = await signupAndGetToken(
        app,
        "admin2@test.com",
        "adminuser2",
      );
      (env as Record<string, unknown>).REQUIRE_INVITE = true;

      const inviteResult = await gql(
        app,
        CREATE_INVITE_MUTATION,
        {},
        adminToken,
      );
      const code = (inviteResult.data!.createInvite as { code: string }).code;

      // First signup succeeds
      await gql(app, SIGNUP_WITH_INVITE, {
        email: "first@test.com",
        password: "password123",
        username: "firstuser",
        birthYearMonth: "1990-01",
        inviteCode: code,
      });

      // Second signup with same code fails
      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "second@test.com",
        password: "password123",
        username: "seconduser",
        birthYearMonth: "1990-01",
        inviteCode: code,
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toBe(
        "Invalid or already used invite code",
      );
    });

    it("rejects invite code for different email", async () => {
      (env as Record<string, unknown>).REQUIRE_INVITE = false;
      const adminToken = await signupAndGetToken(
        app,
        "admin3@test.com",
        "adminuser3",
      );
      (env as Record<string, unknown>).REQUIRE_INVITE = true;

      const inviteResult = await gql(
        app,
        CREATE_INVITE_MUTATION,
        { email: "specific@test.com" },
        adminToken,
      );
      const code = (inviteResult.data!.createInvite as { code: string }).code;

      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "wrong@test.com",
        password: "password123",
        username: "wronguser",
        birthYearMonth: "1990-01",
        inviteCode: code,
      });

      expect(result.errors).toBeDefined();
      // Email mismatch is caught by the atomic UPDATE WHERE clause,
      // so the error is the generic "Invalid or already used" message
      expect(result.errors![0].message).toBe(
        "Invalid or already used invite code",
      );
    });

    it("rejects expired invite code", async () => {
      (env as Record<string, unknown>).REQUIRE_INVITE = false;
      const adminToken = await signupAndGetToken(
        app,
        "admin4@test.com",
        "adminuser4",
      );
      (env as Record<string, unknown>).REQUIRE_INVITE = true;

      // Create invite, then manually set expiresAt to the past
      const inviteResult = await gql(
        app,
        CREATE_INVITE_MUTATION,
        { expiresInDays: 1 },
        adminToken,
      );
      const code = (inviteResult.data!.createInvite as { code: string }).code;

      // Expire it manually
      await db
        .update(invites)
        .set({ expiresAt: new Date("2020-01-01") })
        .where(eq(invites.code, code));

      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "expired@test.com",
        password: "password123",
        username: "expireduser",
        birthYearMonth: "1990-01",
        inviteCode: code,
      });

      expect(result.errors).toBeDefined();
      expect(result.errors![0].message).toContain(
        "Invalid or already used invite code",
      );
    });
  });

  describe("signup with REQUIRE_INVITE=false (default)", () => {
    it("allows signup without invite code", async () => {
      const result = await gql(app, SIGNUP_WITH_INVITE, {
        email: "free1@test.com",
        password: "password123",
        username: "freeuser1",
        birthYearMonth: "1990-01",
      });

      expect(result.errors).toBeUndefined();
      expect(result.data!.signup).toBeDefined();
    });
  });
});
