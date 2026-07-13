"use strict";

import Interpreter from "hologram:runtime/interpreter";
import Type from "hologram:runtime/type";

export function defineModule1Fixture() {
  Interpreter.defineElixirFunction(
    "Hologram.Test.Fixtures.Router.Helpers.Module1",
    "__params__",
    0,
    "public",
    [
      {
        params: (_context) => [],
        guards: [],
        body: (_context) => {
          return Elixir_Enum["reverse/1"](Type.list());
        },
      },
    ],
  );

  Interpreter.defineElixirFunction(
    "Hologram.Test.Fixtures.Router.Helpers.Module1",
    "__route__",
    0,
    "public",
    [
      {
        params: (_context) => [],
        guards: [],
        body: (_context) => {
          return Type.bitstring(
            "/hologram-test-fixtures-router-helpers-module1",
          );
        },
      },
    ],
  );
}
