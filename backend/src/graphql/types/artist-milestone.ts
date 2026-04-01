import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, artistMilestones } from "../../db/schema/index.js";
import { and, eq, desc } from "drizzle-orm";
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

      // Validate date format (YYYY-MM-DD)
      if (!/^\d{4}-\d{2}-\d{2}$/.test(args.date)) {
        throw new GraphQLError("Date must be in YYYY-MM-DD format");
      }

      try {
        const [milestone] = await db
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
      } catch {
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
        if (!/^\d{4}-\d{2}-\d{2}$/.test(args.date)) {
          throw new GraphQLError("Date must be in YYYY-MM-DD format");
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
        .limit(100);
    },
  }),
}));
