[
  checks: [baseline: ".reach-baseline.json"],
  # ExDNA runs as a separate zero-clone gate in .check.exs.
  clone_analysis: [provider: false],
  smells: [
    strict: true,
    ignore: [paths: ["benchmarks/**"]]
  ]
]
