import Config

config :hologram,
  debug_encoder: false,
  debug_parser: false,
  debug_transformer: false

config :volt,
  root: ".",
  sources: ["priv/ts/**/*.ts"],
  ignore: []

config :volt, :format,
  root: ".",
  sources: [
    "benchmarks/javascript/**/*.{js,mjs,ts,jsx,tsx}",
    "priv/ts/**/*.{js,ts,jsx,tsx}",
    "scripts/**/*.{js,mjs,ts,jsx,tsx}",
    "test/javascript_volt/**/*.{js,mjs,ts,jsx,tsx}"
  ],
  ignore: [],
  bracket_spacing: false

config :volt, :lint,
  root: ".",
  sources: [
    "assets/*.mjs",
    "benchmarks/javascript/**/*.{js,mjs,ts,jsx,tsx}",
    "priv/ts/**/*.{js,ts,jsx,tsx}",
    "scripts/**/*.{js,mjs,ts,jsx,tsx}",
    "test/javascript/**/*.{js,mjs,ts,jsx,tsx}",
    "test/javascript_volt/**/*.{js,mjs,ts,jsx,tsx}"
  ],
  ignore: [],
  env: [:browser, :node, :mocha],
  globals: %{
    "Elixir_Code" => :readonly,
    "Elixir_Enum" => :readonly,
    "Elixir_Exception" => :readonly,
    "Elixir_Hologram_Router_Helpers" => :readonly,
    "Elixir_Kernel" => :readonly,
    "Elixir_Map" => :readonly,
    "Elixir_String_Chars" => :readonly,
    "Erlang" => :readonly,
    "Erlang_Binary" => :readonly,
    "Erlang_Code" => :readonly,
    "Erlang_Elixir_Aliases" => :readonly,
    "Erlang_Elixir_Locals" => :readonly,
    "Erlang_Filename" => :readonly,
    "Erlang_Lists" => :readonly,
    "Erlang_Maps" => :readonly,
    "Erlang_Math" => :readonly,
    "Erlang_Os" => :readonly,
    "Erlang_Persistent_Term" => :readonly,
    "Erlang_Rand" => :readonly,
    "Erlang_Re" => :readonly,
    "Erlang_Sets" => :readonly,
    "Erlang_Unicode" => :readonly
  },
  plugins: [:typescript],
  rules: %{
    "correctness" => :deny,
    "no-control-regex" => :deny,
    "no-unused-expressions" => :deny,
    "no-unused-vars" => :deny
  }

import_config "#{config_env()}.exs"
