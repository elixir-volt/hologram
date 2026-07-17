# VibeKit quality gate

## Development

```sh
mix deps.get
mix ci
```

`mix ci` delegates to Hologram's existing `mix check` pipeline, which remains the canonical full-project quality gate.

## Conventions

- Run focused checks while developing and `mix ci` before finishing changes.
- Keep changes small, tested, and formatted.
- Treat ExSlop findings as Credo findings.
- Keep ExDNA at zero structural clones; refactor findings instead of suppressing them.
- Reach's checked-in baseline records pre-existing brownfield findings so new architecture and cross-function smells still fail CI.
- Preserve Hologram's supported Elixir and Erlang/OTP matrix.
