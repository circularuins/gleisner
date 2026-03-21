import { createHash, verify } from "node:crypto";

/**
 * Compute a SHA-256 content hash from post fields using JSON canonical form.
 * The canonical JSON ensures unambiguous field boundaries, preventing
 * collision attacks where field values containing delimiters produce
 * identical hashes for different inputs.
 */
export function computeContentHash(fields: {
  title?: string | null;
  body?: string | null;
  mediaUrl?: string | null;
  mediaType: string;
  importance: number;
  duration?: number | null;
}): string {
  const canonical = JSON.stringify({
    title: fields.title ?? "",
    body: fields.body ?? "",
    mediaUrl: fields.mediaUrl ?? "",
    mediaType: fields.mediaType,
    importance: fields.importance,
    duration: fields.duration ?? null,
  });
  return createHash("sha256").update(canonical).digest("hex");
}

/**
 * Verify an Ed25519 signature against a content hash.
 *
 * Returns false for both invalid signatures and malformed inputs
 * (e.g. bad base64, invalid PEM). System-level errors are logged
 * for debugging but do not propagate.
 */
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
  } catch (err) {
    console.error("[signing] Signature verification error:", err);
    return false;
  }
}
