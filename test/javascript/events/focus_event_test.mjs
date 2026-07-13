"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import FocusEvent from "hologram:runtime/events/focus_event";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

describe("FocusEvent", () => {
  const event = {};

  it("buildOperationParam()", () => {
    assert.deepStrictEqual(FocusEvent.buildOperationParam(event), Type.map());
  });

  it("isEventIgnored()", () => {
    assert.isFalse(FocusEvent.isEventIgnored(event));
  });
});
