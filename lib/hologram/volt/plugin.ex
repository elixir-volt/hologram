defmodule Hologram.Volt.Plugin do
  @moduledoc """
  Resolves Hologram's packaged browser runtime for Volt builds.

  Runtime modules are exposed through the stable `hologram:runtime/*` namespace,
  while their physical TypeScript sources remain private under Hologram's OTP
  `priv` directory.
  """

  @behaviour Volt.Plugin

  alias Volt.JS.Extensions

  @runtime_prefix "hologram:runtime/"
  @runtime_source {:hologram, "ts"}

  @impl Volt.Plugin
  def name, do: "hologram"

  @impl Volt.Plugin
  def resolve(@runtime_prefix <> relative, _importer) do
    @runtime_source
    |> Volt.Priv.path(relative)
    |> resolve_runtime_module(@runtime_prefix <> relative)
  end

  def resolve(_specifier, _importer), do: nil

  defp resolve_runtime_module(base, specifier) do
    path =
      base
      |> candidate_paths()
      |> Enum.find(&File.regular?/1)

    case path do
      nil -> {:error, {:module_not_found, specifier, nil}}
      path -> {:ok, path}
    end
  end

  defp candidate_paths(base) do
    exact_and_exts = Enum.map(Extensions.node_resolvable_with_exact(), &(base <> &1))
    index_files = Enum.map(Extensions.node_resolvable(), &Path.join(base, "index" <> &1))
    exact_and_exts ++ index_files
  end
end
