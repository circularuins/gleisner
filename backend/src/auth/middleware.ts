import type { Context, Next } from "hono";
import { verifyToken } from "./jwt.js";

export interface AuthUser {
  userId: string;
}

// Store auth user in Hono context variables
export async function authMiddleware(
  c: Context,
  next: Next,
): Promise<void | Response> {
  const header = c.req.header("Authorization");
  if (header?.startsWith("Bearer ")) {
    try {
      const token = header.slice(7);
      const { userId } = await verifyToken(token);
      c.set("authUser", { userId } satisfies AuthUser);
    } catch (err) {
      // Invalid/expired token — log for security monitoring, continue as unauthenticated
      // Sanitize header values to prevent log injection
      const rawIp = c.req.header("x-forwarded-for") ?? "unknown";
      const ip = rawIp
        .split(",")[0]
        .trim()
        .replace(/[\r\n]/g, "");
      const reason =
        err instanceof Error
          ? err.message.slice(0, 100).replace(/[\r\n]/g, "")
          : "unknown";
      console.warn(`[auth] token rejected: ip=${ip} reason=${reason}`);
    }
  }
  await next();
}
