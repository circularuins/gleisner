import {
  SignJWT,
  jwtVerify,
  importPKCS8,
  importSPKI,
  generateKeyPair,
} from "jose";
import { env } from "../env.js";

const ALG = "EdDSA";
// Phase 0: 30d single-token TTL is a pragmatic trade-off until #409
// (refresh-token rotation, PR-D of the Phase 1 authz batch). The previous
// 24h TTL caused daily forced re-login on iPad child accounts where the
// parent had switched to a child profile via switchToChild — the TTL clock
// started at switch time, not at last activity, so a child using the iPad
// once per evening was almost certain to be logged out by the next day.
const TOKEN_EXPIRY = "30d";

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

export async function signToken(
  userId: string,
  opts?: { guardianId?: string },
): Promise<string> {
  const claims: Record<string, unknown> = { sub: userId };
  if (opts?.guardianId) {
    claims.gid = opts.guardianId;
  }
  return new SignJWT(claims)
    .setProtectedHeader({ alg: ALG })
    .setIssuedAt()
    .setExpirationTime(TOKEN_EXPIRY)
    .setIssuer("gleisner")
    .sign(privateKey);
}

export async function verifyToken(
  token: string,
): Promise<{ userId: string; guardianId?: string }> {
  const { payload } = await jwtVerify(token, publicKey, {
    issuer: "gleisner",
  });
  if (!payload.sub) {
    throw new Error("Invalid token: missing sub");
  }
  const result: { userId: string; guardianId?: string } = {
    userId: payload.sub,
  };
  if (typeof payload.gid === "string") {
    result.guardianId = payload.gid;
  }
  return result;
}
