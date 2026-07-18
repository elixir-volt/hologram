alias Hologram.Assets.BundleManifest
alias Hologram.Assets.ManifestCache, as: AssetManifestCache
alias Hologram.Assets.PathRegistry, as: AssetPathRegistry
alias Hologram.LiveReload
alias Hologram.Reflection
alias Hologram.Router.PageModuleResolver

# Create tmp dir if it doesn't exist yet.
File.mkdir_p!(Reflection.tmp_dir())

System.put_env(
  "SECRET_KEY_BASE",
  "test_secret_key_base_that_is_long_enough_for_testing_purposes_in_hologram"
)

# Skip tests that don't work reliably on either OS type
exclude_opts =
  case :os.type() do
    {:unix, _name} -> [:skip_on_unix]
    {:win32, _name} -> [:skip_on_windows]
  end

ExUnit.start(exclude: exclude_opts)

ex_unit_config = ExUnit.configuration()

tag_configured? = fn filters, tag ->
  Enum.any?(filters, fn
    ^tag -> true
    {^tag, _value} -> true
    _other -> false
  end)
end

included_tags = ex_unit_config[:include]
excluded_tags = ex_unit_config[:exclude]

javascript_tests_requested? =
  not tag_configured?.(excluded_tags, :js) and
    (included_tags == [] or tag_configured?.(included_tags, :js) or
       tag_configured?.(included_tags, :browser_js))

if javascript_tests_requested? do
  browser_files = ~w[
    test/javascript/elixir/hologram/js_test.mjs
    test/javascript/events/change_event_test.mjs
    test/javascript/events/submit_event_test.mjs
    test/javascript/intl_pluralrules_test.mjs
    test/javascript/live_reload_test.mjs
    test/javascript/vdom_test.mjs
  ]

  common_opts = [
    root: ".",
    granularity: :file,
    playwright: [executable: Path.expand("assets/node_modules/playwright/cli.js")],
    bundle: [
      aliases: %{
        "hologram:test/browser-helpers" =>
          Path.expand("test/javascript/support/browser_helpers.mjs")
      },
      plugins: [Hologram.Volt.Plugin],
      node_modules: Hologram.Test.NPMDeps.node_modules!()
    ]
  ]

  common_opts
  |> Keyword.merge(
    include: ["test/javascript/**/*_test.mjs"],
    exclude: browser_files,
    setup_files: [
      Path.expand("test/javascript/support/setup.mjs"),
      Path.expand("test/javascript/support/quickbeam_setup.mjs")
    ]
  )
  |> Volt.Test.ExUnit.install()

  common_opts
  |> Keyword.merge(
    include: browser_files,
    browser: true,
    setup_files: [Path.expand("test/javascript/support/setup.mjs")]
  )
  |> Volt.Test.ExUnit.install()
end

Mox.defmock(AssetManifestCacheMock, for: AssetManifestCache)
Application.put_env(:hologram, :asset_manifest_cache_impl, AssetManifestCacheMock)

Mox.defmock(AssetPathRegistryMock, for: AssetPathRegistry)
Application.put_env(:hologram, :asset_path_registry_impl, AssetPathRegistryMock)

Mox.defmock(LiveReloadMock, for: LiveReload)
Application.put_env(:hologram, :live_reload_impl, LiveReloadMock)

Mox.defmock(PageModuleResolverMock, for: PageModuleResolver)
Application.put_env(:hologram, :page_module_resolver_impl, PageModuleResolverMock)

Mox.defmock(BundleManifestMock, for: BundleManifest)
Application.put_env(:hologram, :bundle_manifest_impl, BundleManifestMock)
