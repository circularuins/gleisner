import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, tuneIns, users } from "../../db/schema/index.js";
import { and, eq, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { UserType } from "./user.js";

const TuneInType = builder.objectRef<{
  userId: string;
  artistId: string;
  createdAt: Date;
}>("TuneIn");

TuneInType.implement({
  fields: (t) => ({
    createdAt: t.string({
      resolve: (tuneIn) => tuneIn.createdAt.toISOString(),
    }),
    user: t.field({
      type: UserType,
      resolve: async (tuneIn) => {
        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, tuneIn.userId))
          .limit(1);
        return user;
      },
    }),
    artist: t.field({
      type: ArtistType,
      resolve: async (tuneIn) => {
        const [artist] = await db
          .select()
          .from(artists)
          .where(eq(artists.id, tuneIn.artistId))
          .limit(1);
        return artist;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  toggleTuneIn: t.field({
    type: TuneInType,
    nullable: true,
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Check if already tuned in
      const [existing] = await db
        .select()
        .from(tuneIns)
        .where(
          and(
            eq(tuneIns.userId, ctx.authUser.userId),
            eq(tuneIns.artistId, args.artistId),
          ),
        )
        .limit(1);

      if (existing) {
        // Tune out — use transaction for count consistency
        await db.transaction(async (tx) => {
          await tx
            .delete(tuneIns)
            .where(
              and(
                eq(tuneIns.userId, ctx.authUser!.userId),
                eq(tuneIns.artistId, args.artistId),
              ),
            );
          await tx
            .update(artists)
            .set({ tunedInCount: sql`${artists.tunedInCount} - 1` })
            .where(eq(artists.id, args.artistId));
        });
        return null;
      }

      // Tune in — use transaction for count consistency
      try {
        let result:
          | { userId: string; artistId: string; createdAt: Date }
          | undefined;
        await db.transaction(async (tx) => {
          const [tuneIn] = await tx
            .insert(tuneIns)
            .values({
              userId: ctx.authUser!.userId,
              artistId: args.artistId,
            })
            .returning();
          await tx
            .update(artists)
            .set({ tunedInCount: sql`${artists.tunedInCount} + 1` })
            .where(eq(artists.id, args.artistId));
          result = tuneIn;
        });
        return result!;
      } catch {
        throw new GraphQLError("Failed to tune in");
      }
    },
  }),
}));

builder.queryFields((t) => ({
  tuneIns: t.field({
    type: [TuneInType],
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db
        .select()
        .from(tuneIns)
        .where(eq(tuneIns.artistId, args.artistId));
    },
  }),
}));

// Add tuneIns field to ArtistType
builder.objectFields(ArtistType, (t) => ({
  tuneIns: t.field({
    type: [TuneInType],
    resolve: async (artist) => {
      return db.select().from(tuneIns).where(eq(tuneIns.artistId, artist.id));
    },
  }),
}));
