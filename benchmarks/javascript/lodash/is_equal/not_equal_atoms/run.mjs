"use strict";

import Type from "hologram:runtime/type";

import {benchmark} from "../../../support/helpers.mjs";

import isEqual from "lodash/isEqual.js";

const atom1 = Type.atom("abc");
const atom2 = Type.atom("xyz");

benchmark(() => {
  isEqual(atom1, atom2);
});
