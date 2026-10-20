# Changelog

## Unreleased

### Breaking changes

- `wrapPackage`: when passing explicit `args`, `"$@"` is no longer
  appended automatically by the wrapper template. If you pass custom
  `args` and want passthrough, include `"$@"` in your args list.
  The default `args` (generated from `flags`) still includes `"$@"`.

- `flagSeparator` default changed from `" "` to `null`. The old `" "`
  default was misleading: it produced separate argv entries, not a
  space-joined arg. `null` now means separate argv entries. If you
  were explicitly passing `flagSeparator = " "` to get separate args,
  remove it (or change to `null`).

- `env` option type changed from `attrsOf str` to a small submodule
  with `value` / `separator` / `ifUnset`. Plain strings keep working
  via coercion (`env.FOO = "bar"` is unchanged). To unset a
  variable, put `unset VAR` in `preHook` — the module system
  doesn't model it as a declarative option. The systemd integration
  reads from `config.outputs.staticEnv` instead of `config.env` and
  drops any entries it can't express as a literal assignment.

### Added

- `lib/modules/command.nix`: base module with shared command spec
  (args, env, hooks, exePath) used by both wrapper and systemd outputs.
- `lib/modules/flags.nix`: flags module with per-flag ordering via
  `{ value, order }` submodules. Default order is 1000. Reading
  `config.flags` returns clean values (order is transparent).
- `lib/modules/env.nix`: env module with per-variable options for
  safe composition through the NixOS module system.
  - `env.<VAR>.value`: always a list of parts joined with
    `separator`. A plain string coerces to a singleton list, so
    `env.FOO = "bar"` works, but reading back always gives a list.
    Parts can be plain strings or `wlib.env.ref "NAME"` runtime
    references. Empty/unset refs drop out cleanly, so no dangling
    separators.
  - `env.<VAR>.separator`: join separator for `value` (default `:`).
  - `env.<VAR>.ifUnset = true`: only apply when the caller's
    environment doesn't already have the variable set.
  - List `value`s merge by concatenation when composed via `apply`,
    so modules stack contributions without fighting over a string.
  - To read another wrapper's literal entry as a string, use
    `lib.concatStringsSep entry.separator entry.value`.
- `wlib.env.ref NAME`: marker for a runtime env-variable reference
  inside `env.<VAR>.value` lists.
- `wlib.env.render`: render an `env` attrset into a shell snippet.
  Exposed for tests and downstream composition.
- `outputs.staticEnv`: subset of `env` that resolves to a plain
  literal string, used by the systemd integration.
- `wrapper.nix` injects `"$@"` into args at order 1001, controllable
  via the ordering system.
- `outputs.wrapper` as the canonical output path (config.wrapper is
  a backward-compatible alias).
