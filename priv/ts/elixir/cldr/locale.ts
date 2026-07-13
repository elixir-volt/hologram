"use strict";

import HologramInterpreterError from "../../errors/interpreter_error.ts";
import Interpreter from "../../interpreter.ts";

const Elixir_Cldr_Locale = {
  // TODO: port manually to JavaScript (transpiled output is too big)
  "language_data/0": () => {
    throw new HologramInterpreterError(
      Interpreter.buildTooBigOutputErrorMsg("{Cldr.Locale, :language_data, 0}"),
    );
  },
};

export default Elixir_Cldr_Locale;
