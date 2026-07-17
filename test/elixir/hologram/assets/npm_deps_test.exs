defmodule Hologram.Assets.NPMDepsTest do
  use ExUnit.Case, async: false

  alias Hologram.Assets.NPMDeps

  @lockfile Volt.Priv.path(:hologram, "npm.lock")

  test "package-owned lockfile pins every direct runtime package" do
    assert {:ok, lockfile} = NPM.Lockfile.read(@lockfile)

    Enum.each(NPMDeps.packages(), fn {name, version} ->
      assert %{version: ^version} = lockfile[name]
    end)
  end

  test "installs runtime packages from the package-owned lockfile" do
    node_modules = NPMDeps.node_modules!()

    Enum.each(NPMDeps.packages(), fn {name, _version} ->
      assert File.regular?(Path.join([node_modules, name, "package.json"]))
    end)
  end
end
