import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    // Integration tests share a single DB — parallel execution causes race conditions
    fileParallelism: false,
    // Exclude compiled output — dist/ contains stale .test.js that vitest picks up
    exclude: ["dist/**", "node_modules/**"],
  },
});
