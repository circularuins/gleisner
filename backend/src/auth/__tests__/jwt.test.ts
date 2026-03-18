import { describe, it, expect, beforeAll } from "vitest";
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
