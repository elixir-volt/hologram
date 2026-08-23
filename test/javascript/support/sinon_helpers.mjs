"use strict";

import "./sinon_compatibility.mjs";
import * as nativeSinon from "sinon/pkg/sinon-esm.js";

const defaultFakeTimers = {
  toFake: ["setTimeout", "clearTimeout", "setInterval", "clearInterval"],
};

export const sinon = {
  ...nativeSinon,
  useFakeTimers: (config) =>
    nativeSinon.useFakeTimers(
      config === undefined
        ? defaultFakeTimers
        : {...defaultFakeTimers, ...config},
    ),
};
