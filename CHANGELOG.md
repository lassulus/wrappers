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

### Added

- `lib/modules/styling.nix`: cross-cutting styling module, imported into
  every wrapper. Provides `styling.scheme` (a base16 scheme by name from
  `pkgs.base16-schemes`, or by path), `styling.palette`,
  `styling.colors` (semantic aliases plus the 16 ANSI colours),
  `styling.polarity`, `styling.fonts`, `styling.opacity` and
  `styling.cursor`. `styling.enable` turns on as soon as a scheme is set and
  can be switched off per wrapper, so wrappers with no scheme configured are
  unaffected. See the Styling section of the README.
- `wlib.applyStyle`: apply one settings module to a set of wrapper modules at
  once, so a single theme can reach every program.
- `modules/alacritty`: derives colours, font and opacity from `styling` in a
  separate `styling.nix`, as the worked example of a styled module. Also
  gains a `check.nix`, which it did not have before.
- `wlib.style`: base16 scheme parsing (`parseScheme`, `resolveScheme`,
  `slots`) and colour formatting helpers (`withHash`, `toRGB`, `rgbCss`,
  `rgbaCss`, `withAlpha`, `formatNumber`, `luminance`, `isDark`,
  `mkDefaults`). Scheme loading is pure, with no import from derivation.
- `lib/modules/command.nix`: base module with shared command spec
  (args, env, hooks, exePath) used by both wrapper and systemd outputs.
- `lib/modules/flags.nix`: flags module with per-flag ordering via
  `{ value, order }` submodules. Default order is 1000. Reading
  `config.flags` returns clean values (order is transparent).
- `wrapper.nix` injects `"$@"` into args at order 1001, controllable
  via the ordering system.
- `outputs.wrapper` as the canonical output path (config.wrapper is
  a backward-compatible alias).
