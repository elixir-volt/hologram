"use strict";

import Interpreter from "hologram:runtime/interpreter";
import Type from "hologram:runtime/type";

export function defineModule3Fixture() {
  Interpreter.defineElixirFunction(
    "Hologram.Test.Fixtures.ExJsConsistency.Erlang.Module3",
    "format_error",
    2,
    "public",
    [
      {
        params: (_context) => [
          Type.variablePattern("_reason"),
          Type.variablePattern("_stacktrace"),
        ],
        guards: [],
        body: (_context) => {
          return Type.map([[Type.integer(2), Type.bitstring("not a map")]]);
        },
      },
    ],
  );
}
