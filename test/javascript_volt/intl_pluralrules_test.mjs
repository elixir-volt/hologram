import {describe, expect, test} from "volt:test";
import Utils from "hologram:runtime/utils";

describe("Intl.PluralRules compatibility", () => {
  test("applies English cardinal rules to integers, decimals, and negatives", () => {
    expect(Utils.naiveNounPlural("car", 1)).toBe("car");
    expect(Utils.naiveNounPlural("car", 1.2)).toBe("cars");
    expect(Utils.naiveNounPlural("car", -1)).toBe("car");
    expect(Utils.naiveNounPlural("car", -2)).toBe("cars");
  });

  test("applies English ordinal teen exceptions", () => {
    expect(Utils.ordinal(11)).toBe("11th");
    expect(Utils.ordinal(12)).toBe("12th");
    expect(Utils.ordinal(13)).toBe("13th");
    expect(Utils.ordinal(21)).toBe("21st");
    expect(Utils.ordinal(22)).toBe("22nd");
    expect(Utils.ordinal(23)).toBe("23rd");
  });
});
