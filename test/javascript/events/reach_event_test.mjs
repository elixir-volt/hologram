"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import ReachEvent from "hologram:runtime/events/reach_event";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

describe("ReachEvent", () => {
  it("buildOperationParam()", () => {
    const result = ReachEvent.buildOperationParam({target: {}});

    assert.deepStrictEqual(result, Type.map());
  });

  it("isEventIgnored()", () => {
    assert.isFalse(ReachEvent.isEventIgnored({target: {}}));
  });
});
