/**
 * admin:setup — Create the initial admin user and invite codes.
 *
 * Run this once on a fresh production database before enabling
 * REQUIRE_INVITE=true. It creates a user account and generates
 * invite codes for distributing to family/friends.
 *
 * Usage:
 *   pnpm admin:setup --email you@example.com --username yourname --password secret123
 *   pnpm admin:setup --email you@example.com --username yourname  (auto-generates password)
 *
 * On Railway:
 *   railway run pnpm admin:setup --email ... --username ... --password ...
 */
import "dotenv/config";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { randomBytes } from "node:crypto";
import { eq } from "drizzle-orm";
import { users, invites } from "../src/db/schema/index.js";
import {
  generateEdKeyPair,
  generateSalt,
  hashPassword,
  encryptPrivateKey,
} from "../src/auth/crypto.js";
import { generateDid } from "../src/auth/did.js";

const INVITE_COUNT = 5;

function parseArgs() {
  const args = process.argv.slice(2);
  const map = new Map<string, string>();
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace(/^--/, "");
    const value = args[i + 1];
    if (key && value) map.set(key, value);
  }
  return {
    email: map.get("email"),
    username: map.get("username"),
    password: map.get("password") ?? randomBytes(16).toString("base64url"),
    displayName: map.get("display-name"),
  };
}

async function main() {
  const { email, username, password, displayName } = parseArgs();

  if (!email || !username) {
    console.error(
      "Usage: pnpm admin:setup --email <email> --username <username> [--password <pw>] [--display-name <name>]",
    );
    process.exit(1);
  }

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error("DATABASE_URL environment variable is required");
    process.exit(1);
  }

  const client = postgres(databaseUrl);
  const db = drizzle(client);

  try {
    // Check if user already exists
    const [existing] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, email))
      .limit(1);

    if (existing) {
      console.error(`User with email ${email} already exists.`);
      console.log("Generating invite codes for existing user...\n");
      await generateInvites(db, existing.id);
      return;
    }

    // Create admin user (same flow as signup resolver)
    const { publicKey, privateKey } = generateEdKeyPair();
    const passwordSalt = generateSalt();
    const encryptionSalt = generateSalt();
    const passwordHashValue = hashPassword(password, passwordSalt);
    const encryptedPrivateKey = encryptPrivateKey(
      privateKey,
      password,
      encryptionSalt,
    );

    // Transaction: INSERT + DID UPDATE are atomic
    const { userId, did } = await db.transaction(async (tx) => {
      const [{ id }] = await tx
        .insert(users)
        .values({
          email,
          username,
          displayName: displayName ?? null,
          passwordHash: passwordHashValue,
          passwordSalt,
          publicKey,
          encryptedPrivateKey,
          encryptionSalt,
          did: "pending",
        })
        .returning({ id: users.id });

      const userDid = generateDid(id);
      await tx.update(users).set({ did: userDid }).where(eq(users.id, id));

      return { userId: id, did: userDid };
    });

    console.log("✓ Admin user created");
    console.log(`  Email:    ${email}`);
    console.log(`  Username: ${username}`);
    // Password to stderr to avoid leaking into piped stdout / CI logs
    console.error(`  Password: ${password}`);
    console.log(`  DID:      ${did}`);
    console.log();

    // Generate invite codes
    await generateInvites(db, userId);
  } finally {
    await client.end();
  }
}

async function generateInvites(
  db: ReturnType<typeof drizzle>,
  createdBy: string,
) {
  console.log(`Generating ${INVITE_COUNT} invite codes:\n`);

  for (let i = 0; i < INVITE_COUNT; i++) {
    const code = randomBytes(10).toString("hex");
    await db.insert(invites).values({
      code,
      createdBy,
    });
    console.log(`  ${i + 1}. ${code}`);
  }

  console.log("\nShare these codes with family/friends to let them sign up.");
  console.log("Each code can be used once.");
}

main().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
