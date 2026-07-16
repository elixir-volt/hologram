alias Hologram.Commons.FileUtils
alias Hologram.Compiler
alias Hologram.Compiler.CallGraph
alias Hologram.Reflection

Benchee.run(
  %{
    "build_assets/2" => fn {entry_files, opts} ->
      Compiler.build_assets(entry_files, opts)
    end
  },
  before_scenario: fn _input ->
    tmp_dir = Path.join([Reflection.tmp_dir(), "benchmarks", "compiler", "build_assets_2"])

    opts = [
      tmp_dir: tmp_dir,
      static_dir: Path.join(tmp_dir, "static")
    ]

    FileUtils.recreate_dir(opts[:tmp_dir])
    File.mkdir!(opts[:static_dir])

    ir_plt = Compiler.build_ir_plt()

    call_graph = Compiler.build_call_graph(ir_plt)

    # Must be computed before remove_manually_ported_mfas/1 strips the Task.await/1 vertex.
    async_mfas = CallGraph.list_async_mfas(call_graph)

    CallGraph.remove_manually_ported_mfas(call_graph)

    runtime_mfas = CallGraph.list_runtime_mfas(call_graph, Reflection.list_pages())

    # Derived before the graph is split into runtime and page parts, so that the
    # applications reached from pages are named as well.
    app_versions = Compiler.build_app_versions(call_graph)

    call_graph_for_pages = CallGraph.remove_runtime_mfas!(call_graph, runtime_mfas)

    runtime_entry_file_path =
      Compiler.create_runtime_entry_file(runtime_mfas, ir_plt, async_mfas, app_versions, opts)

    page_entry_files =
      Compiler.create_page_entry_files(
        Reflection.list_pages(),
        call_graph_for_pages,
        ir_plt,
        async_mfas,
        opts
      )

    entry_files = [runtime_entry_file_path | Enum.map(page_entry_files, &elem(&1, 1))]

    {entry_files, opts}
  end,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     description: "Hologram.Compiler.build_assets/2", file: Path.join(__DIR__, "README.md")}
  ],
  time: 10
)
