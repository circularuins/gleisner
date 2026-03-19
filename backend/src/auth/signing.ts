import { createHash, verify } from "node:crypto";

export function computeContentHash(fields: {
  title?: string | null;
  body?: string | null;
  mediaUrl?: string | null;
  importance: number;
}): string {
  const parts = [
    fields.title ?? "",
    fields.body ?? "",
    fields.mediaUrl ?? "",
    fields.importance.toString(),
  ];
  return createHash("sha256").update(parts.join("\n")).digest("hex");
}

export function verifySignature(
  contentHash: string,
  signature: string,
  publicKeyPem: string,
): boolean {
  try {
    return verify(
      null,
      Buffer.from(contentHash),
      publicKeyPem,
      Buffer.from(signature, "base64"),
    );
  } catch {
    return false;
  }
}
