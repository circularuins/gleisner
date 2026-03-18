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
  JWT_SECRET: requireEnv("JWT_SECRET"),
} as const;
