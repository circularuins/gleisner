import { Hono } from "hono";
import { logger } from "hono/logger";
import { serve } from "@hono/node-server";
import { env } from "./env.js";
import { health } from "./routes/health.js";
import { yoga } from "./graphql/index.js";

const app = new Hono();

app.use(logger());
app.route("/", health);
app.on(["GET", "POST"], "/graphql", async (c) => {
  const response = await yoga.handleRequest(c.req.raw, {});
  return response;
});

console.log(`Gleisner API listening on port ${env.PORT}`);

serve({
  fetch: app.fetch,
  port: env.PORT,
});
