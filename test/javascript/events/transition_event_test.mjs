"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import TransitionEvent from "hologram:runtime/events/transition_event";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

describe("TransitionEvent", () => {
  const event = {};

  it("buildOperationParam()", () => {
    assert.deepStrictEqual(
      TransitionEvent.buildOperationParam(event),
      Type.map(),
    );
  });

  it("isEventIgnored()", () => {
    assert.isFalse(TransitionEvent.isEventIgnored(event));
  });
});
