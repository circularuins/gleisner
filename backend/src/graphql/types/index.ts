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
// Re-enable after legal review (Phase 1+) by following the checklist in Issue #221:
//   1. Uncomment this import
//   2. Remove the individual `import "../types/comment.js"` from comment.test.ts
//   3. Change `it.skip` back to `it` in public-user.test.ts
//      ("comments query user does not expose email")
// Issue #221 also tracks pre-existing security/perf gaps (missing auth check on
// `comments`, `db.select()` leaking columns, N+1 in `Post.comments`) that must
// be addressed in the same restoration PR.
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
