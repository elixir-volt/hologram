opts = [enabled: true, env: %{"MIX_ENV" => "test"}]

[
  retry: false,
  tools: [
    {:compiler, opts},
    {:credo, opts},
    {:dialyzer, opts},
    {:doctor, opts},
    {:ex_dna, "mix ex_dna --max-clones 0", opts},
    {:reach, "mix reach.check --arch --smells --strict", opts},
    {:volt_js, "mix volt.js.check", opts},
    {:ex_doc, enabled: false},
    {:ex_formatter, "mix format", opts},
    {:ex_test_file_names, "mix holo.test.check_file_names test/elixir/hologram", opts},
    {:ex_tests, "mix test", opts},
    # custom :ex_tests used instead of :ex_unit
    {:ex_unit, enabled: false},
    # custom :ex_formatter used instead of :formatter
    {:formatter, enabled: false},
    {:gettext, enabled: false},
    {:hex_audit, "mix hex.audit", opts},
    {:js_formatter, "mix format.js.check", opts},
    {:mix_audit, opts},
    # JavaScript tests run through ExUnit via Volt.Test.ExUnit.
    {:npm_test, enabled: false},
    {:sobelow, "mix sobelow --config", opts},
    {:unused_deps, opts}
  ]
]
