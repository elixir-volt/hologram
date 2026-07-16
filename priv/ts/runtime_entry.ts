/* oxlint-disable no-unused-expressions, no-unused-vars -- generated placeholders and injected definitions */
"use strict";

import Bitstring from "hologram:runtime/bitstring";
import ERTS from "hologram:runtime/erts";
import Hologram from "hologram:runtime/hologram";
import HologramBoxedError from "hologram:runtime/errors/boxed_error";
import HologramInterpreterError from "hologram:runtime/errors/interpreter_error";
import Interpreter from "hologram:runtime/interpreter";
import MemoryStorage from "hologram:runtime/memory_storage";
import PerformanceTimer from "hologram:runtime/performance_timer";
import Type from "hologram:runtime/type";
import Utils from "hologram:runtime/utils";

const startTime = PerformanceTimer.start();
$function_definitions;

document.addEventListener("hologram:pageScriptLoaded", () => Hologram.run());

if (globalThis.Hologram.pageScriptLoaded) {
  document.dispatchEvent(new CustomEvent("hologram:pageScriptLoaded"));
}

console.debug("Hologram: runtime script executed in", PerformanceTimer.diff(startTime));
