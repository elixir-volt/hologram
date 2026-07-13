import {assert, defineRuntimeGlobals} from "../../../support/helpers.mjs";

import Elixir_Cldr_Validity_U from "hologram:runtime/elixir/cldr/validity/u";
import HologramInterpreterError from "hologram:runtime/errors/interpreter_error";
import Interpreter from "hologram:runtime/interpreter";

defineRuntimeGlobals();

describe("Elixir_Cldr_Validity_U", () => {
  it("encode_key/2", () => {
    const encode_key = Elixir_Cldr_Validity_U["encode_key/2"];

    assert.throw(
      () => encode_key("dummy_key", "dummy_value"),
      HologramInterpreterError,
      Interpreter.buildTooBigOutputErrorMsg(
        "{Cldr.Validity.U, :encode_key, 2}",
      ),
    );
  });
});
