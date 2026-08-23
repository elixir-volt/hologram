defmodule Hologram.CompilerTest do
  use Hologram.Test.BasicCase, async: false
  import Hologram.Compiler

  alias Hologram.Commons.PLT
  alias Hologram.Compiler
  alias Hologram.Compiler.CallGraph
  alias Hologram.Compiler.Context
  alias Hologram.Compiler.Digraph
  alias Hologram.Compiler.Encoder
  alias Hologram.Compiler.IR
  alias Hologram.Reflection

  alias Hologram.Test.Fixtures.Compiler.Module1
  alias Hologram.Test.Fixtures.Compiler.Module11
  alias Hologram.Test.Fixtures.Compiler.Module12
  alias Hologram.Test.Fixtures.Compiler.Module13
  alias Hologram.Test.Fixtures.Compiler.Module14
  alias Hologram.Test.Fixtures.Compiler.Module15
  alias Hologram.Test.Fixtures.Compiler.Module17
  alias Hologram.Test.Fixtures.Compiler.Module19
  alias Hologram.Test.Fixtures.Compiler.Module2
  alias Hologram.Test.Fixtures.Compiler.Module21
  alias Hologram.Test.Fixtures.Compiler.Module23
  alias Hologram.Test.Fixtures.Compiler.Module24
  alias Hologram.Test.Fixtures.Compiler.Module25
  alias Hologram.Test.Fixtures.Compiler.Module26
  alias Hologram.Test.Fixtures.Compiler.Module27
  alias Hologram.Test.Fixtures.Compiler.Module28
  alias Hologram.Test.Fixtures.Compiler.Module29
  alias Hologram.Test.Fixtures.Compiler.Module3
  alias Hologram.Test.Fixtures.Compiler.Module30
  alias Hologram.Test.Fixtures.Compiler.Module32
  alias Hologram.Test.Fixtures.Compiler.Module34
  alias Hologram.Test.Fixtures.Compiler.Module36
  alias Hologram.Test.Fixtures.Compiler.Module37
  alias Hologram.Test.Fixtures.Compiler.Module38
  alias Hologram.Test.Fixtures.Compiler.Module4
  alias Hologram.Test.Fixtures.Compiler.Module40
  alias Hologram.Test.Fixtures.Compiler.Module8
  alias Hologram.Test.Fixtures.Compiler.Module9

  @js_dir Volt.Priv.path({:hologram, "ts"}, ".")
  @erlang_js_dir Path.join(@js_dir, "erlang")

  @fixtures_compiler_dir Path.join(@fixtures_dir, "compiler")
  @tmp_dir Reflection.tmp_dir()

  defp js_contains?(source, expected) do
    source = String.replace(source, ~r/\s+/u, "")
    expected = String.replace(expected, ~r/\s+/u, "")
    String.contains?(source, expected)
  end

  # validate_prop_usages/2 walks a module's template/0, so hand-built DOM IR has to be wrapped the way
  # a compiled module carries it. Built by hand rather than taken from a fixture module, because a
  # fixture with a deliberately invalid usage would fail the compile.hologram Mix task tests.
  defp module_ir_with_template(dom_ir) do
    # The module field is left unset - the message names the module validate_prop_usages/2 was given,
    # not the one recorded in the IR.
    %IR.ModuleDefinition{
      body: %IR.Block{
        expressions: [
          %IR.FunctionDefinition{
            name: :template,
            arity: 0,
            visibility: :public,
            clause: %IR.FunctionClause{
              params: [],
              guards: [],
              body: %IR.Block{expressions: [dom_ir]}
            }
          }
        ]
      }
    }
  end

  setup_all do
    ir_plt = build_ir_plt()
    call_graph = build_call_graph(ir_plt)

    [
      call_graph: call_graph,
      ir_plt: ir_plt,
      runtime_mfas: CallGraph.list_runtime_mfas(call_graph, Reflection.list_pages())
    ]
  end

  describe "aggregate_js_imports/1" do
    test "empty MFAs list" do
      assert aggregate_js_imports([]) == %{imports: [], bindings: %{}}
    end

    test "filters out Erlang modules" do
      mfas = [{:erlang, :+, 2}, {:maps, :get, 2}]

      assert aggregate_js_imports(mfas) == %{imports: [], bindings: %{}}
    end

    test "no modules have JS imports" do
      mfas = [{Enum, :map, 2}, {Kernel, :+, 2}]

      assert aggregate_js_imports(mfas) == %{imports: [], bindings: %{}}
    end

    test "skips modules that use Hologram.JS but have no imports" do
      mfas = [{Module13, :func, 0}]

      assert aggregate_js_imports(mfas) == %{imports: [], bindings: %{}}
    end

    test "single module with imports" do
      mfas = [{Module12, :func, 0}, {Enum, :map, 2}]

      assert aggregate_js_imports(mfas) == %{
               imports: [
                 %{from: "chart.js", export: "Chart", alias: "$1"},
                 %{from: "chart.js", export: "helpers", alias: "$2"}
               ],
               bindings: %{
                 Module12 => %{
                   "MyChart" => "$1",
                   "helpers" => "$2"
                 }
               }
             }
    end

    test "multiple modules with imports from different sources" do
      mfas = [{Module12, :func, 0}, {Module17, :func, 0}]

      assert aggregate_js_imports(mfas) == %{
               imports: [
                 %{from: "chart.js", export: "Chart", alias: "$1"},
                 %{from: "chart.js", export: "helpers", alias: "$2"},
                 %{from: "utils.js", export: "formatDate", alias: "$3"}
               ],
               bindings: %{
                 Module12 => %{
                   "MyChart" => "$1",
                   "helpers" => "$2"
                 },
                 Module17 => %{
                   "myFormatDate" => "$3"
                 }
               }
             }
    end

    test "deduplicates modules when multiple MFAs reference the same module" do
      mfas = [{Module12, :func_a, 0}, {Module12, :func_b, 1}]

      assert aggregate_js_imports(mfas) == %{
               imports: [
                 %{from: "chart.js", export: "Chart", alias: "$1"},
                 %{from: "chart.js", export: "helpers", alias: "$2"}
               ],
               bindings: %{
                 Module12 => %{
                   "MyChart" => "$1",
                   "helpers" => "$2"
                 }
               }
             }
    end

    test "deduplicates imports when multiple modules import the same export" do
      mfas = [{Module14, :func, 0}, {Module15, :func, 0}]

      assert aggregate_js_imports(mfas) == %{
               imports: [
                 %{from: "chart.js", export: "Chart", alias: "$1"}
               ],
               bindings: %{
                 Module14 => %{
                   "Chart" => "$1"
                 },
                 Module15 => %{
                   "MyChart" => "$1"
                 }
               }
             }
    end
  end

  describe "build_page_js/6" do
    setup %{call_graph: call_graph, runtime_mfas: runtime_mfas} do
      call_graph_without_runtime_mfas =
        call_graph
        |> CallGraph.clone()
        |> CallGraph.remove_runtime_mfas!(runtime_mfas)

      graph = CallGraph.get_graph(call_graph_without_runtime_mfas)
      templatables = Reflection.list_pages() ++ Reflection.list_components()

      server_callback_analysis_by_templatable =
        CallGraph.server_callback_analysis_by_templatable(graph, templatables)

      [
        call_graph: call_graph_without_runtime_mfas,
        server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
      ]
    end

    test "has both Erlang and Elixir function defs", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module24,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      js_fragment_1 = ~s/globalThis.Hologram.pageReachableFunctionDefs/
      js_fragment_2 = ~s/Interpreter.defineElixirFunction/
      js_fragment_3 = ~s/Interpreter.defineErlangFunction/

      assert js_contains?(result, js_fragment_1)
      assert js_contains?(result, js_fragment_2)
      assert js_contains?(result, js_fragment_3)
    end

    test "has only Elixir defs", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module25,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      js_fragment_1 = ~s/globalThis.Hologram.pageReachableFunctionDefs/
      js_fragment_2 = ~s/Interpreter.defineElixirFunction/
      js_fragment_3 = ~s/Interpreter.defineErlangFunction/

      assert js_contains?(result, js_fragment_1)
      assert js_contains?(result, js_fragment_2)
      refute js_contains?(result, js_fragment_3)
    end

    test "no JS imports", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module11,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      refute js_contains?(result, "import {")
      refute js_contains?(result, "registerJsBindings")
    end

    test "single JS import", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module19,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      js_fixture_path = Path.join([@fixtures_dir, "compiler", "js_fixture_1.mjs"])

      assert length(Regex.scan(~r/import \{/, result)) == 1
      assert js_contains?(result, ~s'import { export_1a as $1 } from "#{js_fixture_path}";')

      assert length(Regex.scan(~r/registerJsBindings/, result)) == 1

      assert js_contains?(
               result,
               ~s'Interpreter.registerJsBindings({"Hologram.Test.Fixtures.Compiler.Module18": {"alias_1a": $1}});'
             )
    end

    test "multiple JS imports", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module21,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      js_fixture_path = Path.join([@fixtures_dir, "compiler", "js_fixture_1.mjs"])

      assert length(Regex.scan(~r/import \{/, result)) == 2
      assert js_contains?(result, ~s'import { export_1a as $1 } from "#{js_fixture_path}";')
      assert js_contains?(result, ~s'import { export_1b as $2 } from "#{js_fixture_path}";')

      assert length(Regex.scan(~r/registerJsBindings/, result)) == 1

      assert js_contains?(
               result,
               ~s'Interpreter.registerJsBindings({"Hologram.Test.Fixtures.Compiler.Module20": {"alias_1a": $1, "alias_1b": $2}});'
             )
    end

    test "multiple modules with JS imports", %{
      call_graph: call_graph,
      ir_plt: ir_plt,
      server_callback_analysis_by_templatable: server_callback_analysis_by_templatable
    } do
      result =
        build_page_js(
          Module23,
          call_graph,
          ir_plt,
          MapSet.new(),
          server_callback_analysis_by_templatable,
          @js_dir
        )

      js_fixture_1_path = Path.join([@fixtures_dir, "compiler", "js_fixture_1.mjs"])
      js_fixture_2_path = Path.join([@fixtures_dir, "compiler", "js_fixture_2.mjs"])

      assert length(Regex.scan(~r/import \{/, result)) == 2
      assert js_contains?(result, ~s'import { export_1a as $1 } from "#{js_fixture_1_path}";')
      assert js_contains?(result, ~s'import { export_2 as $2 } from "#{js_fixture_2_path}";')

      assert length(Regex.scan(~r/registerJsBindings/, result)) == 1

      assert js_contains?(
               result,
               ~s'Interpreter.registerJsBindings({"Hologram.Test.Fixtures.Compiler.Module18": {"alias_1a": $1}, "Hologram.Test.Fixtures.Compiler.Module22": {"alias_2": $2}});'
             )
    end
  end

  test "build_call_graph/0" do
    assert %CallGraph{} = call_graph = build_call_graph()

    assert CallGraph.has_vertex?(call_graph, {Compiler, :build_call_graph, 1})
  end

  describe "build_call_graph/1" do
    test "builds call graph from IR PLT", %{ir_plt: ir_plt} do
      assert %CallGraph{} = call_graph = build_call_graph(ir_plt)

      assert CallGraph.has_vertex?(call_graph, {Compiler, :build_call_graph, 1})
    end

    test "adds non-discoverable edges", %{ir_plt: ir_plt} do
      call_graph = build_call_graph(ir_plt)

      assert CallGraph.has_edge?(call_graph, {:binary, :match, 2}, {:binary, :match, 3})
      assert CallGraph.has_edge?(call_graph, {Date, :new, 4}, {Calendar.ISO, :valid_date?, 3})
    end
  end

  test "build_ir_plt/0" do
    assert %PLT{} = ir_plt = build_ir_plt()

    assert %IR.ModuleDefinition{module: %IR.AtomType{value: Hologram.Compiler}} =
             PLT.get!(ir_plt, Hologram.Compiler)
  end

  describe "build_ir_plt/1" do
    test "module has BEAM path" do
      assert %PLT{} = ir_plt = build_ir_plt()

      assert %IR.ModuleDefinition{module: %IR.AtomType{value: Hologram.Compiler}} =
               PLT.get!(ir_plt, Hologram.Compiler)
    end

    test "module doesn't have BEAM path" do
      assert %PLT{} = ir_plt = build_ir_plt()
      assert PLT.get(ir_plt, MyModule) == :error
    end
  end

  describe "build_module_digest_plt!/0" do
    test "adds module digest entries for modules that have a BEAM path" do
      assert %PLT{} = plt = build_module_digest_plt!()

      assert plt
             |> PLT.get!(Hologram.Reflection)
             |> is_integer()

      assert plt
             |> PLT.get!(Hologram.Compiler)
             |> is_integer()
    end

    test "doesn't add module digest entries for modules that don't have a BEAM path" do
      assert %PLT{} = plt = build_module_digest_plt!()
      assert PLT.get(plt, MyModule) == :error
    end
  end

  describe "build_runtime_js/5" do
    setup do
      on_exit(fn ->
        Application.delete_env(:hologram, :client_error_overlay)
        Application.delete_env(:hologram, :client_stacktraces)
      end)

      :ok
    end

    test "renders reachable function defs", %{ir_plt: ir_plt, runtime_mfas: runtime_mfas} do
      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               ~s/Interpreter.defineElixirFunction("Enum", "into", 2, "public"/
             )

      assert js_contains?(
               js,
               ~s/Interpreter.defineElixirFunction("Enum", "into_protocol", 2, "private"/
             )

      assert js_contains?(
               js,
               ~s/Interpreter.defineElixirFunction("String.Chars", "to_string", 1, "public"/
             )

      assert js_contains?(
               js,
               ~s/Interpreter.defineElixirFunction("String.Chars", "impl_for!", 1, "public"/
             )

      refute js_contains?(js, "Hologram.Test.Fixtures.Compiler.CallGraph.Module12")

      assert js_contains?(js, ~s/Interpreter.defineErlangFunction("erlang", "error", 1/)

      assert js_contains?(
               js,
               ~s/Interpreter.defineNotImplementedErlangFunction("erlang", "process_info", 2/
             )
    end

    test "renders the clause heads of manually ported functions", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               ~s/Interpreter.defineFunctionClauseHeads("Code", "ensure_loaded", 1, "public", [{params: (context) => [Type.variablePattern("module_0")], guards: [(context) => Erlang["is_atom\/1"](context.vars.module_0)], blame: {params: ["module"], guards: [{source: "is_atom(module)", test: (context) => Erlang["is_atom\/1"](context.vars.module_0)}]}}]);/
             )

      # A default argument makes the ported arity differ from the raised one.
      assert js_contains?(
               js,
               ~s/Interpreter.defineFunctionClauseHeads("Task", "await", 2, "public"/
             )
    end

    test "injects the client config when the presentation settings are enabled", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_error_overlay, true)
      Application.put_env(:hologram, :client_stacktraces, true)

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               "globalThis.Hologram.config = {errorOverlay: true, stacktraces: true};"
             )
    end

    test "injects the client config when the presentation settings are disabled", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_error_overlay, false)
      Application.put_env(:hologram, :client_stacktraces, false)

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               "globalThis.Hologram.config = {errorOverlay: false, stacktraces: false};"
             )
    end

    test "registers the metadata of the modules it defines", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_stacktraces, true)

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               ~s/ERTS.registerModuleMetadata({"Access": {app: "elixir", file: "lib\/access.ex"/
             )
    end

    test "injects the versions of the applications the frames name", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_stacktraces, true)

      app_versions = [hologram: "0.1.0", my_app: "9.8.7"]

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), app_versions, @js_dir)

      assert js_contains?(
               js,
               ~s/ERTS.appVersions = {"hologram": "0.1.0", "my_app": "9.8.7"};/
             )
    end

    test "quotes an application name that isn't a JavaScript identifier", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_stacktraces, true)

      app_versions = [{:"my-app", "9.8.7"}]

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), app_versions, @js_dir)

      assert js_contains?(js, ~s/ERTS.appVersions = {"my-app": "9.8.7"};/)
    end

    test "injects no application versions when client stacktraces are disabled", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_stacktraces, false)

      app_versions = [hologram: "0.1.0", my_app: "9.8.7"]

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), app_versions, @js_dir)

      assert js_contains?(js, "ERTS.appVersions = {};")
    end

    test "injects the client config when the error overlay is opted out of", %{
      ir_plt: ir_plt,
      runtime_mfas: runtime_mfas
    } do
      Application.put_env(:hologram, :client_error_overlay, false)
      Application.put_env(:hologram, :client_stacktraces, true)

      js = build_runtime_js(runtime_mfas, ir_plt, MapSet.new(), [], @js_dir)

      assert js_contains?(
               js,
               "globalThis.Hologram.config = {errorOverlay: false, stacktraces: true};"
             )
    end
  end

  describe "build_assets/2" do
    test "builds entries through Volt" do
      tmp_dir = Path.join([Reflection.tmp_dir(), "tests", "compiler", "build_assets_2"])
      static_dir = Path.join(tmp_dir, "static")
      clean_dir(tmp_dir)
      File.mkdir_p!(static_dir)

      entry_file_path = Path.join(tmp_dir, "MyPage.entry.ts")
      File.write!(entry_file_path, "export const myVar: number = 123;\n")

      result = build_assets([entry_file_path], static_dir: static_dir, tmp_dir: tmp_dir)

      assert %Volt.Builder.ManifestEntry{
               file: file,
               isEntry: true,
               src: "MyPage.entry.js"
             } = result.manifest["MyPage.entry.js"]

      assert static_dir
             |> Path.join(file)
             |> File.regular?()

      assert static_dir
             |> Path.join(file <> ".map")
             |> File.regular?()

      assert static_dir
             |> Path.join("manifest.json")
             |> File.regular?()
    end
  end

  describe "get_erlang_function_js/4" do
    test ":erlang module function that is implemented" do
      result = get_erlang_function_js(:erlang, :+, 2, @erlang_js_dir)

      expected =
        normalize_newlines("""
        (left, right) => {
            if (!Type.isNumber(left) || !Type.isNumber(right)) {
              Interpreter.raiseBifError("badarith", "erlang", "+", [left, right]);
            }

            const [type, leftValue, rightValue] = Type.maybeNormalizeNumberTerms(left, right);

            const result = leftValue.value + rightValue.value;

            return type === "float" ? Type.float(result) : Type.integer(result);
          }\
        """)

      assert normalize_newlines(result) == expected
    end

    test ":erlang module function that is not implemented" do
      result = Compiler.get_erlang_function_js(:erlang, :not_implemented, 2, @erlang_js_dir)
      assert result == nil
    end

    test ":maps module function that is implemented" do
      result = Compiler.get_erlang_function_js(:maps, :get, 2, @erlang_js_dir)

      expected =
        normalize_newlines("""
        (key, map) => {
            if (!Type.isMap(map)) {
              Interpreter.raiseBifError(["badmap", map], "erlang", "map_get", [key, map]);
            }

            const encodedKey = Type.encodeMapKey(key);

            if (map.data[encodedKey]) {
              return map.data[encodedKey][1];
            }

            Interpreter.raiseBifError(["badkey", key], "erlang", "map_get", [key, map]);
          }\
        """)

      assert normalize_newlines(result) == expected
    end

    test ":maps module function that is not implemented" do
      result = Compiler.get_erlang_function_js(:maps, :not_implemented, 2, @erlang_js_dir)
      assert result == nil
    end

    test "no comment lines between start marker and key" do
      result =
        Compiler.get_erlang_function_js(:erlang_fixture, :no_comments, 1, @fixtures_compiler_dir)

      expected =
        normalize_newlines("""
        (x) => {
            return x;
          }\
        """)

      assert normalize_newlines(result) == expected
    end

    test "single comment line between start marker and key" do
      result =
        Compiler.get_erlang_function_js(
          :erlang_fixture,
          :single_comment,
          0,
          @fixtures_compiler_dir
        )

      expected =
        normalize_newlines("""
        () => {
            return 1;
          }\
        """)

      assert normalize_newlines(result) == expected
    end

    test "multiple comment lines between start marker and key" do
      result =
        Compiler.get_erlang_function_js(
          :erlang_fixture,
          :multiple_comments,
          2,
          @fixtures_compiler_dir
        )

      expected =
        normalize_newlines("""
        (a, b) => {
            return a + b;
          }\
        """)

      assert normalize_newlines(result) == expected
    end

    test "module file doesn't exist" do
      result = Compiler.get_erlang_function_js(:non_existing_module, :some_fun, 1, @erlang_js_dir)
      assert result == nil
    end
  end

  test "group_mfas_by_module/1" do
    mfas = [
      {:module_1, :fun_a, 1},
      {:module_2, :fun_b, 2},
      {:module_3, :fun_c, 3},
      {:module_1, :fun_d, 3},
      {:module_2, :fun_e, 1},
      {:module_3, :fun_f, 2}
    ]

    assert group_mfas_by_module(mfas) == %{
             module_1: [{:module_1, :fun_a, 1}, {:module_1, :fun_d, 3}],
             module_2: [{:module_2, :fun_b, 2}, {:module_2, :fun_e, 1}],
             module_3: [{:module_3, :fun_c, 3}, {:module_3, :fun_f, 2}]
           }
  end

  describe "list_component_usages/1" do
    test "collects plain and nested usages, in template order" do
      usages =
        Module28
        |> IR.for_module()
        |> list_component_usages()

      assert usages == [
               {Module27, [{"a", {:ok, "1"}}, {"b", :unknown}], false},
               {Module27, [{"a", {:ok, "2"}}], false},
               {Module27, [{"b", {:ok, "3"}}], false}
             ]
    end

    test "reports the value of a prop written as a literal expression" do
      usages =
        Module38
        |> IR.for_module()
        |> list_component_usages()

      assert usages == [
               {Module37, [{"size", {:ok, :small}}, {"label", {:ok, "abc"}}, {"free", :unknown}],
                false}
             ]
    end

    test "flags a usage carrying a spread" do
      usages =
        Module29
        |> IR.for_module()
        |> list_component_usages()

      assert usages == [
               {Module27, [{"a", {:ok, "1"}}], true}
             ]
    end

    test "skips dynamic tags" do
      usages =
        Module30
        |> IR.for_module()
        |> list_component_usages()

      assert usages == []
    end

    test "returns an empty list for a module without component usages" do
      usages =
        Module27
        |> IR.for_module()
        |> list_component_usages()

      assert usages == []
    end
  end

  describe "maybe_load_call_graph/1" do
    setup do
      test_tmp_dir = Path.join([@tmp_dir, "tests", "compiler", "maybe_load_call_graph_1"])

      build_dir = Path.join(test_tmp_dir, "build")
      clean_dir(build_dir)

      dump_path = Path.join(build_dir, Reflection.call_graph_dump_file_name())

      [build_dir: build_dir, dump_path: dump_path]
    end

    test "dump file doesn't exist", %{build_dir: build_dir, dump_path: dump_path} do
      assert {call_graph = %CallGraph{}, ^dump_path} = maybe_load_call_graph(build_dir)
      assert CallGraph.get_graph(call_graph) == Digraph.new()
    end

    test "dump file exists", %{build_dir: build_dir, call_graph: call_graph, dump_path: dump_path} do
      CallGraph.dump(call_graph, dump_path)

      assert {loaded_call_graph = %CallGraph{}, ^dump_path} = maybe_load_call_graph(build_dir)
      assert CallGraph.get_graph(loaded_call_graph) == CallGraph.get_graph(call_graph)
    end
  end

  describe "maybe_load_ir_plt/1" do
    setup do
      test_tmp_dir = Path.join([@tmp_dir, "tests", "compiler", "maybe_load_ir_plt_1"])

      build_dir = Path.join(test_tmp_dir, "build")
      clean_dir(build_dir)

      dump_path = Path.join(build_dir, Reflection.ir_plt_dump_file_name())

      [build_dir: build_dir, dump_path: dump_path]
    end

    test "dump file doesn't exist", %{build_dir: build_dir, dump_path: dump_path} do
      assert {plt = %PLT{}, ^dump_path} = maybe_load_ir_plt(build_dir)
      assert PLT.get_all(plt) == %{}
    end

    test "dump file exists", %{build_dir: build_dir, dump_path: dump_path, ir_plt: ir_plt} do
      PLT.dump(ir_plt, dump_path)

      assert {plt = %PLT{}, ^dump_path} = maybe_load_ir_plt(build_dir)
      assert PLT.get_all(plt) == PLT.get_all(ir_plt)
    end
  end

  describe "maybe_load_module_digest_plt/1" do
    setup do
      test_tmp_dir = Path.join([@tmp_dir, "tests", "compiler", "maybe_load_module_digest_plt_1"])

      build_dir = Path.join(test_tmp_dir, "build")
      clean_dir(build_dir)

      dump_path = Path.join(build_dir, Reflection.module_digest_plt_dump_file_name())

      [build_dir: build_dir, dump_path: dump_path]
    end

    test "dump file doesn't exist", %{build_dir: build_dir, dump_path: dump_path} do
      assert {plt = %PLT{}, ^dump_path} = maybe_load_module_digest_plt(build_dir)
      assert PLT.get_all(plt) == %{}
    end

    test "dump file exists", %{build_dir: build_dir, dump_path: dump_path} do
      PLT.start()
      |> PLT.put(:a, 1)
      |> PLT.put(:b, 2)
      |> PLT.dump(dump_path)

      assert {plt = %PLT{}, ^dump_path} = maybe_load_module_digest_plt(build_dir)
      assert PLT.get_all(plt) == %{a: 1, b: 2}
    end
  end

  describe "patch_ir_plt!/3" do
    setup do
      ir_plt =
        PLT.start()
        |> PLT.put(:module_5, :ir_5)
        |> PLT.put(:module_6, :ir_6)
        |> PLT.put(Module3, :ir_3)
        |> PLT.put(:module_7, :ir_7)
        |> PLT.put(:module_8, :ir_8)
        |> PLT.put(Module4, :ir_4)

      module_digests_diff = %{
        added_modules: [Module1, Module2],
        removed_modules: [:module_5, :module_7],
        edited_modules: [Module3, Module4]
      }

      patch_ir_plt!(ir_plt, module_digests_diff)

      [ir_plt: ir_plt]
    end

    test "adds entries of added modules", %{ir_plt: ir_plt} do
      assert PLT.get(ir_plt, Module1) ==
               {:ok,
                %IR.ModuleDefinition{
                  module: %IR.AtomType{
                    value: Module1
                  },
                  body: %IR.Block{expressions: []}
                }}

      assert PLT.get(ir_plt, Module2) ==
               {:ok,
                %IR.ModuleDefinition{
                  module: %IR.AtomType{
                    value: Module2
                  },
                  body: %IR.Block{expressions: []}
                }}
    end

    test "removes entries of removed modules", %{ir_plt: ir_plt} do
      assert PLT.get(ir_plt, :module_5) == :error
      assert PLT.get(ir_plt, :module_7) == :error
    end

    test "updates entries of edited modules", %{ir_plt: ir_plt} do
      assert PLT.get(ir_plt, Module3) ==
               {:ok,
                %IR.ModuleDefinition{
                  module: %IR.AtomType{
                    value: Module3
                  },
                  body: %IR.Block{expressions: []}
                }}

      assert PLT.get(ir_plt, Module4) ==
               {:ok,
                %IR.ModuleDefinition{
                  module: %IR.AtomType{
                    value: Module4
                  },
                  body: %IR.Block{expressions: []}
                }}
    end

    test "doesn't change entries of unchanged modules", %{ir_plt: ir_plt} do
      assert PLT.get(ir_plt, :module_6) == {:ok, :ir_6}
      assert PLT.get(ir_plt, :module_8) == {:ok, :ir_8}
    end

    # Reproduces the state Phoenix's code reloader leaves behind in an umbrella:
    # it compiles with --purge-consolidation-path-if-stale, which removes the
    # umbrella root consolidated dir while the protocol modules stay loaded from
    # it. Resolving such a module through :code.which/1 alone raises, which is
    # what the single-app path would do here - see the removal note on
    # Hologram.Compiler.resolve_beam_source/2.
    # TODO: Remove when resolve_beam_source/2 goes (see the removal note there).
    test "umbrella project, module loaded from a purged consolidated beam" do
      module = Module26
      {^module, bytecode, _beam_path} = :code.get_object_code(module)

      # The module's own beam stays on the code path - only the consolidated copy
      # it gets reloaded from below is gone.
      {:module, ^module} =
        :code.load_binary(module, ~c"/removed/consolidated/#{module}.beam", bytecode)

      on_exit(fn ->
        :code.purge(module)
        {:module, ^module} = :code.load_file(module)
      end)

      ir_plt = PLT.start()
      umbrella_dir = Path.join(@fixtures_dir, "umbrella")

      module_digests_diff = %{
        added_modules: [module],
        removed_modules: [],
        edited_modules: []
      }

      Mix.Project.in_project(:umbrella_fixture, umbrella_dir, [app: nil], fn _module ->
        patch_ir_plt!(ir_plt, module_digests_diff)
      end)

      assert {:ok, %IR.ModuleDefinition{module: %IR.AtomType{value: ^module}}} =
               PLT.get(ir_plt, module)
    end
  end

  test "prune_module_def/2" do
    module_def_ir = IR.for_module(Module8)

    module_def_ir_fixture = %{
      module_def_ir
      | body: %IR.Block{
          expressions: [
            %IR.IgnoredExpression{type: :public_macro_definition} | module_def_ir.body.expressions
          ]
        }
    }

    reachable_mfas = [
      {Module8, :fun_2, 2},
      {Module8, :fun_3, 1}
    ]

    assert prune_module_def(module_def_ir_fixture, reachable_mfas) == %IR.ModuleDefinition{
             module: %IR.AtomType{value: Module8},
             body: %IR.Block{
               expressions: [
                 %IR.FunctionDefinition{
                   name: :fun_2,
                   arity: 2,
                   visibility: :public,
                   clause: %IR.FunctionClause{
                     params: [
                       %IR.AtomType{value: :a},
                       %IR.AtomType{value: :b}
                     ],
                     guards: [],
                     body: %IR.Block{
                       expressions: [%IR.IntegerType{value: 3}]
                     },
                     line: 11,
                     blame: %{params: [":a", ":b"], guards: []}
                   }
                 },
                 %IR.FunctionDefinition{
                   name: :fun_2,
                   arity: 2,
                   visibility: :public,
                   clause: %IR.FunctionClause{
                     params: [
                       %IR.AtomType{value: :b},
                       %IR.AtomType{value: :c}
                     ],
                     guards: [],
                     body: %IR.Block{
                       expressions: [%IR.IntegerType{value: 4}]
                     },
                     # The AST reconstructed from BEAM debug info carries the
                     # first clause's line on every clause of a function.
                     line: 11,
                     blame: %{params: [":b", ":c"], guards: []}
                   }
                 },
                 %IR.FunctionDefinition{
                   name: :fun_3,
                   arity: 1,
                   visibility: :public,
                   clause: %IR.FunctionClause{
                     params: [%IR.Variable{name: :x, version: 0}],
                     guards: [],
                     body: %IR.Block{
                       expressions: [%IR.Variable{name: :x, version: 0}]
                     },
                     line: 19,
                     blame: %{params: ["x"], guards: []}
                   }
                 }
               ]
             }
           }
  end

  test "prune_module_def/2 prunes protocol dispatcher clauses to included implementations" do
    reachable_mfas = [
      {String.Chars, :impl_for, 1},
      {String.Chars, :impl_for!, 1},
      {String.Chars, :struct_impl_for, 1},
      {String.Chars, :to_string, 1},
      {String.Chars.Atom, :__impl__, 1},
      {String.Chars.Atom, :to_string, 1},
      {String.Chars.URI, :__impl__, 1},
      {String.Chars.URI, :to_string, 1}
    ]

    js =
      String.Chars
      |> IR.for_module()
      |> prune_module_def(reachable_mfas)
      |> Encoder.encode_ir(%Context{module: String.Chars, async_mfas: MapSet.new()})

    assert js_contains?(
             js,
             ~s/Interpreter.defineElixirFunction("String.Chars", "impl_for!", 1, "public"/
           )

    assert js_contains?(js, ~s/Type.atom("Elixir.String.Chars.Atom")/)
    assert js_contains?(js, ~s/Type.atom("Elixir.String.Chars.URI")/)

    refute js_contains?(js, "Elixir.String.Chars.Version")
    refute js_contains?(js, "Hologram.Test.Fixtures.Compiler.CallGraph.Module12")
  end

  describe "validate_prop_usages/2" do
    test "doesn't raise when every required prop is written at the usage" do
      plt = PLT.put(PLT.start(), Module32, IR.for_module(Module32))

      assert validate_prop_usages([Module32], plt) == :ok
    end

    test "raises when a required prop is missing from the usage" do
      # The offending usage is built as IR rather than as a file fixture, because a file fixture
      # would raise in the compile.hologram Mix task tests, which compile the whole project.
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module31, [{"label", [text: "abc"]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module32, module_ir_with_template(ir))

      expected_msg =
        "component Hologram.Test.Fixtures.Compiler.Module31 is missing required prop " <>
          ~s/"size" in Hologram.Test.Fixtures.Compiler.Module32's template/

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_prop_usages([Module32], plt)
      end
    end

    test "doesn't raise when the usage carries a spread" do
      plt = PLT.put(PLT.start(), Module34, IR.for_module(Module34))

      assert validate_prop_usages([Module34], plt) == :ok
    end

    test "doesn't raise when the required prop is sourced from context" do
      plt = PLT.put(PLT.start(), Module36, IR.for_module(Module36))

      assert validate_prop_usages([Module36], plt) == :ok
    end

    # A component node is an ordinary 4-tuple, so code outside the template can hold one without any
    # template rendering it.
    test "ignores a component tuple returned by a non-template function" do
      plt = PLT.put(PLT.start(), Module40, IR.for_module(Module40))

      assert validate_prop_usages([Module40], plt) == :ok
    end

    test "skips modules that are not in the IR PLT" do
      assert validate_prop_usages([Module32], PLT.start()) == :ok
    end

    test "doesn't raise when a written value is in the prop's :values list" do
      plt = PLT.put(PLT.start(), Module38, IR.for_module(Module38))

      assert validate_prop_usages([Module38], plt) == :ok
    end

    test "raises when a literal expression value is not in the prop's :values list" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module37, [{"size", [expression: {:huge}]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      expected_msg =
        ~s/prop "size" of component Hologram.Test.Fixtures.Compiler.Module37 must be one of / <>
          "[:small, :large], got: :huge, " <>
          "in Hologram.Test.Fixtures.Compiler.Module38's template"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_prop_usages([Module38], plt)
      end
    end

    test "raises when a text value is not in the prop's :values list" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module37, [{"label", [text: "nope"]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      expected_msg =
        ~s/prop "label" of component Hologram.Test.Fixtures.Compiler.Module37 must be one of / <>
          ~s/["abc", "xyz"], got: "nope", / <>
          "in Hologram.Test.Fixtures.Compiler.Module38's template"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_prop_usages([Module38], plt)
      end
    end

    test "raises for a value written at a usage that also carries a spread" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module37, [{"size", [expression: {:huge}]}, {:spread, {vars.props}}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      expected_msg =
        ~s/prop "size" of component Hologram.Test.Fixtures.Compiler.Module37 must be one of / <>
          "[:small, :large], got: :huge, " <>
          "in Hologram.Test.Fixtures.Compiler.Module38's template"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_prop_usages([Module38], plt)
      end
    end

    test "raises when a composite literal value is not in the prop's :values list" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module39, [{"size", [expression: {[:huge]}]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      expected_msg =
        ~s/prop "size" of component Hologram.Test.Fixtures.Compiler.Module39 must be one of / <>
          "[[:small], [:large]], got: [:huge], " <>
          "in Hologram.Test.Fixtures.Compiler.Module38's template"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_prop_usages([Module38], plt)
      end
    end

    test "doesn't raise when a composite literal value is in the prop's :values list" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module39, [{"size", [expression: {[:small]}]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      assert validate_prop_usages([Module38], plt) == :ok
    end

    # One expression anywhere inside makes the whole composite unknowable until it runs.
    test "doesn't raise when a composite value holds an expression" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module39, [{"size", [expression: {[vars.x]}]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      assert validate_prop_usages([Module38], plt) == :ok
    end

    test "doesn't raise when the value is not known at compile time" do
      ir =
        IR.for_code(
          ~s/[{:component, Hologram.Test.Fixtures.Compiler.Module37, [{"size", [expression: {vars.x}]}], []}]/,
          %Context{}
        )

      plt = PLT.put(PLT.start(), Module38, module_ir_with_template(ir))

      assert validate_prop_usages([Module38], plt) == :ok
    end
  end

  describe "validate_page_modules/1" do
    test "doesn't raise any error if all pages have a route and a layout specified" do
      assert validate_page_modules([Module9, Module11]) == :ok
    end

    test "raises error if any of the pages doesn't have a route specified" do
      # Inline fixture used, because file fixture would raise error in compile.hologram Mix task tests.
      defmodule InlinePageModuleFixture1 do
        use Hologram.Page

        layout Hologram.Test.Fixtures.LayoutFixture

        @impl Page
        def template do
          ~HOLO""
        end
      end

      expected_msg =
        "page 'Hologram.CompilerTest.InlinePageModuleFixture1' doesn't have a route specified (use the route/1 macro to fix it)"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_page_modules([Module11, InlinePageModuleFixture1])
      end
    end

    test "raises error if any of the pages doesn't have a layout specified" do
      # Inline fixture used, because file fixture would raise error in compile.hologram Mix task tests.
      defmodule InlinePageModuleFixture2 do
        use Hologram.Page

        route "/hologram-compilertest-inline-page-module-fixture-2"

        @impl Page
        def template do
          ~HOLO""
        end
      end

      expected_msg =
        "page 'Hologram.CompilerTest.InlinePageModuleFixture2' doesn't have a layout module specified (use the layout/1 macro to fix it)"

      assert_raise Hologram.CompileError, expected_msg, fn ->
        validate_page_modules([Module11, InlinePageModuleFixture2])
      end
    end
  end
end
