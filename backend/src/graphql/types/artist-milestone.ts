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
  // Prefetched by parent resolver to avoid N+1
  _reactionCounts?: { emoji: string; count: number }[];
  _myReactions?: string[];
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
        // Use prefetched data from parent resolver (avoids N+1)
        if (m._reactionCounts) return m._reactionCounts;
        // Fallback for direct queries (e.g. after mutation)
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
        // Use prefetched data from parent resolver (avoids N+1)
        if (m._myReactions) return m._myReactions;
        // Fallback for direct queries (e.g. after mutation)
        const rows = await db
          .select({ emoji: milestoneReactions.emoji })
          .from(milestoneReactions)
          .where(
            and(
              eq(milestoneReactions.milestoneId, m.id),
              eq(milestoneReactions.userId, ctx.authUser.userId),
            ),
          )
          .limit(8);
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

      // Atomic toggle inside transaction — existence check included.
      return await db.transaction(async (tx) => {
        // Verify milestone exists and artist is accessible
        const [milestone] = await tx
          .select({
            id: artistMilestones.id,
            profileVisibility: artists.profileVisibility,
            userId: artists.userId,
          })
          .from(artistMilestones)
          .innerJoin(artists, eq(artistMilestones.artistId, artists.id))
          .where(eq(artistMilestones.id, args.milestoneId))
          .limit(1);
        if (!milestone) {
          throw new GraphQLError("Milestone not found");
        }
        if (
          milestone.profileVisibility === "private" &&
          milestone.userId !== ctx.authUser!.userId
        ) {
          throw new GraphQLError("Milestone not found");
        }

        const [deleted] = await tx
          .delete(milestoneReactions)
          .where(
            and(
              eq(milestoneReactions.milestoneId, args.milestoneId),
              eq(milestoneReactions.userId, ctx.authUser!.userId),
              eq(milestoneReactions.emoji, emoji),
            ),
          )
          .returning();

        if (deleted) {
          // Was on → now off
          return null;
        }

        // Enforce per-user reaction limit (max 8 distinct emoji per milestone)
        const [{ count }] = await tx
          .select({ count: sql<number>`count(*)::int` })
          .from(milestoneReactions)
          .where(
            and(
              eq(milestoneReactions.milestoneId, args.milestoneId),
              eq(milestoneReactions.userId, ctx.authUser!.userId),
            ),
          );
        if (count >= 8) {
          throw new GraphQLError("Maximum 8 reactions per milestone");
        }

        // Was off → now on
        const [reaction] = await tx
          .insert(milestoneReactions)
          .values({
            milestoneId: args.milestoneId,
            userId: ctx.authUser!.userId,
            emoji,
          })
          .returning();
        return reaction;
      });
    },
  }),
}));

// Add milestones field to ArtistType — prefetches reaction data to avoid N+1
builder.objectFields(ArtistType, (t) => ({
  milestones: t.field({
    type: [ArtistMilestoneType],
    resolve: async (artist, _args, ctx) => {
      const rows = await db
        .select()
        .from(artistMilestones)
        .where(eq(artistMilestones.artistId, artist.id))
        .orderBy(desc(artistMilestones.date))
        .limit(MAX_MILESTONES_PER_ARTIST);

      if (rows.length === 0) return [];

      const milestoneIds = rows.map((r) => r.id);

      // Batch fetch reaction counts (1 query, top 5 per milestone via window fn)
      const countRows = await db.execute<{
        milestone_id: string;
        emoji: string;
        cnt: number;
      }>(sql`
        SELECT milestone_id, emoji, cnt FROM (
          SELECT milestone_id, emoji, count(*)::int AS cnt,
                 ROW_NUMBER() OVER (
                   PARTITION BY milestone_id
                   ORDER BY count(*) DESC, emoji ASC
                 ) AS rn
          FROM milestone_reactions
          WHERE milestone_id IN ${milestoneIds}
          GROUP BY milestone_id, emoji
        ) ranked WHERE rn <= 5
      `);

      const countsMap = new Map<string, { emoji: string; count: number }[]>();
      for (const row of countRows) {
        const list = countsMap.get(row.milestone_id) ?? [];
        list.push({ emoji: row.emoji, count: row.cnt });
        countsMap.set(row.milestone_id, list);
      }

      // Batch fetch user's own reactions (1 query instead of N)
      const myMap = new Map<string, string[]>();
      if (ctx.authUser) {
        const myRows = await db
          .select({
            milestoneId: milestoneReactions.milestoneId,
            emoji: milestoneReactions.emoji,
          })
          .from(milestoneReactions)
          .where(
            and(
              sql`${milestoneReactions.milestoneId} IN ${milestoneIds}`,
              eq(milestoneReactions.userId, ctx.authUser.userId),
            ),
          );
        for (const row of myRows) {
          const list = myMap.get(row.milestoneId) ?? [];
          list.push(row.emoji);
          myMap.set(row.milestoneId, list);
        }
      }

      // Embed prefetched data into each milestone object
      return rows.map((r) => ({
        ...r,
        _reactionCounts: countsMap.get(r.id) ?? [],
        _myReactions: myMap.get(r.id) ?? [],
      }));
    },
  }),
}));
