"use strict";

import Interpreter from "hologram:runtime/interpreter";
import Type from "hologram:runtime/type";

import {benchmark} from "../../../support/helpers.mjs";

const atom1 = Type.atom("abc");
const atom2 = Type.atom("xyz");

benchmark(() => {
  Interpreter.isStrictlyEqual(atom1, atom2);
});
