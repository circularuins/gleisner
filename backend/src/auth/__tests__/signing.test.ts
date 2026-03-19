import { describe, it, expect } from "vitest";
import { sign } from "node:crypto";
import { computeContentHash, verifySignature } from "../signing.js";
import { generateEdKeyPair } from "../crypto.js";

describe("computeContentHash", () => {
  it("returns consistent hash for same input", () => {
    const fields = {
      title: "Hello",
      body: "World",
      mediaUrl: null,
      importance: 0.5,
    };
    const hash1 = computeContentHash(fields);
    const hash2 = computeContentHash(fields);
    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64); // SHA-256 hex
  });

  it("returns different hash for different input", () => {
    const hash1 = computeContentHash({
      title: "A",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    const hash2 = computeContentHash({
      title: "B",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    expect(hash1).not.toBe(hash2);
  });

  it("handles all-null optional fields", () => {
    const hash = computeContentHash({
      title: null,
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    expect(hash).toHaveLength(64);
  });

  it("importance change produces different hash", () => {
    const base = { title: "X", body: null, mediaUrl: null };
    const hash1 = computeContentHash({ ...base, importance: 0.5 });
    const hash2 = computeContentHash({ ...base, importance: 0.8 });
    expect(hash1).not.toBe(hash2);
  });
});

describe("verifySignature", () => {
  function signHash(contentHash: string, privateKeyPem: string): string {
    const sig = sign(null, Buffer.from(contentHash), privateKeyPem);
    return sig.toString("base64");
  }

  it("verifies a correct signature", () => {
    const { publicKey, privateKey } = generateEdKeyPair();
    const hash = computeContentHash({
      title: "Test",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    const signature = signHash(hash, privateKey);
    expect(verifySignature(hash, signature, publicKey)).toBe(true);
  });

  it("rejects signature for tampered hash", () => {
    const { publicKey, privateKey } = generateEdKeyPair();
    const hash = computeContentHash({
      title: "Test",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    const signature = signHash(hash, privateKey);
    const tamperedHash = hash.replace(/^./, "0");
    expect(verifySignature(tamperedHash, signature, publicKey)).toBe(false);
  });

  it("rejects an invalid signature string", () => {
    const { publicKey } = generateEdKeyPair();
    const hash = computeContentHash({
      title: "Test",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    expect(verifySignature(hash, "not-valid-base64!!!", publicKey)).toBe(false);
  });

  it("rejects signature from wrong key", () => {
    const keyPair1 = generateEdKeyPair();
    const keyPair2 = generateEdKeyPair();
    const hash = computeContentHash({
      title: "Test",
      body: null,
      mediaUrl: null,
      importance: 0.5,
    });
    const signature = signHash(hash, keyPair1.privateKey);
    expect(verifySignature(hash, signature, keyPair2.publicKey)).toBe(false);
  });
});
