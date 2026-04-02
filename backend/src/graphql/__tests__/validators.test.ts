import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ageFromBirthYearMonth } from "../validators.js";

describe("ageFromBirthYearMonth", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("calculates age when birthday month has passed", () => {
    // 2026-06-15, birth: 2000-01 → age 26
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2000-01")).toBe(26);
  });

  it("calculates age when birthday month has not yet passed", () => {
    // 2026-03-15, birth: 2000-06 → age 25 (not yet 26)
    vi.setSystemTime(new Date("2026-03-15"));
    expect(ageFromBirthYearMonth("2000-06")).toBe(25);
  });

  it("calculates age when birthday is current month", () => {
    // 2026-06-15, birth: 2000-06 → age 26 (month matches)
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2000-06")).toBe(26);
  });

  it("handles December birth tested in January", () => {
    // 2027-01-10, birth: 2014-12 → age 12 (Dec has passed)
    vi.setSystemTime(new Date("2027-01-10"));
    expect(ageFromBirthYearMonth("2014-12")).toBe(12);
  });

  it("handles January birth tested in December", () => {
    // 2026-12-15, birth: 2014-01 → age 12
    vi.setSystemTime(new Date("2026-12-15"));
    expect(ageFromBirthYearMonth("2014-01")).toBe(12);
  });

  it("returns 12 for child just under 13 (COPPA boundary)", () => {
    // 2026-06-15, birth: 2013-07 → age 12 (not yet 13)
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2013-07")).toBe(12);
  });

  it("returns 13 for child just turned 13 (COPPA boundary)", () => {
    // 2026-06-15, birth: 2013-06 → age 13
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2013-06")).toBe(13);
  });
});
