import { describe, it, expect, beforeAll } from "vitest";
import { Hono } from "hono";
import { initJwtKeys, signToken } from "../jwt.js";
import { authMiddleware, type AuthUser } from "../middleware.js";

describe("authMiddleware", () => {
  let app: Hono<{ Variables: { authUser?: AuthUser } }>;

  beforeAll(async () => {
    await initJwtKeys();

    app = new Hono<{ Variables: { authUser?: AuthUser } }>();
    app.use(authMiddleware);
    app.get("/test", (c) => {
      const authUser = c.get("authUser");
      return c.json({ authUser: authUser ?? null });
    });
  });

  it("sets authUser with valid Bearer token", async () => {
    const token = await signToken("user-123");
    const res = await app.request("/test", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const body = await res.json();
    expect(body.authUser).toEqual({ userId: "user-123" });
  });

  it("leaves authUser undefined without token", async () => {
    const res = await app.request("/test");
    const body = await res.json();
    expect(body.authUser).toBeNull();
  });

  it("leaves authUser undefined with invalid token", async () => {
    const res = await app.request("/test", {
      headers: { Authorization: "Bearer invalid.token.here" },
    });
    const body = await res.json();
    expect(body.authUser).toBeNull();
  });
});
