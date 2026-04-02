import { describe, it, expect, beforeAll, vi } from "vitest";
import { initJwtKeys, signToken, verifyToken } from "../jwt.js";

describe("JWT", () => {
  beforeAll(async () => {
    await initJwtKeys();
  });

  it("signs and verifies a token (round-trip)", async () => {
    const userId = "test-user-id";
    const token = await signToken(userId);
    const result = await verifyToken(token);
    expect(result.userId).toBe(userId);
    expect(result.guardianId).toBeUndefined();
  });

  it("signs and verifies a token with guardianId", async () => {
    const userId = "child-user-id";
    const guardianId = "guardian-user-id";
    const token = await signToken(userId, { guardianId });
    const result = await verifyToken(token);
    expect(result.userId).toBe(userId);
    expect(result.guardianId).toBe(guardianId);
  });

  it("omits guardianId when not provided in opts", async () => {
    const token = await signToken("user-1", {});
    const result = await verifyToken(token);
    expect(result.userId).toBe("user-1");
    expect(result.guardianId).toBeUndefined();
  });

  it("rejects an invalid token", async () => {
    await expect(verifyToken("invalid.token.here")).rejects.toThrow();
  });
});

describe("JWT production guard", () => {
  it("throws if keys are missing in production", async () => {
    vi.resetModules();
    vi.doMock("../../env.js", () => ({
      env: { NODE_ENV: "production" },
    }));
    const { initJwtKeys: initFresh } = await import("../jwt.js");
    await expect(initFresh()).rejects.toThrow(
      "JWT_PRIVATE_KEY and JWT_PUBLIC_KEY must be set in production",
    );
    vi.doUnmock("../../env.js");
  });
});
