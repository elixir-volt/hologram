# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule Hologram.MixProject do
  use Mix.Project

  @version "0.11.0"

  defp aliases do
    [
      f: [
        "format",
        "volt.js.format",
        "format.js",
        "cmd cd test/features && mix format && mix format.js",
        "cmd cd test/umbrella && mix format"
      ],
      "format.js":
        "cmd assets/node_modules/.bin/prettier '*.yml' '.github/**' 'assets/*.json' --config 'assets/.prettierrc.json' -u --write",
      "format.js.check":
        "cmd assets/node_modules/.bin/prettier '*.yml' '.github/**' 'assets/*.json' --check --config 'assets/.prettierrc.json' --no-error-on-unmatched-pattern -u",
      setup: [
        "deps.get",
        "cmd --cd assets npm install",
        "cmd --cd test/features mix deps.get",
        "cmd --cd test/features/assets npm install",
        "cmd --cd test/umbrella mix deps.get",
        "cmd --cd test/umbrella/assets npm install"
      ],
      t: ["test"],
      ci: ["check"]
    ]
  end

  def application do
    if dep?() do
      [
        mod: {Hologram.Application, []},
        extra_applications: [:logger]
      ]
    else
      [
        extra_applications: [:logger]
      ]
    end
  end

  def cli do
    [
      preferred_envs: [t: :test, ci: :test]
    ]
  end

  defp deps do
    [
      {:beam_file, "0.6.4"},
      {:benchee, "~> 1.0", only: :dev, runtime: false},
      {:benchee_markdown, "~> 0.3", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:decimal, "~> 3.0", only: [:dev, :test], runtime: false, override: true},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.0", only: :test, runtime: false},
      {:ex_check, "~> 0.15", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:file_system, "~> 1.0"},
      {:gproc, "~> 1.0"},
      {:html_entities, "~> 0.5"},
      {:interceptor, "~> 0.5"},
      {:jason, "~> 1.0"},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.0"},
      {:playwright_ex, "~> 0.5", only: :test},
      {:plug_crypto, "~> 2.0"},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:recode, "~> 0.7", only: :dev, runtime: false},
      {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false},
      {:telemetry, "~> 1.0"},
      {:volt, github: "elixir-volt/volt", ref: "3380315", runtime: false},
      {:uuid, "~> 1.0"},
      {:wallaby, "~> 0.30", only: [:dev, :test], runtime: false},
      {:websock_adapter, "~> 0.5"}
    ]
  end

  def elixirc_paths(:dev), do: ["benchmarks/elixir/support", "lib"]
  def elixirc_paths(:test), do: ["lib", "test/elixir/fixtures", "test/elixir/support"]
  def elixirc_paths(_env), do: ["lib"]

  def package do
    [
      files: [
        "config",
        "lib",
        "priv/npm.lock",
        "priv/ts",
        ".formatter.exs",
        "LICENSE",
        "llms.txt",
        "llms-full.txt",
        "mix.exs",
        "README.md",
        "usage-rules.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Website" => "https://hologram.page",
        "Forum" => "https://elixirforum.com/hologram",
        "Discord" => "https://discord.gg/huJWNuqt8J",
        "Slack" => "https://elixir-lang.slack.com/channels/hologram",
        "Newsletter" => "https://hologram.page/newsletter",
        "Courses" => "https://hologram.page/courses",
        "UI" => "https://hologram.page/ui",
        "GitHub" => "https://github.com/bartblast/hologram",
        "Sponsor" => "https://github.com/sponsors/bartblast"
      },
      maintainers: ["Bart Blast"]
    ]
  end

  def project do
    [
      aliases: aliases(),
      app: :hologram,
      deps: deps(),
      description:
        "Full stack isomorphic Elixir web framework that can be used on top of Phoenix.",
      dialyzer: [
        plt_add_apps: [:ex_unit, :iex, :mix, :oxc, :volt, :wallaby],
        plt_core_path: Path.join(["priv", "plts", "core.plt"]),
        plt_local_path: Path.join(["priv", "plts", "project.plt"])
      ],
      docs: [
        authors: ["Bart Blast"],
        groups_for_modules: [
          Main: [
            Hologram,
            Hologram.Component,
            Hologram.Component.Action,
            Hologram.Component.Command,
            Hologram.Page,
            Hologram.Server
          ],
          Plug: [Hologram.Router, Hologram.Router.Helpers],
          UI: [Hologram.UI.Link, Hologram.UI.Runtime],
          Errors: [
            Hologram.AssetNotFoundError,
            Hologram.CompileError,
            Hologram.ParamError,
            Hologram.TemplateSyntaxError
          ]
        ],
        source_ref: "v#{@version}"
      ],
      elixir: "~> 1.19",
      elixirc_options: [
        # These modules are used only in tests to test whether Hex.Solver's implementations
        # for Inspect and String.Chars protocols are excluded when building runtime and pages JavaScript files.
        no_warn_undefined: [
          Inspect.Hex.Solver.PackageRange,
          String.Chars.Hex.Solver.PackageRange
        ],
        warnings_as_errors: true
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      homepage_url: "https://hologram.page/",
      package: package(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/bartblast/hologram",
      test_paths: ["test/elixir"],
      version: @version
    ]
  end

  defp dep? do
    __MODULE__.module_info()[:compile][:source]
    |> to_string()
    |> String.ends_with?("/deps/hologram/mix.exs")
  end
end
