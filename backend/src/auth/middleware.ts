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
    } catch {
      // Invalid token — continue as unauthenticated
    }
  }
  await next();
}
