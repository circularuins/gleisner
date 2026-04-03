import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import {
  generateUploadUrl,
  isR2Configured,
  R2ValidationError,
  type UploadCategory,
} from "../../storage/r2.js";

const UploadCategoryEnum = builder.enumType("UploadCategory", {
  values: ["avatars", "covers", "media"] as const,
});

const PresignedUploadType = builder.objectRef<{
  uploadUrl: string;
  publicUrl: string;
  key: string;
}>("PresignedUpload");

PresignedUploadType.implement({
  fields: (t) => ({
    uploadUrl: t.exposeString("uploadUrl"),
    publicUrl: t.exposeString("publicUrl"),
    key: t.exposeString("key"),
  }),
});

builder.mutationFields((t) => ({
  getUploadUrl: t.field({
    type: PresignedUploadType,
    args: {
      category: t.arg({ type: UploadCategoryEnum, required: true }),
      contentType: t.arg.string({ required: true }),
      contentLength: t.arg.int({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      if (!isR2Configured()) {
        throw new GraphQLError(
          "Media upload is not available. Storage is not configured.",
        );
      }

      try {
        return await generateUploadUrl(
          ctx.authUser.userId,
          args.category as UploadCategory,
          args.contentType,
          args.contentLength,
        );
      } catch (err) {
        // R2ValidationError is safe to expose (client input issues)
        // All other errors may contain AWS SDK internals — log and return generic message
        if (err instanceof R2ValidationError) {
          throw new GraphQLError(err.message);
        }
        console.error("getUploadUrl error:", err);
        throw new GraphQLError("Failed to generate upload URL");
      }
    },
  }),
}));
