import Config

config :hologram,
  debug_encoder: false,
  debug_parser: false,
  debug_transformer: false

config :volt,
  root: ".",
  sources: ["priv/ts/**/*.ts"],
  ignore: []

config :volt, :lint,
  plugins: [:typescript],
  rules: %{
    "no-control-regex" => :deny,
    "no-unused-expressions" => :deny,
    "no-unused-vars" => :deny
  }

import_config "#{config_env()}.exs"
