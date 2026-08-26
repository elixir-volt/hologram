defmodule App1.TestCase do
  use ExUnit.CaseTemplate

  setup do
    if System.get_env("GITHUB_ACTIONS") == "true" do
      IO.inspect(
        {:ets.whereis(Hologram.Assets.BundleManifest), Process.whereis(Hologram.Supervisor),
         Application.started_applications()},
        label: "bundle manifest before feature"
      )
    end

    :ok
  end

  using do
    quote do
      use Wallaby.Feature

      import Hologram.Test.FeatureHelpers
      import Wallaby.Browser, except: [visit: 2]
      import Wallaby.Query
    end
  end
end
