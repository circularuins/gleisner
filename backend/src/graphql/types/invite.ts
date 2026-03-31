import { GraphQLError } from "graphql";
import crypto from "node:crypto";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { invites } from "../../db/schema/index.js";
import { eq, desc, sql } from "drizzle-orm";

const MAX_INVITES_PER_USER = 10;

const InviteType = builder.objectRef<{
  id: string;
  code: string;
  email: string | null;
  createdBy: string | null;
  usedBy: string | null;
  usedAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
}>("Invite");

InviteType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    code: t.exposeString("code"),
    email: t.exposeString("email", { nullable: true }),
    usedBy: t.exposeID("usedBy", { nullable: true }),
    usedAt: t.string({
      nullable: true,
      resolve: (inv) => inv.usedAt?.toISOString() ?? null,
    }),
    expiresAt: t.string({
      nullable: true,
      resolve: (inv) => inv.expiresAt?.toISOString() ?? null,
    }),
    createdAt: t.string({
      resolve: (inv) => inv.createdAt.toISOString(),
    }),
    isUsed: t.boolean({
      resolve: (inv) => inv.usedBy !== null,
    }),
  }),
});

builder.mutationFields((t) => ({
  createInvite: t.field({
    type: InviteType,
    args: {
      email: t.arg.string(),
      expiresInDays: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      if (args.email != null && args.email.length > 255) {
        throw new GraphQLError("Email must be 255 characters or less");
      }

      // Enforce per-user invite limit
      const [{ count }] = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(invites)
        .where(eq(invites.createdBy, ctx.authUser.userId));
      if (count >= MAX_INVITES_PER_USER) {
        throw new GraphQLError(
          `You can create up to ${MAX_INVITES_PER_USER} invite codes`,
        );
      }

      const code = crypto.randomBytes(10).toString("hex");
      const expiresAt =
        args.expiresInDays != null
          ? new Date(Date.now() + args.expiresInDays * 24 * 60 * 60 * 1000)
          : null;

      const [invite] = await db
        .insert(invites)
        .values({
          code,
          email: args.email ?? null,
          createdBy: ctx.authUser.userId,
          expiresAt,
        })
        .returning();

      return invite;
    },
  }),
}));

builder.queryFields((t) => ({
  // email is shown in plaintext — acceptable because users only see
  // their own invites (filtered by createdBy = authUser.userId)
  myInvites: t.field({
    type: [InviteType],
    resolve: async (_parent, _args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      return db
        .select()
        .from(invites)
        .where(eq(invites.createdBy, ctx.authUser.userId))
        .orderBy(desc(invites.createdAt))
        .limit(50);
    },
  }),
}));
