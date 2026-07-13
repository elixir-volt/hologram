import {assert, defineRuntimeGlobals} from "../../support/helpers.mjs";

import Elixir_Cldr_Locale from "hologram:runtime/elixir/cldr/locale";
import HologramInterpreterError from "hologram:runtime/errors/interpreter_error";
import Interpreter from "hologram:runtime/interpreter";

defineRuntimeGlobals();

describe("Elixir_Cldr_Locale", () => {
  it("language_data/0", () => {
    const language_data = Elixir_Cldr_Locale["language_data/0"];

    assert.throw(
      () => language_data(),
      HologramInterpreterError,
      Interpreter.buildTooBigOutputErrorMsg("{Cldr.Locale, :language_data, 0}"),
    );
  });
});
