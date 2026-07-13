defmodule Hologram.Test.VoltCanonicalSuite do
  @moduledoc false

  alias Volt.Test.Assertions
  alias Volt.Test.BrowserRunner
  alias Volt.Test.Config
  alias Volt.Test.Runner

  @browser_files ~w[
    test/javascript/elixir/hologram/js_test.mjs
    test/javascript/events/change_event_test.mjs
    test/javascript/events/submit_event_test.mjs
    test/javascript/live_reload_test.mjs
    test/javascript/vdom_test.mjs
  ]

  @spec browser_files() :: [String.t()]
  def browser_files, do: @browser_files

  @spec install([Path.t()], keyword()) :: [module()]
  def install(files, opts) do
    {browser_paths, opts_without_browser} = Keyword.pop(opts, :browser_files, [])

    {parity_files, config_opts} = Keyword.pop(opts_without_browser, :parity_files, %{})
    config = Config.read(config_opts)
    browser_set = MapSet.new(browser_paths)

    Enum.map(files, fn file ->
      runner =
        if MapSet.member?(browser_set, file),
          do: BrowserRunner,
          else: Runner

      define_test_module(file, config, runner, Map.get(parity_files, file))
    end)
  end

  @spec names_hash([map()]) :: String.t()
  def names_hash(tests) do
    tests
    |> Enum.map(& &1.full_name)
    |> Enum.sort()
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec assert_parity!(map(), map() | nil) :: :ok
  def assert_parity!(_result, nil), do: :ok

  def assert_parity!(result, expected) do
    actual_hash = names_hash(result.tests)

    expected_count = expected["count"]
    expected_hash = expected["namesSha256"]

    if result.total != expected_count or actual_hash != expected_hash do
      raise ExUnit.AssertionError,
        message:
          "canonical JavaScript parity mismatch for #{result.file}: " <>
            "expected #{expected_count} tests / #{expected_hash}, " <>
            "got #{result.total} tests / #{actual_hash}"
    end

    :ok
  end

  defp define_test_module(file, config, runner, parity) do
    expanded_file = Path.expand(file)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    module = Module.concat([Hologram.Test.Generated.VoltJSTest, module_suffix(expanded_file)])

    unless Code.ensure_loaded?(module) do
      quoted =
        quote do
          defmodule unquote(module) do
            use ExUnit.Case, async: false

            @moduletag js: true
            @moduletag canonical_js: true

            if unquote(runner) == Volt.Test.BrowserRunner do
              @moduletag browser_js: true
            end

            test unquote(Path.relative_to_cwd(file)) do
              assert {:ok, result} =
                       unquote(runner).run_file(unquote(expanded_file),
                         config: unquote(Macro.escape(config))
                       )

              unquote(Assertions).assert_passed!(result)
              unquote(__MODULE__).assert_parity!(result, unquote(Macro.escape(parity)))
            end
          end
        end

      Code.compile_quoted(quoted, file)
    end

    module
  end

  defp module_suffix(file) do
    hash =
      file
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    "Test" <> binary_part(hash, 0, 16)
  end
end
