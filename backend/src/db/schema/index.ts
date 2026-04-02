import { relations } from "drizzle-orm";

// Tables
export { users } from "./user.js";
export { artists } from "./artist.js";
export { genres } from "./genre.js";
export { artistGenres } from "./artist-genre.js";
export { tracks } from "./track.js";
export { posts, mediaTypeEnum } from "./post.js";
export { connections, connectionTypeEnum } from "./connection.js";
export { constellations } from "./constellation.js";
export { reactions } from "./reaction.js";
export { comments } from "./comment.js";
export { tuneIns } from "./tune-in.js";
export { follows } from "./follow.js";
export { artistLinks, linkCategoryEnum } from "./artist-link.js";
export { artistMilestones, milestoneCategoryEnum } from "./artist-milestone.js";
export { analyticsEvents } from "./analytics-event.js";
export { invites } from "./invite.js";

// Re-import for relations
import { users } from "./user.js";
import { artists } from "./artist.js";
import { genres } from "./genre.js";
import { artistGenres } from "./artist-genre.js";
import { tracks } from "./track.js";
import { posts } from "./post.js";
import { connections } from "./connection.js";
import { reactions } from "./reaction.js";
import { comments } from "./comment.js";
import { tuneIns } from "./tune-in.js";
import { follows } from "./follow.js";
import { artistLinks } from "./artist-link.js";
import { artistMilestones } from "./artist-milestone.js";
import { constellations } from "./constellation.js";

// Relations
export const usersRelations = relations(users, ({ one, many }) => ({
  artist: one(artists, { fields: [users.id], references: [artists.userId] }),
  posts: many(posts),
  reactions: many(reactions),
  comments: many(comments),
  followers: many(follows, { relationName: "following" }),
  following: many(follows, { relationName: "follower" }),
  tuneIns: many(tuneIns),
}));

export const artistsRelations = relations(artists, ({ one, many }) => ({
  user: one(users, { fields: [artists.userId], references: [users.id] }),
  artistGenres: many(artistGenres),
  tracks: many(tracks),
  artistLinks: many(artistLinks),
  artistMilestones: many(artistMilestones),
  tuneIns: many(tuneIns),
}));

export const genresRelations = relations(genres, ({ many }) => ({
  artistGenres: many(artistGenres),
}));

export const artistGenresRelations = relations(artistGenres, ({ one }) => ({
  artist: one(artists, {
    fields: [artistGenres.artistId],
    references: [artists.id],
  }),
  genre: one(genres, {
    fields: [artistGenres.genreId],
    references: [genres.id],
  }),
}));

export const tracksRelations = relations(tracks, ({ one, many }) => ({
  artist: one(artists, { fields: [tracks.artistId], references: [artists.id] }),
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  track: one(tracks, { fields: [posts.trackId], references: [tracks.id] }),
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
  reactions: many(reactions),
  comments: many(comments),
  outgoingConnections: many(connections, { relationName: "source" }),
  incomingConnections: many(connections, { relationName: "target" }),
}));

export const connectionsRelations = relations(connections, ({ one }) => ({
  source: one(posts, {
    fields: [connections.sourceId],
    references: [posts.id],
    relationName: "source",
  }),
  target: one(posts, {
    fields: [connections.targetId],
    references: [posts.id],
    relationName: "target",
  }),
}));

export const reactionsRelations = relations(reactions, ({ one }) => ({
  post: one(posts, { fields: [reactions.postId], references: [posts.id] }),
  user: one(users, { fields: [reactions.userId], references: [users.id] }),
}));

export const commentsRelations = relations(comments, ({ one }) => ({
  post: one(posts, { fields: [comments.postId], references: [posts.id] }),
  user: one(users, { fields: [comments.userId], references: [users.id] }),
}));

export const tuneInsRelations = relations(tuneIns, ({ one }) => ({
  user: one(users, { fields: [tuneIns.userId], references: [users.id] }),
  artist: one(artists, {
    fields: [tuneIns.artistId],
    references: [artists.id],
  }),
}));

export const followsRelations = relations(follows, ({ one }) => ({
  follower: one(users, {
    fields: [follows.followerId],
    references: [users.id],
    relationName: "follower",
  }),
  following: one(users, {
    fields: [follows.followingId],
    references: [users.id],
    relationName: "following",
  }),
}));

export const artistLinksRelations = relations(artistLinks, ({ one }) => ({
  artist: one(artists, {
    fields: [artistLinks.artistId],
    references: [artists.id],
  }),
}));

export const artistMilestonesRelations = relations(
  artistMilestones,
  ({ one }) => ({
    artist: one(artists, {
      fields: [artistMilestones.artistId],
      references: [artists.id],
    }),
  }),
);

export const constellationsRelations = relations(constellations, ({ one }) => ({
  artist: one(artists, {
    fields: [constellations.artistId],
    references: [artists.id],
  }),
  anchorPost: one(posts, {
    fields: [constellations.anchorPostId],
    references: [posts.id],
  }),
}));
