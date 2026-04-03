import "dotenv/config";

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export const env = {
  DATABASE_URL: requireEnv("DATABASE_URL"),
  PORT: parseInt(process.env.PORT ?? "4000", 10),
  NODE_ENV: process.env.NODE_ENV ?? "development",
  // JWT EdDSA keys — optional in development (auto-generated), required in production
  JWT_PRIVATE_KEY: process.env.JWT_PRIVATE_KEY?.replace(/\\n/g, "\n"),
  JWT_PUBLIC_KEY: process.env.JWT_PUBLIC_KEY?.replace(/\\n/g, "\n"),
  CORS_ORIGIN: process.env.CORS_ORIGIN ?? "http://localhost:3000",
  REQUIRE_INVITE: process.env.REQUIRE_INVITE === "true",
  // R2 storage — optional in development, required in production
  R2_ACCOUNT_ID: process.env.R2_ACCOUNT_ID,
  R2_ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID,
  R2_SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY,
  R2_BUCKET_NAME: process.env.R2_BUCKET_NAME ?? "gleisner-media",
  R2_PUBLIC_URL: process.env.R2_PUBLIC_URL,
} as const;
