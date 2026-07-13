"use strict";

import Bitstring from "hologram:runtime/bitstring";

import {benchmark} from "../support/helpers.mjs";

const text =
  "全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全";

benchmark(() => {
  Bitstring.fromText(text);
});
