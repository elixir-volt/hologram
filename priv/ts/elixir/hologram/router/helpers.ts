"use strict";

import AssetPathRegistry from "../../../asset_path_registry.ts";
import Bitstring from "../../../bitstring.ts";
import Interpreter from "../../../interpreter.ts";
import Type from "../../../type.ts";

const Elixir_Hologram_Router_Helpers = {
  "asset_path/1": (staticPath) => {
    const assetPath = AssetPathRegistry.lookup(staticPath);

    if (Type.isNil(assetPath)) {
      const message = `there is no such asset: "${Bitstring.toText(
        staticPath,
      )}"`;

      Interpreter.raiseError("Hologram.AssetNotFoundError", message);
    }

    return assetPath;
  },
};

export default Elixir_Hologram_Router_Helpers;
