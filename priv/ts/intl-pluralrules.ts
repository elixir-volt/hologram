export function needsIntlPluralRulesPolyfill() {
  if (typeof Intl === "undefined" || typeof Intl.PluralRules !== "function") {
    return true;
  }

  try {
    const decimalRule = new Intl.PluralRules("en", {minimumFractionDigits: 2});

    return (
      decimalRule.select(1) === "one" || Intl.PluralRules.supportedLocalesOf(["en"]).length === 0
    );
  } catch {
    return true;
  }
}

export function loadIntlPluralRulesPolyfill() {
  if (needsIntlPluralRulesPolyfill()) {
    if (typeof Intl !== "undefined" && typeof Intl.PluralRules !== "function") {
      delete Intl.PluralRules;
    }

    return import("./intl-pluralrules-polyfill");
  }

  return null;
}
