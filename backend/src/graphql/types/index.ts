import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { users } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
import { UserType, userColumns } from "./user.js";
import "./auth.js";
import "./artist.js";
import "./track.js";
import "./post.js";
import "./reaction.js";
// Comments are disabled for Phase 0 to avoid 電気通信事業法 "通信の媒介" implications.
// Re-enable by restoring this import after legal review (Phase 1+).
// import "./comment.js";
import "./connection.js";
import "./constellation.js";
import "./follow.js";
import "./tune-in.js";
import "./artist-link.js";
import "./artist-milestone.js";
import "./genre.js";
import "./analytics.js";
import "./invite.js";
import "./guardian.js";
import "./media.js";

builder.queryType({
  fields: (t) => ({
    hello: t.string({
      resolve: () => "Gleisner API is running",
    }),
    me: t.field({
      type: UserType,
      nullable: true,
      resolve: async (_parent, _args, ctx) => {
        if (!ctx.authUser) return null;
        const [user] = await db
          .select(userColumns)
          .from(users)
          .where(eq(users.id, ctx.authUser.userId))
          .limit(1);
        return user ?? null;
      },
    }),
  }),
});
