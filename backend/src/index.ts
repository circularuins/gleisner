import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { serve } from "@hono/node-server";
import { env } from "./env.js";
import { health } from "./routes/health.js";
import { yoga } from "./graphql/index.js";
import { authMiddleware, type AuthUser } from "./auth/middleware.js";
import { initJwtKeys } from "./auth/jwt.js";

type HonoEnv = { Variables: { authUser?: AuthUser } };

const app = new Hono<HonoEnv>();

app.use(logger());
app.use(
  cors({
    origin: env.CORS_ORIGIN === "*" ? "*" : env.CORS_ORIGIN.split(","),
    allowMethods: ["GET", "POST"],
    allowHeaders: ["Content-Type", "Authorization"],
  }),
);
app.use(authMiddleware);
app.route("/", health);
app.on(["GET", "POST"], "/graphql", async (c) => {
  const authUser = c.get("authUser");
  const response = await yoga.handleRequest(c.req.raw, { authUser });
  return response;
});

async function start() {
  await initJwtKeys(env.JWT_PRIVATE_KEY, env.JWT_PUBLIC_KEY);
  console.log(`Gleisner API listening on port ${env.PORT}`);
  serve({
    fetch: app.fetch,
    port: env.PORT,
  });
}

start();
