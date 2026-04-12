import { createHash, verify } from "node:crypto";

/**
 * Extract plain text from a Quill Delta ops array.
 * String inserts are concatenated; non-string inserts (images, embeds)
 * are replaced with a newline to maintain structure for hashing.
 */
export function deltaToPlainText(ops: unknown): string {
  if (!Array.isArray(ops)) return "";
  return ops
    .map((op) => {
      if (typeof op === "object" && op !== null && "insert" in op) {
        const insert = (op as { insert: unknown }).insert;
        return typeof insert === "string" ? insert : "\n";
      }
      return "";
    })
    .join("");
}

/**
 * Compute a SHA-256 content hash from post fields using JSON canonical form.
 * The canonical JSON ensures unambiguous field boundaries, preventing
 * collision attacks where field values containing delimiters produce
 * identical hashes for different inputs.
 *
 * For Delta-format bodies, plain text is extracted first so that the
 * hash is format-independent (same text = same hash regardless of
 * plain vs Delta storage).
 */
export function computeContentHash(fields: {
  title?: string | null;
  body?: unknown;
  bodyFormat?: string;
  mediaUrl?: string | null;
  mediaType: string;
  importance: number;
  duration?: number | null;
  articleGenre?: string | null;
}): string {
  // Normalize body to plain text for format-independent hashing
  let bodyText = "";
  if (fields.bodyFormat === "delta" && Array.isArray(fields.body)) {
    bodyText = deltaToPlainText(fields.body);
  } else if (typeof fields.body === "string") {
    bodyText = fields.body;
  }

  const canonical = JSON.stringify({
    title: fields.title ?? "",
    body: bodyText,
    mediaUrl: fields.mediaUrl ?? "",
    mediaType: fields.mediaType,
    importance: fields.importance,
    duration: fields.duration ?? null,
    articleGenre: fields.articleGenre ?? null,
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
