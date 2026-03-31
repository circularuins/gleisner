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
