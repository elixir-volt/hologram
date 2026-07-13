"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import HologramInterpreterError from "hologram:runtime/errors/interpreter_error";

defineRuntimeGlobals();

describe("HologramInterpreterError", () => {
  it("throw", () => {
    try {
      throw new HologramInterpreterError("my message");
    } catch (error) {
      assert.instanceOf(error, HologramInterpreterError);
      assert.deepStrictEqual(error.message, "my message");
    }
  });
});
