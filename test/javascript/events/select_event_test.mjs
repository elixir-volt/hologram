"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import SelectEvent from "hologram:runtime/events/select_event";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

describe("SelectEvent", () => {
  const event = {
    target: {selectionEnd: 15, selectionStart: 6, value: "Hologram 1 Hologram"},
  };

  it("buildOperationParam()", () => {
    const result = SelectEvent.buildOperationParam(event);

    assert.deepStrictEqual(
      result,
      Type.map([[Type.atom("value"), Type.bitstring("am 1 Holo")]]),
    );
  });

  it("isEventIgnored()", () => {
    assert.isFalse(SelectEvent.isEventIgnored(event));
  });
});
