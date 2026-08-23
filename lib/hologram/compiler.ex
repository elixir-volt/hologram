defmodule Hologram.Compiler do
  @moduledoc false

  alias Hologram.Assets.NPMDeps
  alias Hologram.Commons.MapUtils
  alias Hologram.Commons.PLT
  alias Hologram.Commons.TaskUtils
  alias Hologram.Commons.Types, as: T
  alias Hologram.Compiler.CallGraph
  alias Hologram.Compiler.Context
  alias Hologram.Compiler.Encoder
  alias Hologram.Compiler.IR
  alias Hologram.Reflection
  alias Volt.Builder.ManifestEntry

  @runtime_source {:hologram, "ts"}

  @doc """
  Aggregates JS imports from all Elixir modules referenced by the given MFAs.
  Returns a map with:
  - `:imports` — unique imports with generated `$1`, `$2`, ... aliases for JS import statements
  - `:bindings` — per-module map of user alias to generated alias for `__bindings__` on module proxies
  """
  @spec aggregate_js_imports(list(mfa)) :: %{
          imports: list(%{from: String.t(), export: String.t(), alias: String.t()}),
          bindings: %{module => %{String.t() => String.t()}}
        }
  def aggregate_js_imports(mfas) do
    modules_with_imports =
      mfas
      |> filter_elixir_mfas()
      |> Enum.map(fn {module, _function, _arity} -> module end)
      |> Enum.uniq()
      |> Enum.filter(
        &(Reflection.has_function?(&1, :__js_imports__, 0) and &1.__js_imports__() != [])
      )

    unique_imports =
      modules_with_imports
      |> Enum.flat_map(fn module ->
        Enum.map(module.__js_imports__(), fn %{from: from, export: export} ->
          {from, export}
        end)
      end)
      |> Enum.uniq()
      |> Enum.sort()

    alias_map =
      unique_imports
      |> Enum.with_index(1)
      |> Map.new(fn {{from, export}, index} -> {{from, export}, "$#{index}"} end)

    imports =
      Enum.map(unique_imports, fn {from, export} ->
        %{from: from, export: export, alias: alias_map[{from, export}]}
      end)

    bindings =
      Map.new(modules_with_imports, fn module ->
        module_bindings =
          Map.new(module.__js_imports__(), fn %{as: as, from: from, export: export} ->
            {as, alias_map[{from, export}]}
          end)

        {module, module_bindings}
      end)

    %{imports: imports, bindings: bindings}
  end

  @doc """
  Returns the version of each OTP application the given call graph reaches, keyed by application
  name and sorted by it.

  A stacktrace frame names the application its module belongs to and that application's version,
  the way the server renders one, and this is where the client reads the version from.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/elixir/compiler/build_app_versions_1/README.md
  """
  @spec build_app_versions(CallGraph.t()) :: keyword(String.t())
  def build_app_versions(call_graph) do
    call_graph
    |> CallGraph.vertices()
    |> Enum.map(fn
      {module, _function, _arity} -> module
      module -> module
    end)
    |> Enum.uniq()
    |> Enum.map(&Application.get_application/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(fn app -> {app, Application.spec(app, :vsn)} end)
    |> Enum.reject(fn {_app, vsn} -> is_nil(vsn) end)
    |> Enum.map(fn {app, vsn} -> {app, to_string(vsn)} end)
    |> Enum.sort()
  end

  @doc """
  Builds the call graph of all modules in the project.
  """
  @spec build_call_graph :: CallGraph.t()
  def build_call_graph do
    build_call_graph(build_ir_plt())
  end

  @doc """
  Builds the call graph of all modules in the given IR PLT.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/build_call_graph_1/README.md
  """
  @spec build_call_graph(PLT.t()) :: CallGraph.t()
  def build_call_graph(ir_plt) do
    call_graph = CallGraph.start()

    ir_plt
    |> PLT.get_all()
    |> TaskUtils.async_many(fn {_module, ir} -> CallGraph.build(call_graph, ir) end)
    |> Task.await_many(:infinity)

    CallGraph.add_non_discoverable_edges(call_graph)
  end

  @doc """
  Builds IR persistent lookup table (PLT) of all modules in the project.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/build_ir_plt_1/README.md
  """
  @spec build_ir_plt(T.opts()) :: PLT.t()
  # credo:disable-for-lines:26 Credo.Check.Refactor.Nesting
  # The above Credo check is disabled because the function is optimised this way
  def build_ir_plt(opts \\ []) do
    ir_plt = PLT.start(opts)

    modules = Reflection.list_elixir_modules()

    # Processing modules in chunks of 2 improves performance by ~7%
    # (determined experimentally)
    chunk_size = 2

    # TODO: Remove this flag and call :code.which/1 directly below when
    # resolve_beam_source/2 goes (see the removal note there).
    umbrella? = Reflection.umbrella?()

    modules
    |> Enum.chunk_every(chunk_size)
    |> TaskUtils.async_many(fn module_chunk ->
      Enum.each(module_chunk, fn module ->
        beam_source = resolve_beam_source(module, umbrella?)

        if beam_source do
          ir = IR.for_module(module, beam_source)
          PLT.put(ir_plt, module, ir)
        end
      end)
    end)
    |> Task.await_many(:infinity)

    ir_plt
  end

  @doc """
  Builds a persistent lookup table (PLT) containing the BEAM defs digests for all the modules in the project.

  Benchmarks: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/build_module_digest_plt!_1/README.md
  """
  @spec build_module_digest_plt!(T.opts()) :: PLT.t()
  def build_module_digest_plt!(opts \\ []) do
    module_digest_plt = PLT.start(opts)

    # TODO: Remove this flag and the argument it feeds to
    # rebuild_module_digest_plt_entry!/3 when resolve_beam_source/2 goes (see
    # the removal note there).
    umbrella? = Reflection.umbrella?()

    Reflection.list_elixir_modules()
    |> TaskUtils.async_many(&rebuild_module_digest_plt_entry!(&1, module_digest_plt, umbrella?))
    |> Task.await_many(:infinity)

    module_digest_plt
  end

  @doc """
  Builds all generated JavaScript entries through Volt's production pipeline.
  """
  @spec build_assets([T.file_path()], T.opts()) :: Volt.Builder.Result.t()
  def build_assets(entry_files, opts) do
    static_dir = opts[:static_dir]
    project_node_modules = Path.join([Reflection.root_dir(), "assets", "node_modules"])
    hologram_node_modules = opts[:hologram_node_modules] || NPMDeps.node_modules!()
    plugins = [Hologram.Volt.Plugin | List.wrap(opts[:plugins])]

    with_asset_output_rollback(static_dir, fn ->
      case Volt.Builder.build(
             entry: entry_files,
             outdir: static_dir,
             target: :es2021,
             minify: true,
             sourcemap: true,
             format: :esm,
             code_splitting: true,
             hash: true,
             asset_url_prefix: "/hologram",
             node_modules: project_node_modules,
             package_scopes: [
               {Volt.Priv.path(@runtime_source, "."), hologram_node_modules}
               | List.wrap(opts[:package_scopes])
             ],
             plugins: plugins,
             resolve_dirs: List.wrap(opts[:resolve_dirs])
           ) do
        {:ok, result} ->
          ensure_no_css!(result.manifest)
          maybe_ensure_build_within_size_limit!(result.manifest, static_dir)
          result

        {:error, reason} ->
          raise RuntimeError, message: "Volt build failed: #{inspect(reason)}"
      end
    end)
  end

  @doc """
  Builds JavaScript code for the given Hologram page.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/elixir/compiler/build_page_js_6/README.md
  """
  @spec build_page_js(
          module,
          CallGraph.t(),
          PLT.t(),
          MapSet.t(mfa),
          %{module => CallGraph.server_callback_analysis()},
          T.file_path()
        ) :: String.t()
  def build_page_js(
        page_module,
        call_graph,
        ir_plt,
        async_mfas,
        server_callback_analysis_by_templatable,
        _js_dir
      ) do
    mfas =
      CallGraph.list_page_mfas(call_graph, page_module, server_callback_analysis_by_templatable)

    %{imports: imports, bindings: bindings} = aggregate_js_imports(mfas)

    import_statements =
      imports
      |> Enum.map_join("\n", fn %{from: from, export: export, alias: alias} ->
        ~s'import { #{export} as #{alias} } from "#{from}";'
      end)
      |> render_block()

    js_bindings_registration_call =
      bindings
      |> render_js_bindings_registration_call()
      |> render_block()

    erlang_js_dir = Volt.Priv.path(@runtime_source, "erlang")

    erlang_function_defs =
      mfas
      |> render_erlang_function_defs(erlang_js_dir)
      |> render_block()

    elixir_function_defs =
      mfas
      |> render_elixir_function_defs(ir_plt, async_mfas)
      |> render_block()

    module_metadata_registration =
      mfas
      |> render_module_metadata_registration()
      |> render_block()

    function_definitions =
      module_metadata_registration <>
        js_bindings_registration_call <>
        erlang_function_defs <>
        elixir_function_defs

    Volt.Priv.render!(@runtime_source, "page_entry.ts", [],
      splices: [imports: import_statements, function_definitions: function_definitions]
    )
  end

  @doc """
  Builds Hologram runtime JavaScript source code.
  """
  @spec build_runtime_js(list(mfa), PLT.t(), MapSet.t(mfa), keyword(String.t()), T.file_path()) ::
          String.t()
  def build_runtime_js(runtime_mfas, ir_plt, async_mfas, app_versions, _js_dir) do
    erlang_function_defs =
      runtime_mfas
      |> render_erlang_function_defs(Volt.Priv.path(@runtime_source, "erlang"))
      |> render_block()

    elixir_function_defs =
      runtime_mfas
      |> render_elixir_function_defs(ir_plt, async_mfas)
      |> render_block()

    module_metadata_registration =
      runtime_mfas
      |> render_module_metadata_registration()
      |> render_block()

    manually_ported_clause_heads =
      ir_plt
      |> render_manually_ported_clause_heads()
      |> render_block()

    function_definitions =
      "globalThis.Hologram.config = #{render_client_config()};\n" <>
        "ERTS.appVersions = #{render_app_versions(app_versions)};\n" <>
        module_metadata_registration <>
        erlang_function_defs <>
        elixir_function_defs <>
        manually_ported_clause_heads

    Volt.Priv.render!(@runtime_source, "runtime_entry.ts", [],
      splices: [function_definitions: function_definitions]
    )
  end

  @doc """
  Creates page bundle entry file.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/elixir/compiler/create_page_entry_files_5/README.md
  """
  @spec create_page_entry_files(list(module), CallGraph.t(), PLT.t(), MapSet.t(mfa), T.opts()) ::
          list({module, T.file_path()})
  def create_page_entry_files(page_modules, call_graph, ir_plt, async_mfas, opts) do
    graph = CallGraph.get_graph(call_graph)
    templatables = page_modules ++ Reflection.list_components()

    server_callback_analysis_by_templatable =
      CallGraph.server_callback_analysis_by_templatable(graph, templatables)

    page_modules
    |> TaskUtils.async_many(fn page_module ->
      entry_name = Reflection.module_name(page_module)

      entry_file_path =
        page_module
        |> build_page_js(
          call_graph,
          ir_plt,
          async_mfas,
          server_callback_analysis_by_templatable,
          opts[:js_dir]
        )
        |> create_entry_file(entry_name, opts[:tmp_dir])

      {page_module, entry_file_path}
    end)
    |> Task.await_many(:infinity)
  end

  @doc """
  Creates runtime bundle entry file.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/elixir/compiler/create_runtime_entry_file_5/README.md
  """
  @spec create_runtime_entry_file(
          list(mfa),
          PLT.t(),
          MapSet.t(mfa),
          keyword(String.t()),
          T.opts()
        ) :: T.file_path()
  def create_runtime_entry_file(runtime_mfas, ir_plt, async_mfas, app_versions, opts) do
    runtime_mfas
    |> build_runtime_js(ir_plt, async_mfas, app_versions, opts[:js_dir])
    |> create_entry_file("runtime", opts[:tmp_dir])
  end

  @doc """
  Compares two module digest PLTs and returns the added, removed, and edited modules lists.

  Benchmarks: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/diff_module_digest_plts_2/README.md
  """
  @spec diff_module_digest_plts(PLT.t(), PLT.t()) :: %{
          added_modules: list(module),
          removed_modules: list(module),
          edited_modules: list(module)
        }
  def diff_module_digest_plts(old_plt, new_plt) do
    old_digests = PLT.get_all(old_plt)
    new_digests = PLT.get_all(new_plt)

    diff = MapUtils.diff(old_digests, new_digests)

    %{
      added_modules: Enum.map(diff.added, fn {module, _digest} -> module end),
      removed_modules: diff.removed,
      edited_modules: Enum.map(diff.edited, fn {module, _digest} -> module end)
    }
  end

  @doc """
  Extracts JavaScript source code for the given ported Erlang function.

  Returns the JavaScript function code if it exists in the corresponding .mjs file,
  or nil if the file or function doesn't exist.

  ## Examples

      iex> get_erlang_function_js(:erlang, :+, 2, "/path/to/erlang")
      "(left, right) => { ... }"

      iex> get_erlang_function_js(:maps, :get, 2, "/path/to/erlang")
      "(key, map) => { ... }"

      iex> get_erlang_function_js(:erlang, :not_implemented, 2, "/path/to/erlang")
      nil
  """
  @spec get_erlang_function_js(module, atom, non_neg_integer, T.file_path()) :: String.t() | nil
  def get_erlang_function_js(module, function, arity, erlang_js_dir) do
    file_path =
      if module == :erlang do
        "#{erlang_js_dir}/erlang.ts"
      else
        "#{erlang_js_dir}/#{module}.ts"
      end

    if File.exists?(file_path) do
      extract_erlang_function_js(file_path, function, arity)
    else
      nil
    end
  end

  @doc """
  Groups the given MFAs by module.
  """
  @spec group_mfas_by_module(list(mfa)) :: %{module => mfa}
  def group_mfas_by_module(mfas) do
    Enum.group_by(mfas, fn {module, _function, _arity} -> module end)
  end

  @doc """
  Returns every component usage found in the given IR, as `{component_module, props, has_spread?}`
  tuples, in the order they appear in the template.

  `props` holds one entry per prop written at the usage, without the framework's own `$`-prefixed
  entries, as `{name, {:ok, value}}` when the value is known without running anything, and
  `{name, :unknown}` otherwise. `has_spread?` says whether the usage carries a `...{expr}` spread,
  which makes its set of props impossible to know before the expression has a value.

  Dynamic tags (`<{@module} />`) are skipped - the component module itself is a runtime value there.

  ## Examples

      iex> list_component_usages(IR.for_module(MyApp.HomePage))
      [{MyApp.Card, [{"size", {:ok, :small}}, {"count", :unknown}], false}]
  """
  @spec list_component_usages(IR.t()) ::
          list({module, list({String.t(), {:ok, any} | :unknown}), boolean})
  def list_component_usages(ir) do
    ir
    |> collect_component_usages([])
    |> Enum.reverse()
  end

  @doc """
  Loads call graph from a dump file if the file exists or creates an empty call graph.

  Benchmarks: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/maybe_load_call_graph_1/README.md
  """
  @spec maybe_load_call_graph(T.file_path(), T.opts()) :: {CallGraph.t(), String.t()}
  def maybe_load_call_graph(build_dir, opts \\ []) do
    call_graph = CallGraph.start(opts)
    call_graph_dump_path = Path.join(build_dir, Reflection.call_graph_dump_file_name())
    CallGraph.maybe_load(call_graph, call_graph_dump_path)

    {call_graph, call_graph_dump_path}
  end

  @doc """
  Loads IR PLT from a dump file if the file exists or creates an empty PLT.

  Benchmarks: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/maybe_load_ir_plt_1/README.md
  """
  @spec maybe_load_ir_plt(T.file_path()) :: {PLT.t(), String.t()}
  def maybe_load_ir_plt(build_dir) do
    ir_plt = PLT.start()
    ir_plt_dump_path = Path.join(build_dir, Reflection.ir_plt_dump_file_name())
    PLT.maybe_load(ir_plt, ir_plt_dump_path)

    {ir_plt, ir_plt_dump_path}
  end

  @doc """
  Loads module digest PLT from a dump file if the file exists or creates an empty PLT.

  Benchmarks: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/maybe_load_module_digest_plt_1/README.md
  """
  @spec maybe_load_module_digest_plt(T.file_path(), T.opts()) :: {PLT.t(), String.t()}
  def maybe_load_module_digest_plt(build_dir, opts \\ []) do
    module_digest_plt = PLT.start(opts)

    module_digest_plt_dump_path =
      Path.join(build_dir, Reflection.module_digest_plt_dump_file_name())

    PLT.maybe_load(module_digest_plt, module_digest_plt_dump_path)

    {module_digest_plt, module_digest_plt_dump_path}
  end

  @doc """
  Given a module digests diff, updates the IR persistent lookup table (PLT)
  by deleting entries for modules that have been removed,
  rebuilding the IR of modules that have been edited,
  and adding the IR of new modules.
  """
  @spec patch_ir_plt!(PLT.t(), map) :: PLT.t()
  def patch_ir_plt!(ir_plt, module_digests_diff) do
    # TODO: Remove this flag and the argument it feeds to rebuild_ir_plt_entry!/3
    # when resolve_beam_source/2 goes (see the removal note there).
    umbrella? = Reflection.umbrella?()

    delete_tasks =
      TaskUtils.async_many(module_digests_diff.removed_modules, &PLT.delete(ir_plt, &1))

    rebuild_tasks =
      TaskUtils.async_many(
        module_digests_diff.edited_modules ++ module_digests_diff.added_modules,
        &rebuild_ir_plt_entry!(ir_plt, &1, umbrella?)
      )

    Task.await_many(delete_tasks, :infinity)
    Task.await_many(rebuild_tasks, :infinity)

    ir_plt
  end

  @doc """
  Keeps only those IR expressions that are function definitions of the given reachable MFAs.
  For protocol modules, additionally drops the consolidated impl_for/1 and struct_impl_for/1
  clauses that return implementations not included in the given reachable MFAs.
  """
  @spec prune_module_def(IR.ModuleDefinition.t(), list(mfa)) :: IR.ModuleDefinition.t()
  def prune_module_def(module_def_ir, reachable_mfas) do
    module = module_def_ir.module.value

    module_reachable_mfas =
      reachable_mfas
      |> Enum.filter(fn {reachable_module, _function, _arity} -> reachable_module == module end)
      |> MapSet.new()

    function_defs =
      module_def_ir.body.expressions
      |> Enum.filter(fn
        %IR.FunctionDefinition{name: function, arity: arity} ->
          MapSet.member?(module_reachable_mfas, {module, function, arity})

        _fallback ->
          false
      end)
      |> maybe_prune_protocol_dispatcher_function_defs(module, reachable_mfas)

    %IR.ModuleDefinition{
      module: module_def_ir.module,
      body: %IR.Block{expressions: function_defs}
    }
  end

  @doc """
  Raises a compilation error if any page module lacks a specified route or layout.

  Benchmark: https://github.com/bartblast/hologram/blob/master/benchmarks/compiler/validate_page_modules_1/README.md
  """
  @spec validate_page_modules(list(module)) :: :ok
  def validate_page_modules(page_modules) do
    Enum.each(page_modules, fn page_module ->
      if !Reflection.has_function?(page_module, :__route__, 0) do
        module_name = Reflection.module_name(page_module)

        raise Hologram.CompileError,
          message:
            "page '#{module_name}' doesn't have a route specified (use the route/1 macro to fix it)"
      end

      if !Reflection.has_function?(page_module, :__layout_module__, 0) do
        module_name = Reflection.module_name(page_module)

        raise Hologram.CompileError,
          message:
            "page '#{module_name}' doesn't have a layout module specified (use the layout/1 macro to fix it)"
      end
    end)
  end

  @doc """
  Raises a compilation error if a template uses a component without one of its required props.

  Only usages the compiler can decide are checked. A usage carrying a `...{expr}` spread is skipped,
  since any prop could be in the spread, and so is a prop declared with `:from_context`, which is
  never written at the usage. Those cases, along with dynamic tags, are left to the renderers.

  Modules missing from the IR PLT are skipped - a module without a BEAM source has no IR to walk.
  """
  @spec validate_prop_usages(list(module), PLT.t()) :: :ok
  def validate_prop_usages(modules, ir_plt) do
    Enum.each(modules, fn module ->
      case PLT.get(ir_plt, module) do
        {:ok, ir} -> validate_module_prop_usages(module, ir)
        _fallback -> :ok
      end
    end)
  end

  # A component node is a 4-element tuple whose first element is the :component atom and whose
  # second is the component module, already resolved by the time the template AST becomes IR. A
  # dynamic tag carries :dynamic_tag instead and never matches, which is what leaves it out.
  # Props and children are walked as well - props hold expressions, children hold nested usages.
  defp collect_component_usages(
         %IR.TupleType{
           data: [
             %IR.AtomType{value: :component},
             %IR.AtomType{value: component_module},
             %IR.ListType{data: props},
             %IR.ListType{data: children}
           ]
         },
         acc
       ) do
    usage = {component_module, prop_entries(props), has_spread?(props)}

    collect_component_usages(children, collect_component_usages(props, [usage | acc]))
  end

  defp collect_component_usages(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &collect_component_usages/2)
  end

  # Structs are maps too, so this walks every IR node's fields without naming any of them.
  defp collect_component_usages(map, acc) when is_map(map) do
    map
    |> Map.to_list()
    |> Enum.reduce(acc, fn {key, value}, key_acc ->
      collect_component_usages(value, collect_component_usages(key, key_acc))
    end)
  end

  defp collect_component_usages(tuple, acc) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.reduce(acc, &collect_component_usages/2)
  end

  defp collect_component_usages(_ir, acc), do: acc

  defp component_usage_error!(component_module, name, module) do
    raise Hologram.CompileError,
      message:
        "component #{Reflection.module_name(component_module)} is missing required prop " <>
          ~s/"#{name}" in #{Reflection.module_name(module)}'s template/
  end

  defp component_value_error!(component_module, {name, value, values}, module) do
    raise Hologram.CompileError,
      message:
        ~s/prop "#{name}" of component #{Reflection.module_name(component_module)} must be one of / <>
          "#{inspect(values)}, got: #{inspect(value)}, " <>
          "in #{Reflection.module_name(module)}'s template"
  end

  defp create_entry_file(js, entry_name, tmp_dir) do
    entry_file_path = Path.join(tmp_dir, "#{entry_name}.entry.js")
    File.write!(entry_file_path, js)

    entry_file_path
  end

  defp extract_erlang_function_js(file_path, function, arity) do
    key = "#{function}/#{arity}"
    start_marker = "// Start #{key}"
    end_marker = "// End #{key}"

    # Matches: start_marker, optional // comment lines, "key": <captured body>, end_marker
    regex =
      ~r/#{Regex.escape(start_marker)}\s+(?:\/\/[^\n]*\s+)*"#{Regex.escape(key)}":\s+(.+),\s+#{Regex.escape(end_marker)}/s

    file_contents = File.read!(file_path)

    case Regex.run(regex, file_contents) do
      [_full_capture, js] -> js
      nil -> nil
    end
  end

  defp filter_elixir_mfas(mfas) do
    Enum.filter(mfas, fn {module, _function, _arity} -> Reflection.elixir_module?(module) end)
  end

  defp filter_erlang_mfas(mfas) do
    Enum.filter(mfas, fn {module, _function, _arity} -> Reflection.erlang_module?(module) end)
  end

  defp has_spread?(props) do
    Enum.any?(props, &match?(%IR.TupleType{data: [%IR.AtomType{value: :spread}, _expr]}, &1))
  end

  # Only props whose value is known without running anything are judged. The comparison needs no
  # type guard: nothing casts a prop to its declared type, so a text value stays the string it was
  # written as, and the renderers compare it against values: exactly the same way.
  defp invalid_prop_values(component_module, prop_entries) do
    values_by_name =
      component_module.__props__()
      |> Enum.filter(fn {_name, _type, opts} -> opts[:values] end)
      |> Map.new(fn {name, _type, opts} -> {to_string(name), opts[:values]} end)

    Enum.flat_map(prop_entries, fn
      {name, {:ok, value}} ->
        values = values_by_name[name]

        if values && value not in values, do: [{name, value, values}], else: []

      {_name, :unknown} ->
        []
    end)
  end

  defp included_protocol_implementations(reachable_mfas, protocol) do
    reachable_mfas
    |> Enum.map(fn {module, _function, _arity} -> module end)
    |> Enum.uniq()
    |> Enum.filter(&(Reflection.protocol_implementation(&1) == protocol))
    |> MapSet.new()
  end

  defp keep_protocol_dispatcher_function_def?(
         %IR.FunctionDefinition{name: function, arity: 1, clause: clause},
         protocol,
         included_impls
       )
       when function in [:impl_for, :struct_impl_for] do
    case clause do
      %IR.FunctionClause{body: %IR.Block{expressions: [%IR.AtomType{value: value}]}} ->
        Reflection.protocol_implementation(value) != protocol or
          MapSet.member?(included_impls, value)

      _clause ->
        true
    end
  end

  defp keep_protocol_dispatcher_function_def?(_function_def, _protocol, _included_impls), do: true

  defp with_asset_output_rollback(static_dir, build) do
    backup_dir = static_dir <> ".previous"
    recover_interrupted_asset_build!(static_dir, backup_dir)

    if File.exists?(static_dir), do: File.rename!(static_dir, backup_dir)
    File.mkdir_p!(static_dir)

    try do
      result = build.()
      File.rm_rf!(backup_dir)
      result
    catch
      kind, reason ->
        File.rm_rf!(static_dir)
        restore_asset_output!(static_dir, backup_dir)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp recover_interrupted_asset_build!(static_dir, backup_dir) do
    if File.exists?(backup_dir) do
      File.rm_rf!(static_dir)
      File.rename!(backup_dir, static_dir)
    end
  end

  defp restore_asset_output!(static_dir, backup_dir) do
    if File.exists?(backup_dir) do
      File.rename!(backup_dir, static_dir)
    else
      File.mkdir_p!(static_dir)
    end
  end

  defp ensure_no_css!(manifest) do
    Enum.each(manifest, fn
      {entry_name, %ManifestEntry{css: [_first | _rest]}} ->
        raise RuntimeError,
          message:
            "Volt emitted CSS for #{entry_name}, but Hologram does not load CSS entries yet"

      {_entry_name, %ManifestEntry{}} ->
        :ok
    end)
  end

  defp maybe_ensure_build_within_size_limit!(manifest, static_dir) do
    Enum.each(manifest, fn
      {artifact_name, %ManifestEntry{file: file}} when is_binary(file) ->
        if Path.extname(file) == ".js" do
          file
          |> then(&Path.join(static_dir, &1))
          |> File.stat!()
          |> then(&maybe_ensure_bundle_within_size_limit!(artifact_name, &1.size))
        end

      {_artifact_name, %ManifestEntry{}} ->
        :ok
    end)
  end

  defp maybe_ensure_bundle_within_size_limit!(entry_name, bundle_size) do
    max_bundle_size = Application.get_env(:hologram, :max_bundle_size)

    if max_bundle_size do
      if bundle_size > max_bundle_size do
        raise RuntimeError,
          message: """
          Generated JavaScript bundle '#{entry_name}' is #{bundle_size} bytes, which exceeds the configured maximum of #{max_bundle_size} bytes.

          This limit acts as an early warning system to surface abnormally large bundles before they reach your app (e.g., accidentally pulling in too many modules or dependencies).

          You can change this limit by setting the [:hologram, :max_bundle_size] config value (in bytes). For example:

              config :hologram, max_bundle_size: 2 * 1024 * 1024\
          """
      end
    end
  end

  # Consolidated protocol dispatchers list every loaded implementation. Keep only
  # clauses for implementations that ship in the same bundle, so dispatch on other
  # types falls through to the catch-all clause and raises Protocol.UndefinedError.
  defp maybe_prune_protocol_dispatcher_function_defs(function_defs, module, reachable_mfas) do
    if Reflection.protocol?(module) do
      included_impls = included_protocol_implementations(reachable_mfas, module)

      Enum.filter(
        function_defs,
        &keep_protocol_dispatcher_function_def?(&1, module, included_impls)
      )
    else
      function_defs
    end
  end

  # Any literal is resolved, composites included, as long as every part of it is one too - a single
  # expression anywhere inside makes the whole value unknowable until it runs. Pids, ports and
  # references can't be written in a template at all (they only come from calls, which aren't
  # literals), so the node types for them are not reachable here.
  defp literal_value(%IR.AtomType{value: value}), do: {:ok, value}
  defp literal_value(%IR.FloatType{value: value}), do: {:ok, value}
  defp literal_value(%IR.IntegerType{value: value}), do: {:ok, value}
  defp literal_value(%IR.StringType{value: value}), do: {:ok, value}

  defp literal_value(%IR.ListType{data: data}), do: literal_values(data)

  defp literal_value(%IR.TupleType{data: data}) do
    case literal_values(data) do
      {:ok, items} -> {:ok, List.to_tuple(items)}
      :unknown -> :unknown
    end
  end

  defp literal_value(%IR.MapType{data: data}) do
    {key_irs, value_irs} = Enum.unzip(data)

    with {:ok, keys} <- literal_values(key_irs),
         {:ok, values} <- literal_values(value_irs) do
      map =
        keys
        |> Enum.zip(values)
        |> Map.new()

      {:ok, map}
    end
  end

  defp literal_value(_ir), do: :unknown

  # One unresolvable part makes the whole composite unresolvable - a list holding an expression has
  # no value until that expression runs.
  defp literal_values(irs) do
    result =
      Enum.reduce_while(irs, {:ok, []}, fn ir, {:ok, acc} ->
        case literal_value(ir) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          :unknown -> {:halt, :unknown}
        end
      end)

    case result do
      {:ok, reversed_values} -> {:ok, Enum.reverse(reversed_values)}
      :unknown -> :unknown
    end
  end

  # A prop sourced from context is never written at the usage, so its absence there says nothing -
  # only the renderers can tell whether the context supplied it.
  defp missing_required_props(component_module, prop_names) do
    component_module.__props__()
    |> Enum.filter(fn {name, _type, opts} ->
      opts[:required] && !opts[:from_context] && to_string(name) not in prop_names
    end)
    |> Enum.map(fn {name, _type, _opts} -> name end)
  end

  # $-prefixed entries are the framework's own ($key, event bindings), never something the author
  # declared with prop/3, so they are not props as far as a usage is concerned.
  defp prop_entries(props) do
    props
    |> Enum.flat_map(fn
      %IR.TupleType{data: [%IR.StringType{value: name}, %IR.ListType{data: value_dom}]} ->
        [{name, static_prop_value(value_dom)}]

      _entry ->
        []
    end)
    |> Enum.reject(fn {name, _value} -> String.starts_with?(name, "$") end)
  end

  # Mirrors evaluate_prop_value/1 in the renderer: a lone expression yields its term as it is, and
  # anything else is rendered to a string. So a value is known here only when the expression is a
  # literal, or when the value is text with nothing interpolated into it.
  defp static_prop_value([
         %IR.TupleType{data: [%IR.AtomType{value: :expression}, %IR.TupleType{data: [expr]}]}
       ]) do
    literal_value(expr)
  end

  defp static_prop_value([_first | _rest] = value_dom) do
    if Enum.all?(
         value_dom,
         &match?(%IR.TupleType{data: [%IR.AtomType{value: :text}, %IR.StringType{}]}, &1)
       ) do
      {:ok,
       Enum.map_join(value_dom, "", fn %IR.TupleType{data: [_tag, %IR.StringType{value: str}]} ->
         str
       end)}
    else
      :unknown
    end
  end

  defp static_prop_value(_value_dom), do: :unknown

  # TODO: Drop the umbrella? param and resolve the beam path with :code.which/1
  # when resolve_beam_source/2 goes (see the removal note there).
  defp rebuild_ir_plt_entry!(ir_plt, module, umbrella?) do
    # A nil beam source must not reach IR.for_module/2 - it resolves a nil one
    # with :code.which/1, which is exactly the stale path that yielded nil here.
    if beam_source = resolve_beam_source(module, umbrella?) do
      PLT.put(ir_plt, module, IR.for_module(module, beam_source))
    end
  end

  # TODO: Drop the umbrella? param and resolve the beam path with :code.which/1
  # when resolve_beam_source/2 goes (see the removal note there).
  defp rebuild_module_digest_plt_entry!(module, module_digest_plt, umbrella?) do
    beam_source = resolve_beam_source(module, umbrella?)

    if beam_source do
      digest =
        beam_source
        |> Reflection.beam_defs()
        # Fast and deterministic for change detection
        |> :erlang.phash2()

      PLT.put(module_digest_plt, module, digest)
    end
  end

  # Travels with the per-module metadata, which is emitted under the same
  # setting - a bundle built without client stacktraces names no application
  # and no version anywhere.
  defp render_app_versions(app_versions) do
    if Hologram.client_stacktraces?() do
      app_versions
      |> Enum.map_join(", ", fn {app, vsn} -> ~s/"#{app}": "#{vsn}"/ end)
      |> then(&"{#{&1}}")
    else
      "{}"
    end
  end

  defp render_block(str) do
    str = String.trim(str)

    if str != "" do
      "\n\n" <> str
    else
      ""
    end
  end

  defp render_client_config do
    ~s/{errorOverlay: #{Hologram.client_error_overlay?()}, stacktraces: #{Hologram.client_stacktraces?()}}/
  end

  defp render_elixir_function_defs(mfas, ir_plt, async_mfas) do
    mfas
    |> filter_elixir_mfas()
    |> group_mfas_by_module()
    |> Enum.sort()
    |> TaskUtils.async_many(fn {module, _module_mfas} ->
      ir_plt
      |> PLT.get!(module)
      |> prune_module_def(mfas)
      |> Encoder.encode_ir(%Context{module: module, async_mfas: async_mfas})
    end)
    |> Task.await_many(:infinity)
    |> Enum.join("\n\n")
  end

  # A manually ported function's clauses aren't encoded, so its raise sites have
  # no attempted clauses to report. Their heads are registered separately, from
  # the IR of the Elixir function the port stands in for.
  defp render_manually_ported_clause_heads(ir_plt) do
    CallGraph.manually_ported_elixir_mfas()
    |> Enum.map(fn {module, function, _arity} -> {module, function} end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn {module, function} ->
      render_manually_ported_clause_heads(ir_plt, module, function)
    end)
    |> Enum.join("\n")
  end

  # A raise reports the arity the function was defined with, which a default
  # argument makes differ from the arity the port replaces - Task.await/1 is
  # ported, but its clause is await/2 - so every arity is registered.
  defp render_manually_ported_clause_heads(ir_plt, module, function) do
    module_name = Reflection.module_name(module)

    case PLT.get(ir_plt, module) do
      {:ok, module_def} ->
        module_def
        |> IR.aggregate_module_funs()
        |> Enum.filter(fn {{name, _arity}, _fun} -> name == function end)
        |> Enum.sort()
        |> Enum.map(fn {{name, arity}, {visibility, clauses}} ->
          Encoder.encode_elixir_function_clause_heads(
            module_name,
            name,
            arity,
            visibility,
            clauses,
            %Context{module: module}
          )
        end)

      :error ->
        []
    end
  end

  defp render_module_metadata_registration(mfas) do
    mfas
    |> filter_elixir_mfas()
    |> Enum.map(fn {module, _function, _arity} -> module end)
    |> Enum.uniq()
    |> Encoder.encode_module_metadata_registration()
  end

  defp render_erlang_function_defs(mfas, erlang_js_dir) do
    mfas
    |> filter_erlang_mfas()
    |> TaskUtils.async_many(fn {module, function, arity} ->
      Encoder.encode_erlang_function(module, function, arity, erlang_js_dir)
    end)
    |> Task.await_many(:infinity)
    |> Enum.join("\n\n")
  end

  defp render_js_bindings_registration_call(bindings) when bindings == %{}, do: ""

  defp render_js_bindings_registration_call(bindings) do
    modules_arg =
      bindings
      |> Enum.sort()
      |> Enum.map_join(", ", fn {module, module_bindings} ->
        module_name = Reflection.module_name(module)

        entries =
          module_bindings
          |> Enum.sort()
          |> Enum.map_join(", ", fn {as, alias} -> ~s'"#{as}": #{alias}' end)

        ~s'"#{module_name}": {#{entries}}'
      end)

    ~s'Interpreter.registerJsBindings({#{modules_arg}});'
  end

  # In umbrella projects a module can stay loaded from a consolidated protocol
  # beam that Phoenix's code reloader has purged: the reloader compiles with
  # --purge-consolidation-path-if-stale, which deletes the umbrella root
  # consolidated dir while :code.which/1 keeps pointing into it. The beam source
  # is therefore resolved through Reflection.beam_source/1, which falls back to
  # the module's object code. Single-app projects never hit that state, so they
  # resolve through a plain :code.which/1 lookup with no per-module overhead.
  # Note that this is NOT fixed by the Phoenix > 1.8.9 code reloader rework
  # (phoenixframework/phoenix#6753) - the purge flag is still passed after it.
  # TODO: Remove the umbrella branch once upstream stops leaving loaded modules
  # pointing at purged consolidated beams. That means this function,
  # Reflection.beam_source/1 and Reflection.umbrella?/0 (if nothing else uses
  # them by then), plus unwinding the umbrella? flag threaded through
  # build_ir_plt/1, build_module_digest_plt!/1, patch_ir_plt!/2,
  # rebuild_ir_plt_entry!/3 and rebuild_module_digest_plt_entry!/3 - their
  # bodies go back to resolving the beam path with :code.which/1 directly.
  defp resolve_beam_source(module, true), do: Reflection.beam_source(module)

  defp resolve_beam_source(module, false) do
    beam_path = :code.which(module)

    if beam_path != :non_existing do
      beam_path
    end
  end

  defp validate_module_prop_usages(module, ir) do
    ir
    |> template_ir()
    |> list_component_usages()
    |> Enum.each(&validate_prop_usage(&1, module))
  end

  # Only the template's own DOM is validated. A component node is an ordinary 4-tuple, so code
  # elsewhere in the module - a helper building DOM by hand, a fixture - can hold one without any
  # template rendering it, and validating those would fail a build over a component nobody uses.
  defp template_ir(%IR.ModuleDefinition{body: %IR.Block{expressions: expressions}}) do
    Enum.find(expressions, &match?(%IR.FunctionDefinition{name: :template, arity: 0}, &1))
  end

  defp template_ir(_ir), do: nil

  # A spread decides only whether a prop is present, so it blocks the required check and nothing
  # else. A value written at the usage is judged either way: being overridden by a later spread
  # doesn't make an invalid literal valid, it just makes it dead as well as wrong.
  defp validate_prop_usage({component_module, prop_entries, has_spread?}, module) do
    if Reflection.has_function?(component_module, :__props__, 0) do
      validate_required_props(component_module, prop_entries, has_spread?, module)

      # Matched rather than iterated: both error functions only raise, so a capture of one would be
      # an anonymous function with no local return. Reporting the first violation is what iterating
      # did anyway - the raise ended it.
      case invalid_prop_values(component_module, prop_entries) do
        [] -> :ok
        [violation | _rest] -> component_value_error!(component_module, violation, module)
      end
    end
  end

  # A spread could supply any prop, so nothing can be proven missing at a usage carrying one.
  defp validate_required_props(_component_module, _prop_entries, true, _module), do: :ok

  defp validate_required_props(component_module, prop_entries, false, module) do
    prop_names = Enum.map(prop_entries, fn {name, _value} -> name end)

    case missing_required_props(component_module, prop_names) do
      [] -> :ok
      [name | _rest] -> component_usage_error!(component_module, name, module)
    end
  end
end
