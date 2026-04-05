import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import {
  artists,
  artistMilestones,
  milestoneReactions,
} from "../../db/schema/index.js";
import { and, eq, desc, sql } from "drizzle-orm";

const MAX_MILESTONES_PER_ARTIST = 200;
import { ArtistType } from "./artist.js";

const MilestoneCategoryEnum = builder.enumType("MilestoneCategory", {
  values: [
    "award",
    "release",
    "event",
    "affiliation",
    "education",
    "other",
  ] as const,
});

const ArtistMilestoneType = builder.objectRef<{
  id: string;
  artistId: string;
  category:
    | "award"
    | "release"
    | "event"
    | "affiliation"
    | "education"
    | "other";
  title: string;
  description: string | null;
  date: string; // DATE column returns string
  position: number;
  createdAt: Date;
}>("ArtistMilestone");

const MilestoneReactionCountType = builder.objectRef<{
  emoji: string;
  count: number;
}>("MilestoneReactionCount");

MilestoneReactionCountType.implement({
  fields: (t) => ({
    emoji: t.exposeString("emoji"),
    count: t.exposeInt("count"),
  }),
});

ArtistMilestoneType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    category: t.field({
      type: MilestoneCategoryEnum,
      resolve: (m) => m.category,
    }),
    title: t.exposeString("title"),
    description: t.exposeString("description", { nullable: true }),
    date: t.exposeString("date"),
    position: t.exposeInt("position"),
    createdAt: t.string({
      resolve: (m) => m.createdAt.toISOString(),
    }),
    reactionCounts: t.field({
      type: [MilestoneReactionCountType],
      resolve: async (m) => {
        const rows = await db
          .select({
            emoji: milestoneReactions.emoji,
            count: sql<number>`count(*)::int`,
          })
          .from(milestoneReactions)
          .where(eq(milestoneReactions.milestoneId, m.id))
          .groupBy(milestoneReactions.emoji)
          .orderBy(desc(sql`count(*)`))
          .limit(5);
        return rows;
      },
    }),
    myReactions: t.field({
      type: ["String"],
      resolve: async (m, _args, ctx) => {
        if (!ctx.authUser) return [];
        const rows = await db
          .select({ emoji: milestoneReactions.emoji })
          .from(milestoneReactions)
          .where(
            and(
              eq(milestoneReactions.milestoneId, m.id),
              eq(milestoneReactions.userId, ctx.authUser.userId),
            ),
          );
        return rows.map((r) => r.emoji);
      },
    }),
  }),
});

async function getOwnArtistId(userId: string): Promise<string> {
  const [artist] = await db
    .select({ id: artists.id })
    .from(artists)
    .where(eq(artists.userId, userId))
    .limit(1);
  if (!artist) {
    throw new GraphQLError("Artist profile required");
  }
  return artist.id;
}

builder.mutationFields((t) => ({
  createArtistMilestone: t.field({
    type: ArtistMilestoneType,
    args: {
      category: t.arg({ type: MilestoneCategoryEnum, required: true }),
      title: t.arg.string({ required: true }),
      description: t.arg.string(),
      date: t.arg.string({ required: true }),
      position: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      const title = args.title.trim();
      if (title.length === 0 || title.length > 255) {
        throw new GraphQLError("Title must be between 1 and 255 characters");
      }

      // Validate date format and existence
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(args.date) ||
        isNaN(new Date(args.date).getTime())
      ) {
        throw new GraphQLError(
          "Date must be a valid date in YYYY-MM-DD format",
        );
      }

      // SELECT FOR UPDATE on artist row to prevent TOCTOU on milestone count
      try {
        return await db.transaction(async (tx) => {
          await tx.execute(
            sql`SELECT 1 FROM ${artists} WHERE id = ${artistId} FOR UPDATE`,
          );
          const [{ count }] = await tx
            .select({ count: sql<number>`count(*)::int` })
            .from(artistMilestones)
            .where(eq(artistMilestones.artistId, artistId));
          if (count >= MAX_MILESTONES_PER_ARTIST) {
            throw new GraphQLError(
              `Maximum ${MAX_MILESTONES_PER_ARTIST} milestones allowed`,
            );
          }
          const [milestone] = await tx
            .insert(artistMilestones)
            .values({
              artistId,
              category: args.category,
              title,
              description: args.description?.trim() || null,
              date: args.date,
              ...(args.position != null ? { position: args.position } : {}),
            })
            .returning();
          return milestone;
        });
      } catch (e) {
        if (e instanceof GraphQLError) throw e;
        throw new GraphQLError("Failed to create milestone");
      }
    },
  }),

  updateArtistMilestone: t.field({
    type: ArtistMilestoneType,
    args: {
      id: t.arg.string({ required: true }),
      category: t.arg({ type: MilestoneCategoryEnum }),
      title: t.arg.string(),
      description: t.arg.string(),
      date: t.arg.string(),
      position: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      const updateData: Record<string, unknown> = {};
      if (args.category != null) updateData.category = args.category;
      if (args.title != null) {
        const title = args.title.trim();
        if (title.length === 0 || title.length > 255) {
          throw new GraphQLError("Title must be between 1 and 255 characters");
        }
        updateData.title = title;
      }
      if (args.description !== undefined) {
        updateData.description = args.description?.trim() || null;
      }
      if (args.date != null) {
        if (
          !/^\d{4}-\d{2}-\d{2}$/.test(args.date) ||
          isNaN(new Date(args.date).getTime())
        ) {
          throw new GraphQLError(
            "Date must be a valid date in YYYY-MM-DD format",
          );
        }
        updateData.date = args.date;
      }
      if (args.position != null) updateData.position = args.position;

      const [updated] = await db
        .update(artistMilestones)
        .set(updateData)
        .where(
          and(
            eq(artistMilestones.id, args.id),
            eq(artistMilestones.artistId, artistId),
          ),
        )
        .returning();

      if (!updated) {
        throw new GraphQLError("Milestone not found");
      }
      return updated;
    },
  }),

  deleteArtistMilestone: t.field({
    type: ArtistMilestoneType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      const [deleted] = await db
        .delete(artistMilestones)
        .where(
          and(
            eq(artistMilestones.id, args.id),
            eq(artistMilestones.artistId, artistId),
          ),
        )
        .returning();

      if (!deleted) {
        throw new GraphQLError("Milestone not found");
      }
      return deleted;
    },
  }),
}));

const MilestoneReactionType = builder.objectRef<{
  id: string;
  milestoneId: string;
  userId: string;
  emoji: string;
  createdAt: Date;
}>("MilestoneReaction");

MilestoneReactionType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    emoji: t.exposeString("emoji"),
    createdAt: t.string({
      resolve: (r) => r.createdAt.toISOString(),
    }),
  }),
});

builder.mutationFields((t) => ({
  toggleMilestoneReaction: t.field({
    type: MilestoneReactionType,
    nullable: true,
    args: {
      milestoneId: t.arg.string({ required: true }),
      emoji: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const emoji = args.emoji.trim();
      if (emoji.length === 0) {
        throw new GraphQLError("Emoji is required");
      }
      if (emoji.length > 10) {
        throw new GraphQLError("Emoji must be 10 characters or less");
      }

      // Verify milestone exists
      const [milestone] = await db
        .select({ id: artistMilestones.id })
        .from(artistMilestones)
        .where(eq(artistMilestones.id, args.milestoneId))
        .limit(1);
      if (!milestone) {
        throw new GraphQLError("Milestone not found");
      }

      // Check if reaction already exists
      const [existing] = await db
        .select()
        .from(milestoneReactions)
        .where(
          and(
            eq(milestoneReactions.milestoneId, args.milestoneId),
            eq(milestoneReactions.userId, ctx.authUser.userId),
            eq(milestoneReactions.emoji, emoji),
          ),
        )
        .limit(1);

      if (existing) {
        await db
          .delete(milestoneReactions)
          .where(eq(milestoneReactions.id, existing.id));
        return null;
      }

      try {
        const [reaction] = await db
          .insert(milestoneReactions)
          .values({
            milestoneId: args.milestoneId,
            userId: ctx.authUser.userId,
            emoji,
          })
          .returning();
        return reaction;
      } catch {
        throw new GraphQLError("Failed to create reaction");
      }
    },
  }),
}));

// Add milestones field to ArtistType
builder.objectFields(ArtistType, (t) => ({
  milestones: t.field({
    type: [ArtistMilestoneType],
    resolve: async (artist) => {
      return db
        .select()
        .from(artistMilestones)
        .where(eq(artistMilestones.artistId, artist.id))
        .orderBy(desc(artistMilestones.date))
        .limit(MAX_MILESTONES_PER_ARTIST);
    },
  }),
}));
