"use strict";

import {benchmark} from "../../../../support/helpers.mjs";

const text =
  "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij";

benchmark(() => {
  void new Blob([text]).size;
});
