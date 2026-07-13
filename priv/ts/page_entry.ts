"use strict";

import PerformanceTimer from "hologram:runtime/performance_timer";
$import_statements;

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
  $js_bindings_registration_call;
  $erlang_function_defs;
  $elixir_function_defs;
};

globalThis.Hologram.pageScriptLoaded = true;
document.dispatchEvent(new CustomEvent("hologram:pageScriptLoaded"));

console.debug(
  "Hologram: page script executed in",
  PerformanceTimer.diff(startTime),
);
