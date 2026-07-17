defmodule Hologram.Test.JavaScriptSuite do
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
    {browser_paths, config_opts} = Keyword.pop(opts, :browser_files, [])
    config = Config.read(config_opts)
    browser_set = MapSet.new(browser_paths)

    Enum.map(files, fn file ->
      runner =
        if MapSet.member?(browser_set, file),
          do: BrowserRunner,
          else: Runner

      define_test_module(file, config, runner)
    end)
  end

  defp define_test_module(file, config, runner) do
    expanded_file = Path.expand(file)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    module = Module.concat([Hologram.Test.Generated.JavaScriptTest, module_suffix(expanded_file)])

    unless Code.ensure_loaded?(module) do
      quoted =
        quote do
          defmodule unquote(module) do
            use ExUnit.Case, async: false

            @moduletag js: true

            if unquote(runner) == Volt.Test.BrowserRunner do
              @moduletag browser_js: true
            end

            test unquote(Path.relative_to_cwd(file)) do
              assert {:ok, result} =
                       unquote(runner).run_file(unquote(expanded_file),
                         config: unquote(Macro.escape(config))
                       )

              unquote(Assertions).assert_passed!(result)
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
