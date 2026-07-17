defmodule Hologram.Test.NPMDeps do
  @moduledoc false

  alias Hologram.Assets.NPMDeps

  @lockfile Path.expand("../../npm.lock", __DIR__)

  @test_packages %{
    "chai" => "6.2.2",
    "sinon" => "22.0.0"
  }

  @spec packages() :: %{String.t() => String.t()}
  def packages, do: Map.merge(NPMDeps.packages(), @test_packages)

  @spec node_modules!() :: String.t()
  def node_modules! do
    %{node_modules: node_modules} = Volt.NPM.install!(packages(), lockfile: @lockfile)
    node_modules
  end
end
