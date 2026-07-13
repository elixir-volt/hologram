"use strict";

import Bitstring from "hologram:runtime/bitstring";
import Type from "hologram:runtime/type";

import {benchmark} from "../../../../support/helpers.mjs";

const bitstring = Type.bitstring(
  "全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全全息图全息图全息图全",
);

Bitstring.maybeSetBytesFromText(bitstring);

benchmark(() => {
  let binaryString = "";

  for (let i = 0; i < bitstring.bytes.length; i++) {
    binaryString += String.fromCharCode(bitstring.bytes[i]);
  }

  btoa(binaryString);
});
