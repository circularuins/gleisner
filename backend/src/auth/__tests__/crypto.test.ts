import { describe, it, expect } from "vitest";
import {
  generateEdKeyPair,
  generateSalt,
  hashPassword,
  verifyPassword,
  encryptPrivateKey,
  decryptPrivateKey,
} from "../crypto.js";

describe("generateEdKeyPair", () => {
  it("returns valid PEM-format key pair", () => {
    const { publicKey, privateKey } = generateEdKeyPair();
    expect(publicKey).toContain("-----BEGIN PUBLIC KEY-----");
    expect(publicKey).toContain("-----END PUBLIC KEY-----");
    expect(privateKey).toContain("-----BEGIN PRIVATE KEY-----");
    expect(privateKey).toContain("-----END PRIVATE KEY-----");
  });
});

describe("generateSalt", () => {
  it("returns a 64-character hex string", () => {
    const salt = generateSalt();
    expect(salt).toHaveLength(64);
    expect(salt).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe("hashPassword / verifyPassword", () => {
  it("verifies correct password", () => {
    const salt = generateSalt();
    const hash = hashPassword("testpassword", salt);
    expect(verifyPassword("testpassword", salt, hash)).toBe(true);
  });

  it("rejects wrong password", () => {
    const salt = generateSalt();
    const hash = hashPassword("testpassword", salt);
    expect(verifyPassword("wrongpassword", salt, hash)).toBe(false);
  });
});

describe("encryptPrivateKey / decryptPrivateKey", () => {
  it("round-trips successfully", () => {
    const { privateKey } = generateEdKeyPair();
    const salt = generateSalt();
    const encrypted = encryptPrivateKey(privateKey, "mypassword", salt);
    const decrypted = decryptPrivateKey(encrypted, "mypassword", salt);
    expect(decrypted).toBe(privateKey);
  });

  it("throws on wrong password", () => {
    const { privateKey } = generateEdKeyPair();
    const salt = generateSalt();
    const encrypted = encryptPrivateKey(privateKey, "mypassword", salt);
    expect(() => decryptPrivateKey(encrypted, "wrongpassword", salt)).toThrow();
  });
});
