import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import {
  generateUploadUrl,
  isR2Configured,
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
      filename: t.arg.string({ required: true }),
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
          args.filename,
          args.contentLength,
        );
      } catch (err) {
        // Log internal errors (may contain AWS SDK details, bucket names, etc.)
        // but only expose safe validation messages to the client
        const message =
          err instanceof Error && err.message.startsWith("Content type ")
            ? err.message
            : err instanceof Error && err.message.startsWith("File size ")
              ? err.message
              : "Failed to generate upload URL";
        console.error("getUploadUrl error:", err);
        throw new GraphQLError(message);
      }
    },
  }),
}));
