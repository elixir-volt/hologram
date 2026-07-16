defmodule Hologram.Test.NPMDeps do
  @moduledoc false

  alias Hologram.Assets.NPMDeps

  @test_packages %{
    "chai" => "6.2.2",
    "sinon" => "22.0.0"
  }

  @spec node_modules!() :: String.t()
  def node_modules! do
    packages = Map.merge(NPMDeps.packages(), @test_packages)
    %{node_modules: node_modules} = Volt.NPM.install!(packages)
    node_modules
  end
end
