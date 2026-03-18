import {
  SignJWT,
  jwtVerify,
  importPKCS8,
  importSPKI,
  exportPKCS8,
  exportSPKI,
  generateKeyPair,
} from "jose";

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
  } else {
    // Auto-generate for development
    const keyPair = await generateKeyPair(ALG, { extractable: true });
    privateKey = keyPair.privateKey;
    publicKey = keyPair.publicKey;
    const privPem = await exportPKCS8(keyPair.privateKey);
    const pubPem = await exportSPKI(keyPair.publicKey);
    console.log("JWT keys auto-generated (development mode)");
    console.log(
      "Set JWT_PRIVATE_KEY and JWT_PUBLIC_KEY env vars for production",
    );
    console.log(`JWT_PRIVATE_KEY=${JSON.stringify(privPem)}`);
    console.log(`JWT_PUBLIC_KEY=${JSON.stringify(pubPem)}`);
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
