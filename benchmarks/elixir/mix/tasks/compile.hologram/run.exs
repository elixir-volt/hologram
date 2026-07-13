alias Hologram.Commons.FileUtils
alias Hologram.Reflection

Benchee.run(
  %{
    "no cache" =>
      {fn opts ->
         Mix.Tasks.Compile.Hologram.run(opts)
       end,
       before_each: fn {benchmark_tmp_dir, opts} ->
         FileUtils.recreate_dir(benchmark_tmp_dir)
         opts
       end},
    "has cache" =>
      {fn opts ->
         Mix.Tasks.Compile.Hologram.run(opts)
       end,
       before_scenario: fn {benchmark_tmp_dir, opts} ->
         FileUtils.recreate_dir(benchmark_tmp_dir)
         Mix.Tasks.Compile.Hologram.run(opts)
         opts
       end}
  },
  before_scenario: fn _input ->
    benchmark_tmp_dir = Path.join([Reflection.tmp_dir(), "benchmarks", "mix", "compile.hologram"])

    opts = [
      build_dir: Path.join(benchmark_tmp_dir, "build"),
      force?: true,
      static_dir: Path.join(benchmark_tmp_dir, "static"),
      tmp_dir: Path.join(benchmark_tmp_dir, "tmp")
    ]

    {benchmark_tmp_dir, opts}
  end,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     description: "mix compile.hologram", file: Path.join(__DIR__, "README.md")}
  ],
  time: 10
)
