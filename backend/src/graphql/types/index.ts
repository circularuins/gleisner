import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { users } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
import { UserType } from "./user.js";
import "./auth.js";

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
        const [user] = await db.select()
          .from(users)
          .where(eq(users.id, ctx.authUser.userId))
          .limit(1);
        return user ?? null;
      },
    }),
  }),
});
