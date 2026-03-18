import { generateKeyPairSync, scryptSync, randomBytes, createCipheriv, createDecipheriv } from "node:crypto";

const SCRYPT_PARAMS = { N: 16384, r: 8, p: 1 } as const;
const SCRYPT_KEYLEN = 64;
const AES_KEYLEN = 32;

export interface KeyPair {
  publicKey: string;
  privateKey: string;
}

export function generateEdKeyPair(): KeyPair {
  const { publicKey, privateKey } = generateKeyPairSync("ed25519", {
    publicKeyEncoding: { type: "spki", format: "pem" },
    privateKeyEncoding: { type: "pkcs8", format: "pem" },
  });
  return { publicKey, privateKey };
}

export function generateSalt(): string {
  return randomBytes(32).toString("hex");
}

export function hashPassword(password: string, salt: string): string {
  const saltBuf = Buffer.from(salt, "hex");
  const hash = scryptSync(password, saltBuf, SCRYPT_KEYLEN, SCRYPT_PARAMS);
  return hash.toString("hex");
}

export function verifyPassword(password: string, salt: string, hash: string): boolean {
  const computed = hashPassword(password, salt);
  // Constant-time comparison
  if (computed.length !== hash.length) return false;
  let diff = 0;
  for (let i = 0; i < computed.length; i++) {
    diff |= computed.charCodeAt(i) ^ hash.charCodeAt(i);
  }
  return diff === 0;
}

function deriveEncryptionKey(password: string, salt: string): Buffer {
  const saltBuf = Buffer.from(salt, "hex");
  return scryptSync(password, saltBuf, AES_KEYLEN, SCRYPT_PARAMS);
}

export function encryptPrivateKey(privateKeyPem: string, password: string, encryptionSalt: string): string {
  const key = deriveEncryptionKey(password, encryptionSalt);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(privateKeyPem, "utf8"), cipher.final()]);
  const authTag = cipher.getAuthTag();
  // Format: iv:authTag:encrypted (all hex)
  return `${iv.toString("hex")}:${authTag.toString("hex")}:${encrypted.toString("hex")}`;
}

export function decryptPrivateKey(encrypted: string, password: string, encryptionSalt: string): string {
  const [ivHex, authTagHex, dataHex] = encrypted.split(":");
  const key = deriveEncryptionKey(password, encryptionSalt);
  const decipher = createDecipheriv("aes-256-gcm", key, Buffer.from(ivHex, "hex"));
  decipher.setAuthTag(Buffer.from(authTagHex, "hex"));
  const decrypted = Buffer.concat([decipher.update(Buffer.from(dataHex, "hex")), decipher.final()]);
  return decrypted.toString("utf8");
}
