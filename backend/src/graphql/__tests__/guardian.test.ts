import { describe, it, expect, beforeAll, beforeEach, afterAll } from "vitest";
import { sql } from "drizzle-orm";
import {
  getTestApp,
  gql,
  db,
  closeTestDb,
  signupAndGetTokenAndId,
  signupAndGetToken,
  CREATE_CHILD_MUTATION,
  SWITCH_TO_CHILD_MUTATION,
  SWITCH_BACK_MUTATION,
  MY_CHILDREN_QUERY,
  signupAndCreateChild,
  switchToChildAndGetToken,
  SIGNUP_MUTATION,
  REGISTER_ARTIST_MUTATION,
} from "./helpers.js";

let app: Awaited<ReturnType<typeof getTestApp>>;

beforeAll(async () => {
  app = await getTestApp();
});
afterAll(async () => {
  await closeTestDb();
});
beforeEach(async () => {
  await db.execute(sql`TRUNCATE users CASCADE`);
});

const ME_QUERY = `query Me { me { id username email isChildAccount birthYearMonth profileVisibility } }`;
const UPDATE_ME_MUTATION = `
  mutation UpdateMe($profileVisibility: String, $displayName: String) {
    updateMe(profileVisibility: $profileVisibility, displayName: $displayName) {
      id profileVisibility displayName
    }
  }
`;

// =============================================================================
// createChildAccount
// =============================================================================

describe("createChildAccount", () => {
  it("creates a child account successfully", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "parent@test.com",
      "parent",
    );
    const result = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "mychild",
        displayName: "My Child",
        birthYearMonth: "2020-06",
        guardianPassword: "password123",
      },
      token,
    );

    expect(result.errors).toBeUndefined();
    const child = result.data!.createChildAccount as Record<string, unknown>;
    expect(child.username).toBe("mychild");
    expect(child.displayName).toBe("My Child");
    expect(child.birthYearMonth).toBe("2020-06");
    expect(child.isChildAccount).toBe(true);
  });

  it("rejects wrong guardian password", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");
    const result = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2020-01",
        guardianPassword: "wrongpassword",
      },
      token,
    );
    expect(result.errors?.[0]?.message).toBe("Invalid password");
  });

  it("rejects unauthenticated requests", async () => {
    const result = await gql(app, CREATE_CHILD_MUTATION, {
      username: "child1",
      birthYearMonth: "2020-01",
      guardianPassword: "password123",
    });
    expect(result.errors?.[0]?.message).toBe("Authentication required");
  });

  it("prevents child from creating child accounts", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    const result = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "grandchild",
        birthYearMonth: "2023-01",
        guardianPassword: "password123",
      },
      childToken,
    );
    expect(result.errors?.[0]?.message).toBe(
      "Child accounts cannot create child accounts",
    );
  });

  it("enforces maximum child limit", async () => {
    const { token } = await signupAndGetTokenAndId(
      app,
      "parent@test.com",
      "parent",
    );

    // Create 10 children (the max)
    for (let i = 0; i < 10; i++) {
      const result = await gql(
        app,
        CREATE_CHILD_MUTATION,
        {
          username: `child${i}`,
          birthYearMonth: "2020-01",
          guardianPassword: "password123",
        },
        token,
      );
      expect(result.errors).toBeUndefined();
    }

    // 11th should fail
    const result = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child10",
        birthYearMonth: "2020-01",
        guardianPassword: "password123",
      },
      token,
    );
    expect(result.errors?.[0]?.message).toBe(
      "Maximum of 10 child accounts allowed",
    );
  });

  it("rejects duplicate username", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");
    await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "taken",
        birthYearMonth: "2020-01",
        guardianPassword: "password123",
      },
      token,
    );
    const result = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "taken",
        birthYearMonth: "2020-01",
        guardianPassword: "password123",
      },
      token,
    );
    expect(result.errors?.[0]?.message).toBe("Username already taken");
  });

  it("validates birthYearMonth format", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");

    // Invalid format
    const r1 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2020",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r1.errors?.[0]?.message).toBe(
      "birthYearMonth must be in YYYY-MM format",
    );

    // Invalid month
    const r2 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2020-13",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r2.errors?.[0]?.message).toBe(
      "birthYearMonth must be in YYYY-MM format",
    );

    // Future year
    const r3 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2099-01",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r3.errors?.[0]?.message).toBe("Invalid birth year");

    // Too old
    const r4 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "1899-01",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r4.errors?.[0]?.message).toBe("Invalid birth year");

    // Month zero
    const r5 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2020-00",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r5.errors?.[0]?.message).toBe(
      "birthYearMonth must be in YYYY-MM format",
    );

    // Single digit month (missing leading zero)
    const r6 = await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        birthYearMonth: "2020-1",
        guardianPassword: "password123",
      },
      token,
    );
    expect(r6.errors?.[0]?.message).toBe(
      "birthYearMonth must be in YYYY-MM format",
    );
  });

  it("sets child profile to private by default", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );
    const result = await gql(app, ME_QUERY, {}, childToken);
    const me = result.data!.me as Record<string, unknown>;
    expect(me.profileVisibility).toBe("private");
  });
});

// =============================================================================
// switchToChild / switchBackToGuardian
// =============================================================================

describe("switchToChild / switchBackToGuardian", () => {
  it("switches to child and back (round-trip)", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );

    // Switch to child
    const switchResult = await gql(
      app,
      SWITCH_TO_CHILD_MUTATION,
      { childId },
      guardianToken,
    );
    expect(switchResult.errors).toBeUndefined();
    const switchData = switchResult.data!.switchToChild as {
      token: string;
      user: { id: string; username: string; isChildAccount: boolean };
    };
    expect(switchData.user.username).toBe("child1");
    expect(switchData.user.isChildAccount).toBe(true);

    // Verify child JWT works
    const meResult = await gql(app, ME_QUERY, {}, switchData.token);
    expect((meResult.data!.me as Record<string, unknown>).username).toBe(
      "child1",
    );

    // Child email should be null (placeholder hidden)
    expect((meResult.data!.me as Record<string, unknown>).email).toBeNull();

    // Switch back to guardian
    const backResult = await gql(
      app,
      SWITCH_BACK_MUTATION,
      {},
      switchData.token,
    );
    expect(backResult.errors).toBeUndefined();
    const backData = backResult.data!.switchBackToGuardian as {
      token: string;
      user: { id: string; username: string; isChildAccount: boolean };
    };
    expect(backData.user.username).toBe("parent");
    expect(backData.user.isChildAccount).toBe(false);

    // Verify guardian JWT works
    const meResult2 = await gql(app, ME_QUERY, {}, backData.token);
    expect((meResult2.data!.me as Record<string, unknown>).username).toBe(
      "parent",
    );
  });

  it("rejects switch to another user's child", async () => {
    const { childId } = await signupAndCreateChild(
      app,
      "parent1@test.com",
      "parent1",
      "child1",
    );
    const otherToken = await signupAndGetToken(
      app,
      "parent2@test.com",
      "parent2",
    );

    const result = await gql(
      app,
      SWITCH_TO_CHILD_MUTATION,
      { childId },
      otherToken,
    );
    expect(result.errors?.[0]?.message).toBe("Child account not found");
  });

  it("rejects switchBack without guardian context (gid)", async () => {
    const token = await signupAndGetToken(app, "user@test.com", "user1");
    const result = await gql(app, SWITCH_BACK_MUTATION, {}, token);
    expect(result.errors?.[0]?.message).toBe(
      "Not in child mode — no guardian to switch back to",
    );
  });

  it("rejects switch to nonexistent child", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");
    const result = await gql(
      app,
      SWITCH_TO_CHILD_MUTATION,
      { childId: "00000000-0000-0000-0000-000000000000" },
      token,
    );
    expect(result.errors?.[0]?.message).toBe("Child account not found");
  });

  it("rejects switch while already in child mode", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );

    // Create a second child
    await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child2",
        birthYearMonth: "2021-01",
        guardianPassword: "password123",
      },
      guardianToken,
    );

    // Switch to first child
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    // Try to switch to second child while in child mode
    const result = await gql(
      app,
      SWITCH_TO_CHILD_MUTATION,
      { childId: "anything" },
      childToken,
    );
    expect(result.errors?.[0]?.message).toBe(
      "Cannot switch to child while already in child mode",
    );
  });
});

// =============================================================================
// myChildren
// =============================================================================

describe("myChildren", () => {
  it("returns empty array when no children", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");
    const result = await gql(app, MY_CHILDREN_QUERY, {}, token);
    expect(result.errors).toBeUndefined();
    expect(result.data!.myChildren).toEqual([]);
  });

  it("returns multiple children", async () => {
    const token = await signupAndGetToken(app, "parent@test.com", "parent");

    await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child1",
        displayName: "Child One",
        birthYearMonth: "2020-01",
        guardianPassword: "password123",
      },
      token,
    );
    await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child2",
        displayName: "Child Two",
        birthYearMonth: "2022-06",
        guardianPassword: "password123",
      },
      token,
    );
    await gql(
      app,
      CREATE_CHILD_MUTATION,
      {
        username: "child3",
        displayName: "Child Three",
        birthYearMonth: "2018-12",
        guardianPassword: "password123",
      },
      token,
    );

    const result = await gql(app, MY_CHILDREN_QUERY, {}, token);
    expect(result.errors).toBeUndefined();
    const children = result.data!.myChildren as Array<Record<string, unknown>>;
    expect(children).toHaveLength(3);
    const usernames = children.map((c) => c.username).sort();
    expect(usernames).toEqual(["child1", "child2", "child3"]);
  });

  it("returns empty array when called by a child", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );
    const result = await gql(app, MY_CHILDREN_QUERY, {}, childToken);
    expect(result.errors).toBeUndefined();
    expect(result.data!.myChildren).toEqual([]);
  });
});

// =============================================================================
// updateMe child restrictions
// =============================================================================

describe("updateMe child restrictions", () => {
  it("prevents child from changing profileVisibility", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    const result = await gql(
      app,
      UPDATE_ME_MUTATION,
      { profileVisibility: "public" },
      childToken,
    );
    expect(result.errors?.[0]?.message).toBe(
      "Child accounts cannot change profile visibility",
    );
  });

  it("allows child to update displayName", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    const result = await gql(
      app,
      UPDATE_ME_MUTATION,
      { displayName: "New Name" },
      childToken,
    );
    expect(result.errors).toBeUndefined();
    expect((result.data!.updateMe as Record<string, unknown>).displayName).toBe(
      "New Name",
    );
  });
});

// =============================================================================
// registerArtist child restriction
// =============================================================================

describe("child artist restrictions", () => {
  it("allows child to register as artist with forced private visibility", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    const result = await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "childartist", displayName: "Child Artist" },
      childToken,
    );
    expect(result.errors).toBeUndefined();

    // Verify artist is forced private
    const artistResult = await gql(
      app,
      `query { artist(username: "childartist") { profileVisibility } }`,
      {},
      childToken,
    );
    expect(
      (artistResult.data!.artist as Record<string, unknown>).profileVisibility,
    ).toBe("private");
  });

  it("allows child to change artist visibility (guardian-managed)", async () => {
    const { guardianToken, childId } = await signupAndCreateChild(
      app,
      "parent@test.com",
      "parent",
      "child1",
    );
    const childToken = await switchToChildAndGetToken(
      app,
      guardianToken,
      childId,
    );

    // Register as artist first
    await gql(
      app,
      REGISTER_ARTIST_MUTATION,
      { artistUsername: "childartist", displayName: "Child Artist" },
      childToken,
    );

    // Guardian (via child JWT) can change artist visibility to public
    const result = await gql(
      app,
      `mutation { updateArtist(profileVisibility: "public") { profileVisibility } }`,
      {},
      childToken,
    );
    expect(result.errors).toBeUndefined();
    expect(
      (result.data!.updateArtist as Record<string, unknown>).profileVisibility,
    ).toBe("public");
  });
});

// =============================================================================
// login / signup child defenses
// =============================================================================

describe("login / signup child defenses", () => {
  it("rejects login with child placeholder email", async () => {
    await signupAndCreateChild(app, "parent@test.com", "parent", "child1");

    const result = await gql(
      app,
      `
      mutation Login($email: String!, $password: String!) {
        login(email: $email, password: $password) { token }
      }
    `,
      { email: "child1@child.gleisner.local", password: "anypassword" },
    );
    expect(result.errors?.[0]?.message).toBe("Invalid credentials");
  });

  it("rejects signup with @child.gleisner.local email", async () => {
    const result = await gql(app, SIGNUP_MUTATION, {
      email: "hacker@child.gleisner.local",
      password: "password123",
      username: "hacker",
      birthYearMonth: "1990-01",
    });
    expect(result.errors?.[0]?.message).toBe("Invalid email format");
  });

  it("rejects self-signup for under-13 (COPPA)", async () => {
    const currentYear = new Date().getFullYear();
    const result = await gql(app, SIGNUP_MUTATION, {
      email: "kid@test.com",
      password: "password123",
      username: "kiduser",
      birthYearMonth: `${currentYear - 10}-01`,
    });
    expect(result.errors?.[0]?.message).toContain(
      "You must be at least 13 to create an account",
    );
  });

  it("allows self-signup for 13+", async () => {
    const currentYear = new Date().getFullYear();
    const result = await gql(app, SIGNUP_MUTATION, {
      email: "teen@test.com",
      password: "password123",
      username: "teenuser",
      birthYearMonth: `${currentYear - 14}-01`,
    });
    expect(result.errors).toBeUndefined();
    expect(result.data?.signup).toBeTruthy();
  });
});
