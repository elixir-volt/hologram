root = Path.expand("..", __DIR__)
files = Path.wildcard(Path.join(root, "test/javascript/**/*_test.mjs"))

browser_files = MapSet.new(Hologram.Test.VoltCanonicalSuite.browser_files())

node_modules = Hologram.Test.NPMDeps.node_modules!()

config =
  Volt.Test.Config.read(
    setup_files: [Path.join(root, "test/javascript_volt/setup.mjs")],
    playwright: [executable: Path.join(root, "assets/node_modules/.bin/playwright")],
    bundle: [
      aliases: %{
        "hologram:test/browser-helpers" =>
          Path.join(root, "test/javascript_volt/browser_helpers.mjs")
      },
      plugins: [Hologram.Volt.Plugin],
      node_modules: node_modules
    ]
  )

manifest_files =
  Enum.map(files, fn file ->
    relative = Path.relative_to(file, root)

    runner =
      if MapSet.member?(browser_files, relative),
        do: Volt.Test.BrowserRunner,
        else: Volt.Test.Runner

    {:ok, result} = runner.run_file(file, config: config)
    Volt.Test.Assertions.assert_passed!(result)
    names_hash = Hologram.Test.VoltCanonicalSuite.names_hash(result.tests)

    {relative,
     %Jason.OrderedObject{
       values: [
         {"count", result.total},
         {"namesSha256", names_hash}
       ]
     }}
  end)

file_count = length(manifest_files)
test_count =
  Enum.sum(
    Enum.map(manifest_files, fn {_file, %Jason.OrderedObject{values: [{"count", count} | _]}} ->
      count
    end)
  )

manifest = %Jason.OrderedObject{
  values: [
    {"version", 1},
    {"totalFiles", file_count},
    {"totalTests", test_count},
    {"files", %Jason.OrderedObject{values: manifest_files}}
  ]
}

output = Path.join(root, "test/javascript_volt/canonical_manifest.json")
File.write!(output, Jason.encode_to_iodata!(manifest, pretty: true) |> IO.iodata_to_binary())
File.write!(output, "\n", [:append])
IO.puts(
  "Wrote #{Path.relative_to(output, root)} (#{file_count} files, #{test_count} tests)"
)
