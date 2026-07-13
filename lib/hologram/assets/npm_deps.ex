defmodule Hologram.Assets.NPMDeps do
  @moduledoc false

  alias Volt.JS.Runtime.Installer

  @runtime_packages %{
    "@formatjs/intl-getcanonicallocales" => "3.2.11",
    "@formatjs/intl-locale" => "5.3.10",
    "@formatjs/intl-pluralrules" => "6.3.12",
    "lodash" => "4.18.1",
    "snabbdom" => "3.6.4",
    "snabbdom-to-html" => "7.1.0"
  }

  @doc false
  @spec packages() :: %{String.t() => String.t()}
  def packages, do: @runtime_packages

  @doc false
  @spec node_modules!() :: String.t()
  def node_modules!, do: install!(@runtime_packages)

  defp install!(packages) do
    %{node_modules: node_modules} = Installer.install!(packages)
    node_modules
  end
end
