#!/usr/bin/env tsx
/**
 * Generate Ed25519 key pair for JWT signing.
 * Output can be added to .env file.
 */
import { generateKeyPair, exportPKCS8, exportSPKI } from "jose";

async function main() {
  const { privateKey, publicKey } = await generateKeyPair("EdDSA");
  const privPem = await exportPKCS8(privateKey);
  const pubPem = await exportSPKI(publicKey);

  console.log("# Add these to your .env file:");
  console.log(`JWT_PRIVATE_KEY="${privPem.replace(/\n/g, "\\n")}"`);
  console.log(`JWT_PUBLIC_KEY="${pubPem.replace(/\n/g, "\\n")}"`);
}

main();
