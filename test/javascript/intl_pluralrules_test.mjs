import {describe, expect, test} from "volt:test";
import {
  loadIntlPluralRulesPolyfill,
  needsIntlPluralRulesPolyfill,
} from "hologram:runtime/intl-pluralrules";
import Utils from "hologram:runtime/utils";

describe("Intl.PluralRules compatibility", () => {
  test("recognizes the installed implementation", () => {
    expect(needsIntlPluralRulesPolyfill()).toBe(false);
  });

  test("detects a missing implementation", () => {
    const originalPluralRules = Intl.PluralRules;

    try {
      Intl.PluralRules = undefined;
      expect(needsIntlPluralRulesPolyfill()).toBe(true);
    } finally {
      Intl.PluralRules = originalPluralRules;
    }
  });

  test("loads the maintained fallback when the implementation is missing", async () => {
    const originalDescriptor = Object.getOwnPropertyDescriptor(Intl, "PluralRules");

    try {
      Intl.PluralRules = undefined;
      await loadIntlPluralRulesPolyfill();

      expect(new Intl.PluralRules("en").select(1)).toBe("one");
      expect(new Intl.PluralRules("en", {type: "ordinal"}).select(22)).toBe("two");
    } finally {
      Object.defineProperty(Intl, "PluralRules", originalDescriptor);
    }
  });

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
