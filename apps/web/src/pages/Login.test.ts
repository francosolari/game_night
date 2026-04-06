import { describe, expect, it } from "vitest";
import { formatPhoneForDisplay } from "./Login";

describe("formatPhoneForDisplay", () => {
  it("formats US numbers as xxx-xxx-xxxx", () => {
    expect(formatPhoneForDisplay("+1", "5551234567")).toBe("555-123-4567");
  });

  it("formats French numbers as x-xx-xx-xx-xx", () => {
    expect(formatPhoneForDisplay("+33", "612345678")).toBe("6-12-34-56-78");
  });

  it("formats Australian numbers as x-xxxx-xxxx", () => {
    expect(formatPhoneForDisplay("+61", "412345678")).toBe("4-1234-5678");
  });

  it("strips non-digits before formatting", () => {
    expect(formatPhoneForDisplay("+1", "(555) 123 4567")).toBe("555-123-4567");
  });
});
