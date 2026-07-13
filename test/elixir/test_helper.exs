alias Hologram.Assets.ManifestCache, as: AssetManifestCache
alias Hologram.Assets.PageDigestRegistry
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

canonical_js_test_files = Path.wildcard("test/javascript/**/*_test.mjs")

canonical_js_manifest =
  "test/javascript_volt/canonical_manifest.json"
  |> File.read!()
  |> Jason.decode!()

canonical_js_parity_files = canonical_js_manifest["files"]

canonical_js_manifest_files =
  canonical_js_parity_files
  |> Map.keys()
  |> Enum.sort()

canonical_js_manifest_test_count =
  canonical_js_parity_files
  |> Map.values()
  |> Enum.reduce(0, &(&1["count"] + &2))

unless canonical_js_manifest["version"] == 1 and
         canonical_js_manifest["totalFiles"] == map_size(canonical_js_parity_files) and
         canonical_js_manifest["totalTests"] == canonical_js_manifest_test_count and
         canonical_js_manifest_files == canonical_js_test_files do
  raise "canonical JavaScript test manifest is stale"
end

Hologram.Test.VoltCanonicalSuite.install(
  ["test/javascript_volt/intl_pluralrules_test.mjs" | canonical_js_test_files],
  parity_files: canonical_js_parity_files,
  browser_files: Hologram.Test.VoltCanonicalSuite.browser_files(),
  setup_files: [Path.expand("test/javascript_volt/setup.mjs")],
  playwright: [executable: Path.expand("assets/node_modules/.bin/playwright")],
  bundle: [
    aliases: %{
      "hologram:test/browser-helpers" => Path.expand("test/javascript_volt/browser_helpers.mjs")
    },
    plugins: [Hologram.Volt.Plugin],
    node_modules: Hologram.Test.NPMDeps.node_modules!()
  ]
)

Mox.defmock(AssetManifestCacheMock, for: AssetManifestCache)
Application.put_env(:hologram, :asset_manifest_cache_impl, AssetManifestCacheMock)

Mox.defmock(AssetPathRegistryMock, for: AssetPathRegistry)
Application.put_env(:hologram, :asset_path_registry_impl, AssetPathRegistryMock)

Mox.defmock(LiveReloadMock, for: LiveReload)
Application.put_env(:hologram, :live_reload_impl, LiveReloadMock)

Mox.defmock(PageModuleResolverMock, for: PageModuleResolver)
Application.put_env(:hologram, :page_module_resolver_impl, PageModuleResolverMock)

Mox.defmock(PageDigestRegistryMock, for: PageDigestRegistry)
Application.put_env(:hologram, :page_digest_registry_impl, PageDigestRegistryMock)
