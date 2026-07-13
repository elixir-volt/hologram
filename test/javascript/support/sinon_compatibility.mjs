"use strict";

// Sinon fake timers mirror Intl whenever the namespace exists and assume that
// DateTimeFormat is present, even when Intl itself is not being faked.
if (
  typeof globalThis.Intl !== "undefined" &&
  typeof globalThis.Intl.DateTimeFormat === "undefined"
) {
  const UnsupportedDateTimeFormat = function () {
    throw new TypeError("Intl.DateTimeFormat is not available in this runtime");
  };

  UnsupportedDateTimeFormat.supportedLocalesOf = () => [];
  globalThis.Intl.DateTimeFormat = UnsupportedDateTimeFormat;
}
