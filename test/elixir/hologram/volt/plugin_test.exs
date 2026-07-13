defmodule Hologram.Volt.PluginTest do
  use Hologram.Test.BasicCase, async: true

  alias Hologram.Reflection
  alias Hologram.Volt.Plugin

  @runtime_source {:hologram, "ts"}

  test "resolves Hologram runtime specifiers from priv/ts" do
    assert Plugin.resolve("hologram:runtime/memory_storage", nil) ==
             {:ok, Volt.Priv.path(@runtime_source, "memory_storage.ts")}
  end

  test "ignores unrelated imports" do
    importer = Path.join([Reflection.root_dir(), "test", "javascript", "example_test.mjs"])

    assert Plugin.resolve("./support/helpers.mjs", importer) == nil
  end
end
