"use strict";

import {assert, defineRuntimeGlobals} from "../support/helpers.mjs";

import Erlang_Elixir_Config from "hologram:runtime/erlang/elixir_config";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

// IMPORTANT!
// Each JavaScript test has a related Elixir consistency test in test/elixir/hologram/ex_js_consistency/erlang/elixir_config_test.exs
// Always update both together.

describe("Erlang_Elixir_Config", () => {
  describe("identifier_tokenizer/0", () => {
    const identifier_tokenizer = Erlang_Elixir_Config["identifier_tokenizer/0"];

    it("names the tokenizer Elixir ships with", () => {
      assert.deepStrictEqual(
        identifier_tokenizer(),
        Type.alias("String.Tokenizer"),
      );
    });
  });
});
