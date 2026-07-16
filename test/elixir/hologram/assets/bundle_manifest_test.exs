defmodule Hologram.Assets.BundleManifestTest do
  use Hologram.Test.BasicCase, async: false

  import Hologram.Assets.BundleManifest
  import Hologram.Test.Stubs
  import Mox

  alias Hologram.Assets.BundleManifest
  alias Hologram.Commons.ETS
  alias Hologram.Reflection

  use_module_stub :bundle_manifest

  setup :set_mox_global

  setup do
    setup_bundle_manifest(BundleManifestStub, false)
  end

  test "init/1" do
    assert init(nil) == {:ok, nil}

    mapping = ETS.get_all(BundleManifestStub.ets_table_name())
    assert mapping[:runtime] == "/hologram/runtime.entry.js"

    Enum.each(Reflection.list_pages(), fn page_module ->
      assert mapping[page_module] ==
               "/hologram/#{Reflection.module_name(page_module)}.entry.js"
    end)
  end

  describe "entry paths" do
    setup do
      init(nil)
      :ok
    end

    test "returns the runtime entry path" do
      assert runtime_path() == "/hologram/runtime.entry.js"
    end

    test "returns a page entry path" do
      page_module = List.first(Reflection.list_pages())

      assert page_path(page_module) ==
               "/hologram/#{Reflection.module_name(page_module)}.entry.js"
    end

    test "raises when a page entry doesn't exist" do
      assert_raise KeyError, fn -> page_path(:missing_page) end
    end
  end

  test "reload/0" do
    BundleManifest.start_link([])

    table_name = BundleManifestStub.ets_table_name()
    ETS.put(table_name, :dummy_key, :dummy_value)

    reload()

    refute table_name
           |> ETS.get_all()
           |> Map.has_key?(:dummy_key)

    assert runtime_path() == "/hologram/runtime.entry.js"
  end

  test "start_link/1" do
    assert {:ok, pid} = BundleManifest.start_link([])
    assert is_pid(pid)
    assert ets_table_exists?(BundleManifestStub.ets_table_name())
  end
end
