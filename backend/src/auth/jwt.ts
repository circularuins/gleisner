import {
  SignJWT,
  jwtVerify,
  importPKCS8,
  importSPKI,
  generateKeyPair,
} from "jose";
import { env } from "../env.js";

const ALG = "EdDSA";
const TOKEN_EXPIRY = "24h";

let privateKey: CryptoKey;
let publicKey: CryptoKey;

export async function initJwtKeys(
  privateKeyPem?: string,
  publicKeyPem?: string,
): Promise<void> {
  if (privateKeyPem && publicKeyPem) {
    privateKey = await importPKCS8(privateKeyPem, ALG);
    publicKey = await importSPKI(publicKeyPem, ALG);
  } else if (env.NODE_ENV === "production") {
    throw new Error(
      "JWT_PRIVATE_KEY and JWT_PUBLIC_KEY must be set in production. " +
        "Generate keys with: node scripts/generate-jwt-keys.ts",
    );
  } else {
    // Auto-generate for development/test only
    const keyPair = await generateKeyPair(ALG, { extractable: true });
    privateKey = keyPair.privateKey;
    publicKey = keyPair.publicKey;
  }
}

export async function signToken(userId: string): Promise<string> {
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: ALG })
    .setIssuedAt()
    .setExpirationTime(TOKEN_EXPIRY)
    .setIssuer("gleisner")
    .sign(privateKey);
}

export async function verifyToken(token: string): Promise<{ userId: string }> {
  const { payload } = await jwtVerify(token, publicKey, {
    issuer: "gleisner",
  });
  if (!payload.sub) {
    throw new Error("Invalid token: missing sub");
  }
  return { userId: payload.sub };
}
