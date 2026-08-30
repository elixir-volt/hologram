defmodule Hologram.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Hologram.Supervisor]

    Hologram.env()
    |> children()
    |> Supervisor.start_link(opts)
  end

  @doc false
  @spec restart_children() :: :ok
  def restart_children do
    Hologram.Supervisor
    |> Supervisor.which_children()
    |> Enum.each(fn {child_id, _pid, _type, _modules} ->
      :ok = Supervisor.terminate_child(Hologram.Supervisor, child_id)
      :ok = Supervisor.delete_child(Hologram.Supervisor, child_id)
    end)

    Hologram.env()
    |> children()
    |> Enum.each(fn child_spec ->
      {:ok, _pid} = Supervisor.start_child(Hologram.Supervisor, child_spec)
    end)
  end

  defp children(:dev) do
    if Hologram.enabled?() do
      # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
      base_children() ++ [Hologram.LiveReload]
    else
      []
    end
  end

  defp children(_env) do
    if Hologram.enabled?() do
      base_children()
    else
      []
    end
  end

  defp base_children do
    [
      {Phoenix.PubSub, name: Hologram.PubSub},
      Hologram.Router.PageModuleResolver,
      Hologram.Assets.PathRegistry,
      Hologram.Assets.ManifestCache,
      Hologram.Assets.BundleManifest,
      Hologram.Realtime.Handshake,
      Hologram.Realtime.SubscriptionRegistry,
      Hologram.Realtime.Tombstone
    ]
  end
end
