import { describe, it, expect } from "vitest";
import { generateDid } from "../did.js";

describe("generateDid", () => {
  it("returns correct DID format", () => {
    const uuid = "550e8400-e29b-41d4-a716-446655440000";
    const did = generateDid(uuid);
    expect(did).toBe(`did:web:gleisner.app:u:${uuid}`);
  });
});
