defmodule Hologram.UI.RuntimeTest do
  use Hologram.Test.BasicCase, async: false

  alias Hologram.UI.Runtime

  setup do
    [
      context: %{
        {Hologram.Runtime, :csrf_token} => "test-csrf-token-12345",
        {Hologram.Runtime, :initial_page?} => false,
        {Hologram.Runtime, :instance_id} => "test-instance-id-abcde",
        {Hologram.Runtime, :page_bundle_path} => "/hologram/my-page-123.js",
        {Hologram.Runtime, :page_mounted?} => false,
        {Hologram.Runtime, :runtime_bundle_path} => "/hologram/runtime-456.js"
      }
    ]
  end

  test "initial page, page mounted", %{context: context} do
    context =
      context
      |> Map.put({Hologram.Runtime, :initial_page?}, true)
      |> Map.put({Hologram.Runtime, :page_mounted?}, true)

    markup = render_component(Runtime, %{}, context)

    refute String.contains?(markup, "globalThis.Hologram._pendingJsInteropActions")
    refute String.contains?(markup, "globalThis.Hologram.assetManifest")
    refute String.contains?(markup, "globalThis.Hologram.csrfToken")
    refute String.contains?(markup, "globalThis.Hologram.dispatchAction")
    refute String.contains?(markup, "globalThis.Hologram.instanceId")
    refute String.contains?(markup, "globalThis.Hologram.pageMountData")
    refute String.contains?(markup, "hologram/runtime")
    refute String.contains?(markup, "hologram/page")
  end

  test "initial page, page not mounted", %{context: context} do
    context = Map.put(context, {Hologram.Runtime, :initial_page?}, true)
    markup = render_component(Runtime, %{}, context)

    assert String.contains?(markup, "globalThis.Hologram._pendingJsInteropActions")
    assert String.contains?(markup, "globalThis.Hologram.assetManifest")
    assert String.contains?(markup, "globalThis.Hologram.csrfToken")
    assert String.contains?(markup, "globalThis.Hologram.dispatchAction")
    assert String.contains?(markup, "globalThis.Hologram.instanceId")
    assert String.contains?(markup, "globalThis.Hologram.pageMountData")
    assert String.contains?(markup, "hologram/runtime")
    assert String.contains?(markup, "/hologram/my-page-123.js")
  end

  test "not initial page, page mounted", %{context: initial_context} do
    context =
      initial_context
      |> Map.delete({Hologram.Runtime, :csrf_token})
      |> Map.delete({Hologram.Runtime, :instance_id})
      |> Map.put({Hologram.Runtime, :page_mounted?}, true)

    markup = render_component(Runtime, %{}, context)

    refute String.contains?(markup, "globalThis.Hologram._pendingJsInteropActions")
    refute String.contains?(markup, "globalThis.Hologram.assetManifest")
    refute String.contains?(markup, "globalThis.Hologram.csrfToken")
    refute String.contains?(markup, "globalThis.Hologram.dispatchAction")
    refute String.contains?(markup, "globalThis.Hologram.instanceId")
    refute String.contains?(markup, "globalThis.Hologram.pageMountData")
    refute String.contains?(markup, "hologram/runtime")
    refute String.contains?(markup, "hologram/page")
  end

  test "not initial page, page not mounted", %{context: initial_context} do
    context =
      initial_context
      |> Map.delete({Hologram.Runtime, :csrf_token})
      |> Map.delete({Hologram.Runtime, :instance_id})

    markup = render_component(Runtime, %{}, context)

    refute String.contains?(markup, "globalThis.Hologram._pendingJsInteropActions")
    refute String.contains?(markup, "globalThis.Hologram.assetManifest")
    refute String.contains?(markup, "globalThis.Hologram.csrfToken")
    refute String.contains?(markup, "globalThis.Hologram.dispatchAction")
    refute String.contains?(markup, "globalThis.Hologram.instanceId")
    assert String.contains?(markup, "globalThis.Hologram.pageMountData")
    refute String.contains?(markup, "hologram/runtime")
    assert String.contains?(markup, "/hologram/my-page-123.js")
  end

  test "csrf_token prop", %{context: initial_context} do
    context = Map.put(initial_context, {Hologram.Runtime, :initial_page?}, true)
    markup = render_component(Runtime, %{}, context)

    assert String.contains?(markup, ~s'globalThis.Hologram.csrfToken = "test-csrf-token-12345";')
  end

  test "instance_id prop", %{context: initial_context} do
    context = Map.put(initial_context, {Hologram.Runtime, :initial_page?}, true)
    markup = render_component(Runtime, %{}, context)

    assert String.contains?(
             markup,
             ~s'globalThis.Hologram.instanceId = "test-instance-id-abcde";'
           )
  end

  test "page_bundle_path prop", %{context: context} do
    markup = render_component(Runtime, %{}, context)

    assert String.contains?(
             markup,
             ~s'<script type="module" async src="/hologram/my-page-123.js">'
           )
  end
end
