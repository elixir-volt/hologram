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

included_tags = ExUnit.configuration()[:include]

javascript_tests_requested? =
  System.get_env("HOLOGRAM_SKIP_JAVASCRIPT_TESTS") != "1" and
    (included_tags == [] or :js in included_tags)

if javascript_tests_requested? do
  "test/javascript/**/*_test.mjs"
  |> Path.wildcard()
  |> Hologram.Test.JavaScriptSuite.install(
    browser_files: Hologram.Test.JavaScriptSuite.browser_files(),
    setup_files: [Path.expand("test/javascript/support/setup.mjs")],
    playwright: [executable: Path.expand("assets/node_modules/.bin/playwright")],
    bundle: [
      aliases: %{
        "hologram:test/browser-helpers" =>
          Path.expand("test/javascript/support/browser_helpers.mjs")
      },
      plugins: [Hologram.Volt.Plugin],
      node_modules: Hologram.Test.NPMDeps.node_modules!()
    ]
  )
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
