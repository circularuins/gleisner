import { Hono } from "hono";
import { client } from "../db/index.js";

const health = new Hono();

health.get("/health", async (c) => {
  try {
    await client`SELECT 1`;
    return c.json({ status: "ok", db: "connected" });
  } catch {
    return c.json({ status: "error", db: "disconnected" }, 503);
  }
});

export { health };
