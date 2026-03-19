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
} as const;
