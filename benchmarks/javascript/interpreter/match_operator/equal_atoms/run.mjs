"use strict";

import Interpreter from "hologram:runtime/interpreter";
import Type from "hologram:runtime/type";

import {benchmark} from "../../../support/helpers.mjs";
import {contextFixture} from "../../../../../test/javascript/support/helpers.mjs";

const context = contextFixture();

benchmark(() => {
  Interpreter.matchOperator(Type.atom("abc"), Type.atom("abc"), context);
});
