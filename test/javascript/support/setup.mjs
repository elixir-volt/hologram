"use strict";

import "hologram:runtime/intl-pluralrules-polyfill";

if (typeof globalThis.global === "undefined") {
  globalThis.global = globalThis;
}

if (typeof globalThis.window === "undefined") {
  globalThis.window = globalThis;
}

if (typeof globalThis.self === "undefined") {
  globalThis.self = globalThis;
}

if (typeof globalThis.addEventListener === "undefined") {
  const windowEvents = new EventTarget();
  globalThis.addEventListener = windowEvents.addEventListener.bind(windowEvents);
  globalThis.dispatchEvent = windowEvents.dispatchEvent.bind(windowEvents);
  globalThis.removeEventListener = windowEvents.removeEventListener.bind(windowEvents);
}

if (typeof globalThis.sessionStorage === "undefined") {
  const data = new Map();

  globalThis.sessionStorage = {
    get length() {
      return data.size;
    },
    clear: () => data.clear(),
    getItem: (key) => data.get(String(key)) ?? null,
    key: (index) => [...data.keys()][index] ?? null,
    removeItem: (key) => data.delete(String(key)),
    setItem: (key, value) => data.set(String(key), String(value)),
  };
}
