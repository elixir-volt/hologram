/* oxlint-disable no-unused-expressions, no-unused-vars -- generated placeholders and injected definitions */
"use strict";

import PerformanceTimer from "hologram:runtime/performance_timer";
$imports;

const startTime = performance.now();

globalThis.Hologram.pageReachableFunctionDefs = (deps) => {
  const {
    Bitstring,
    ERTS,
    HologramBoxedError,
    HologramInterpreterError,
    Interpreter,
    MemoryStorage,
    Type,
    Utils,
  } = deps;
  $function_definitions;
};

globalThis.Hologram.pageScriptLoaded = true;
document.dispatchEvent(new CustomEvent("hologram:pageScriptLoaded"));

console.debug("Hologram: page script executed in", PerformanceTimer.diff(startTime));
