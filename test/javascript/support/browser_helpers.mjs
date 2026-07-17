"use strict";

export {h as vnode} from "snabbdom";

// Narrow compatibility facade for canonical tests that previously used jsdom.
// DOM behavior itself comes from the real Playwright browser.
export class JSDOM {
  constructor(html = "") {
    const document = new DOMParser().parseFromString(html, "text/html");
    const window = Object.create(globalThis);

    Object.defineProperties(window, {
      document: {value: document, enumerable: true},
      self: {value: window},
      window: {value: window},
    });

    this.window = window;
  }
}

export function registerWebApis() {
  globalThis.window = globalThis;
  globalThis.self = globalThis;
}
