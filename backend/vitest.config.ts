import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    // Integration tests share a single DB — parallel execution causes race conditions
    fileParallelism: false,
  },
});
