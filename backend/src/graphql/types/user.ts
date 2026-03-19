import { builder } from "../builder.js";

interface UserShape {
  id: string;
  did: string;
  email: string;
  username: string;
  displayName: string | null;
  bio: string | null;
  avatarUrl: string | null;
  publicKey: string;
  createdAt: Date;
  updatedAt: Date;
}

export const UserType = builder.objectRef<UserShape>("User");

UserType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    did: t.exposeString("did"),
    email: t.exposeString("email"),
    username: t.exposeString("username"),
    displayName: t.exposeString("displayName", { nullable: true }),
    bio: t.exposeString("bio", { nullable: true }),
    avatarUrl: t.exposeString("avatarUrl", { nullable: true }),
    publicKey: t.exposeString("publicKey"),
    createdAt: t.string({ resolve: (user) => user.createdAt.toISOString() }),
    updatedAt: t.string({ resolve: (user) => user.updatedAt.toISOString() }),
  }),
});

export const PublicUserType = builder.objectRef<UserShape>("PublicUser");

PublicUserType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    did: t.exposeString("did"),
    username: t.exposeString("username"),
    displayName: t.exposeString("displayName", { nullable: true }),
    bio: t.exposeString("bio", { nullable: true }),
    avatarUrl: t.exposeString("avatarUrl", { nullable: true }),
    createdAt: t.string({ resolve: (user) => user.createdAt.toISOString() }),
  }),
});
