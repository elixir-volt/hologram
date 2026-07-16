defmodule Hologram.Assets.BundleManifest do
  @moduledoc false

  use GenServer

  alias Hologram.Commons.ETS
  alias Hologram.Reflection

  @runtime_entry "runtime.entry.js"
  @runtime_key :runtime
  @url_prefix "/hologram/"

  @doc "Returns the path of Volt's production manifest."
  @callback manifest_path() :: String.t()

  @doc "Returns the name of the ETS table containing resolved entry URLs."
  @callback ets_table_name() :: atom

  @doc "Starts the bundle manifest registry."
  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl GenServer
  def init(nil) do
    table_name = impl().ets_table_name()
    ETS.create_named_table(table_name)
    populate(table_name)
    {:ok, nil}
  end

  @doc "Returns the public URL of the entry emitted for the given page module."
  @spec page_path(module) :: String.t()
  def page_path(page_module) do
    ETS.get!(impl().ets_table_name(), page_module)
  end

  @doc "Returns the public URL of the emitted runtime entry."
  @spec runtime_path() :: String.t()
  def runtime_path do
    ETS.get!(impl().ets_table_name(), @runtime_key)
  end

  @doc "Reloads entry URLs from Volt's production manifest."
  @spec reload() :: :ok
  def reload do
    table_name = impl().ets_table_name()
    ETS.reset(table_name)
    populate(table_name)
  end

  @doc "Returns the default path of Volt's production manifest."
  @spec manifest_path() :: String.t()
  def manifest_path do
    Path.join([Reflection.otp_app_static_dir(), "hologram", "manifest.json"])
  end

  @doc "Returns the default ETS table name for resolved entry URLs."
  @spec ets_table_name() :: atom
  def ets_table_name, do: __MODULE__

  defp populate(table_name) do
    manifest_path = impl().manifest_path()

    manifest =
      manifest_path
      |> File.read!()
      |> Jason.decode!()

    ETS.put(table_name, @runtime_key, entry_path(manifest, @runtime_entry))

    Enum.each(Reflection.list_pages(), fn page_module ->
      ETS.put(table_name, page_module, entry_path(manifest, page_entry(page_module)))
    end)

    :ok
  end

  defp entry_path(manifest, entry) do
    %{"file" => file, "isEntry" => true} = Map.fetch!(manifest, entry)
    @url_prefix <> file
  end

  defp page_entry(page_module) do
    Reflection.module_name(page_module) <> ".entry.js"
  end

  defp impl do
    Application.get_env(:hologram, :bundle_manifest_impl, __MODULE__)
  end
end
