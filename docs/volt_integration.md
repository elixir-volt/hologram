# Volt Integration

## Architecture

Hologram's browser runtime is packaged as TypeScript under `priv/ts`, following the OTP convention for framework-owned runtime files. `Hologram.Volt.Plugin` exposes those physical files through the stable `hologram:runtime/*` module namespace.

The compiler uses the same namespace in generated page and runtime entries and passes the Hologram plugin to `Volt.Builder`. Tests and benchmarks therefore resolve the same packaged sources as production builds instead of relying on a parallel runtime tree.

Generated entries are valid TypeScript templates:

- `priv/ts/runtime_entry.ts`
- `priv/ts/page_entry.ts`

The compiler calls `Volt.Priv` directly for OTP path handling and AST-backed statement splicing of generated import, binding, and function-definition blocks. No Hologram-specific template adapter, EEx, or raw generated entry template is embedded in Elixir source.

## Dependencies and output

Runtime npm packages are exact-pinned by `Hologram.Assets.NPMDeps` and installed through Volt's npm_ex-backed cache. Importer-scoped package roots keep those framework-owned versions isolated from packages with the same names in an application. Application builds do not depend on `assets/node_modules`; that directory contains only repository tooling such as Prettier and Playwright.

`Hologram.Compiler.build_assets/2` passes the generated runtime and page entries to the multi-entry `Volt.Builder.build/1` production pipeline. Volt owns code splitting, content hashes, JavaScript output, source maps, and `manifest.json`. CSS entries remain explicitly rejected until Hologram loads their manifest entries. Hologram reads that manifest through `Hologram.Assets.BundleManifest` to resolve runtime and page entry URLs; it no longer computes bundle digests, rewrites source-map comments, or maintains a parallel page-digest PLT. The former esbuild shell integration and `assets/js` runtime mirror have been removed.

Volt/OXC formats and lints the packaged runtime and repository-owned JavaScript and TypeScript without a Node.js process. Canonical compatibility tests are linted but intentionally excluded from formatting so their bodies remain unchanged. Prettier remains only for repository YAML and JSON.

## Testing

The canonical JavaScript suite under `test/javascript` imports `hologram:runtime/*` and executes through Volt. QuickBEAM handles runtime-only suites, while five explicitly documented DOM suites use Volt's Playwright browser runner. See `docs/volt_js_test_migration.md` for parity and compatibility details.

Browser helper aliases, Sinon compatibility, and npm test dependencies live under `test/`; none are included in the published Hologram package.

## Future work

- Replace the remaining repository-only YAML and JSON formatting when Volt/OXC supports those file types.
- Integrate Hologram live reload with Volt HMR where that improves development feedback.
- Add TypeScript types incrementally without coupling runtime migration to a wholesale rewrite.
