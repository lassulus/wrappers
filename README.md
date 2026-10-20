# wrappers

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

[xkcd 927](https://xkcd.com/927/)

##

Watch this excellent Video by Vimjoyer for an explanation:

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)


## Overview

This library provides two main components:

- `lib.wrapPackage`: Low-level function to wrap packages with additional flags, environment variables, and runtime dependencies
- `lib.wrapModule`: High-level function to create reusable wrapper modules with type-safe configuration options
- `wrapperModules`: Pre-built wrapper modules for common packages (mpv, notmuch, etc.)

## Usage

### Using Pre-built Wrapper Modules

```nix
{
  inputs.wrappers.url = "github:lassulus/wrappers";

  outputs = { self, nixpkgs, wrappers }: {
    packages.x86_64-linux.default =
      (wrappers.wrapperModules.mpv.apply {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        scripts = [ pkgs.mpvScripts.mpris ];
        "mpv.conf".content = ''
          vo=gpu
          hwdec=auto
        '';
        "input.conf".content = ''
          WHEEL_UP seek 10
          WHEEL_DOWN seek -10
        '';
      }).wrapper;
  };
}
```

### Using wrapPackage Directly

```nix
{ pkgs, wrappers, ... }:

wrappers.lib.wrapPackage {
  inherit pkgs;
  package = pkgs.curl;
  runtimeInputs = [ pkgs.jq ];
  env = {
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
  flags = {
    "--silent" = true;
    "--connect-timeout" = "30";
  };
  # Or use args directly for more control:
  # args = [ "--silent" "--connect-timeout" "30" ];
  flagSeparator = "=";  # Use --flag=value instead of --flag value (default is " ")
  preHook = ''
    echo "Making request..." >&2
  '';
}
```

#### Wrapping a specific executable from a package

You can also wrap a specific executable from a package with a custom name:

```nix
wrappers.lib.wrapPackage {
  inherit pkgs;
  package = pkgs.coreutils;
  exePath = "${pkgs.coreutils}/bin/ls";
  binName = "my-ls";
  flags = {
    "--color" = "auto";
    "-l" = true;
  };
}
```

### Creating Custom Wrapper Modules

```nix
{ wlib, lib }:

wlib.wrapModule ({ config, wlib, ... }: {
  options = {
    profile = lib.mkOption {
      type = lib.types.enum [ "fast" "quality" ];
      default = "fast";
      description = "Encoding profile to use";
    };
    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "./output";
      description = "Directory for output files";
    };
  };

  config.package = config.pkgs.ffmpeg;
  config.flags = {
    "-preset" = if config.profile == "fast" then "veryfast" else "slow";
  };
  config.env = {
    FFMPEG_OUTPUT_DIR = config.outputDir;
  };
})
```

## Technical Details

### wrapPackage Function

Arguments:
- `pkgs`: nixpkgs instance
- `package`: Base package to wrap
- `exePath`: Path to the executable to wrap (default: `lib.getExe package`)
- `binName`: Name for the wrapped binary (default: `baseNameOf exePath`)
- `runtimeInputs`: List of packages added to PATH (default: `[]`)
- `env`: Attribute set of environment variables (default: `{}`)
- `flags`: Attribute set of command-line flags (default: `{}`)
  - Value `true`: Flag without argument (e.g., `--verbose`)
  - Value `"string"`: Flag with argument (e.g., `--output "file.txt"`)
  - Value `false` or `null`: Flag omitted
- `flagSeparator`: Separator between flag name and value when generating args from flags (default: `" "`, can be `"="`)
- `args`: List of command-line arguments like argv in execve (default: auto-generated from `flags`)
  - Example: `[ "--silent" "--connect-timeout" "30" ]`
  - If provided, overrides automatic generation from `flags`
- `preHook`: Shell script executed before the command (default: `""`)
- `postHook`: Shell script executed after the command. This will leave a bash process running, use with caution (default: `""`)
- `passthru`: Additional attributes for the derivation's passthru (default: `{}`)
- `aliases`: List of additional symlink names for the executable (default: `[]`)
- `filesToPatch`: List of file paths (glob patterns) relative to package root to patch for self-references (default: `["share/applications/*.desktop"]`)
  - Example: `["bin/*", "lib/*.sh"]` to replace original package paths with wrapped package paths
  - Desktop files are patched by default to update Exec= and Icon= paths
- `filesToExclude`: List of file paths (glob patterns) to exclude from the wrapped package (default: `[]`)
- `patchHook`: Shell script that runs after patchPhase to modify the wrapper package files (default: `""`)
- `wrapper`: Custom wrapper function (optional, overrides default exec wrapper)

The function:
- Preserves all outputs from the original package (man pages, completions, etc.)
- Uses `lndir` for symlinking to maintain directory structure
- Generates a shell wrapper script with proper escaping
- Handles multi-output derivations correctly

### wrapModule Function

Creates a reusable wrapper module with:
- Type-safe configuration options via the module system
- `options`: Exposed options for documentation generation
- `apply`: Function to instantiate the wrapper with settings, returning a config object
  - Access the wrapped package via the `wrapper` attribute of the returned config

Built-in options (always available):
- `pkgs`: nixpkgs instance (required)
- `package`: Base package to wrap
- `extraPackages`: Additional runtime dependencies
- `flags`: Command-line flags (attribute set)
- `flagSeparator`: Separator between flag name and value (default: `" "`)
- `args`: Command-line arguments list (auto-generated from `flags` if not provided)
- `env`: Environment variables
- `preHook`: Shell script executed before the command (default: `""`)
- `postHook`: Shell script executed after the command. This will leave a bash process running, use with caution (default: `""`)
- `passthru`: Additional passthru attributes
- `filesToPatch`: List of file paths (glob patterns) to patch for self-references (default: `["share/applications/*.desktop"]`)
- `filesToExclude`: List of file paths (glob patterns) to exclude from the wrapped package (default: `[]`)
- `patchHook`: Shell script that runs after patchPhase to modify the wrapper package files (default `""`)
- `wrapper`: The resulting wrapped package (read-only, auto-generated from other options)
- `apply`: Function to extend the configuration with additional modules (read-only)

Always available, see [Styling](#styling):
- `styling`: Shared colour scheme, fonts, opacity and cursor settings

Optional modules (import via `wlib.modules.<name>`):
- `systemd`: Generates systemd service files (user and/or system), options are passed through from NixOS

Custom types:
- `wlib.types.file`: File type with `content` and `path` options
  - `content`: File contents as string
  - `path`: Derived path using `pkgs.writeText`

### Module System Integration

The wrapper module system integrates with NixOS module evaluation:
- Uses `lib.evalModules` for configuration evaluation
- Supports all standard module features (imports, conditionals, mkIf, etc.)
- Provides `config` for accessing evaluated configuration
- Provides `options` for introspection and documentation

### Extending Configurations

The `apply` function allows you to extend an already-applied configuration with additional modules, similar to `extendModules` in NixOS:

```nix
# Apply initial configuration
initialConfig = wrappers.wrapperModules.mpv.apply {
  pkgs = pkgs;
  scripts = [ pkgs.mpvScripts.mpris ];
  "mpv.conf".content = ''
    vo=gpu
  '';
};

# Extend with additional configuration
extendedConfig = initialConfig.apply {
  scripts = [ pkgs.mpvScripts.thumbnail ];
  "mpv.conf".content = ''
    profile=gpu-hq
  '';
};

# Access the wrapper
package = extendedConfig.wrapper;
```

The `apply` function re-evaluates the module with both the original settings and the new module, allowing you to override or add to the existing configuration.

## Example Modules

### mpv Module

Wraps mpv with configuration file support and script management:

```nix
(wrappers.wrapperModules.mpv.apply {
  pkgs = pkgs;
  scripts = [ pkgs.mpvScripts.mpris pkgs.mpvScripts.thumbnail ];
  "mpv.conf".content = ''
    vo=gpu
    profile=gpu-hq
  '';
  "input.conf".content = ''
    RIGHT seek 5
    LEFT seek -5
  '';
  flags = {
    "--save-position-on-quit" = true;
  };
}).wrapper
```

### notmuch Module

Wraps notmuch with INI-based configuration:

```nix
(wrappers.wrapperModules.notmuch.apply {
  pkgs = pkgs;
  config = {
    database = {
      path = "/home/user/Mail";
      mail_root = "/home/user/Mail";
    };
    user = {
      name = "John Doe";
      primary_email = "john@example.com";
    };
  };
}).wrapper
```

### Generating systemd Services

Import `wlib.modules.systemd` to generate systemd service files for your wrapper.
The options under `systemd` are the same as `systemd.services.<name>` in NixOS,
passed through directly.

`ExecStart` (including args), `Environment`, `PATH`, `preStart` and `postStop`
are picked up from the wrapper automatically, so you only need to set what's
specific to the service.

The same config produces both a user and system service file, available at
`config.outputs.systemd-user` and `config.outputs.systemd-system`. Use
whichever fits your deployment.

```nix
wlib.wrapModule ({ config, wlib, ... }: {
  imports = [ wlib.modules.systemd ];

  config = {
    package = config.pkgs.hello;
    flags."--greeting" = "world";
    env.HELLO_LANG = "en";
    systemd = {
      description = "Hello service";
      serviceConfig.Type = "simple";
      serviceConfig.Restart = "on-failure";
    };
  };
})
```

Settings merge when using `apply`:

```nix
extended = myWrapper.apply {
  systemd.serviceConfig.Restart = "always";
  systemd.environment.EXTRA = "value";
};
```

#### Using in NixOS

You need both `systemd.packages` for the unit file and the corresponding
`wantedBy` to actually activate it. NixOS does not read the `[Install]` section
from unit files, it creates the `.wants` symlinks from the module option instead.

As a user service (for all users):

```nix
# configuration.nix
{ pkgs, wrappers, ... }:
let
  myHello = wrappers.wrapperModules.hello.apply {
    inherit pkgs;
    systemd.serviceConfig.Restart = "always";
  };
in {
  systemd.packages = [ myHello.outputs.systemd-user ];
  # NixOS needs this to create the .wants symlink, the [Install]
  # section in the unit file alone is not enough
  systemd.user.services.hello.wantedBy = [ "default.target" ];
}
```

As a system service:

```nix
# configuration.nix
{ pkgs, wrappers, ... }:
let
  myHello = wrappers.wrapperModules.hello.apply {
    inherit pkgs;
    systemd.serviceConfig.Restart = "always";
  };
in {
  systemd.packages = [ myHello.outputs.systemd-system ];
  systemd.services.hello.wantedBy = [ "multi-user.target" ];
}
```

#### Using in home-manager

For per-user services, link via `xdg.dataFile`:

```nix
# home.nix
{ pkgs, wrappers, ... }:
let
  myHello = wrappers.wrapperModules.hello.apply {
    inherit pkgs;
    systemd.wantedBy = [ "default.target" ];
    systemd.serviceConfig.Restart = "always";
  };
in {
  xdg.dataFile."systemd/user/hello.service".source =
    "${myHello.outputs.systemd-user}/systemd/user/hello.service";
}
```

## Styling

Every wrapper module has a `styling` option group: one colour scheme, font,
opacity and cursor definition that programs derive their own configuration
from. It plays the role stylix plays for NixOS and home-manager, but stays
inside the wrapper module system, so it works the same on nixos, home-manager,
nix-darwin, devenv, or a bare `nix build`.

Wrapper modules are evaluated independently of each other, so there is no
shared configuration for a theme to live in. `wlib.applyStyle` maps one
definition over as many modules as you like:

```nix
{ pkgs, wrappers, ... }:
let
  themed = wrappers.lib.applyStyle {
    inherit pkgs;
    styling = {
      scheme = "gruvbox-dark-hard";
      fonts.monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      fonts.sizes.terminal = 12;
      opacity.terminal = 0.9;
    };
  } { inherit (wrappers.wrapperModules) alacritty foot rofi waybar; };
in
[
  themed.alacritty.wrapper
  themed.foot.wrapper
  themed.rofi.wrapper
  themed.waybar.wrapper
]
```

The results are ordinary configs, so a single program can still be refined
afterwards without losing the shared theme:

```nix
themed.alacritty.apply {
  # keep the scheme, but with a black background
  styling.palette.base00 = "000000";
}
```

Nothing forces you to use the helper. `styling` is a normal option group, so
passing it to a single `apply` works too:

```nix
(wrappers.wrapperModules.foot.apply {
  inherit pkgs;
  styling.scheme = "gruvbox-dark-hard";
}).wrapper
```

### Colour scheme

`styling.scheme` accepts the name of any scheme in `pkgs.base16-schemes`, or a
path or derivation holding a base16 YAML file:

```nix
styling.scheme = "gruvbox-dark-hard";
styling.scheme = ./my-scheme.yaml;
```

It populates `styling.palette.base00` through `styling.palette.base0F`. Those
are ordinary options, so any individual colour can be changed without giving up
the scheme:

```nix
styling.scheme = "gruvbox-dark-hard";
styling.palette.base0D = "abcdef";
```

Colours are stored as lower case 6 digit hex **without** a `#` prefix, because
that is the one form every config format can be derived from. Add the prefix
you need with the helpers below.

`styling.colors` exposes the same palette under semantic names, which is what
modules should read — `colors.background` says what a value means where
`palette.base00` does not:

| | | | |
|---|---|---|---|
| `background` base00 | `backgroundAlt` base01 | `selection` base02 | `comment` base03 |
| `foregroundAlt` base04 | `foreground` base05 | `foregroundBright` base06 | `backgroundBright` base07 |
| `red` base08 | `orange` base09 | `yellow` base0A | `green` base0B |
| `cyan` base0C | `blue` base0D | `magenta` base0E | `brown` base0F |
| `accent` base0D | `error` base08 | `warning` base0A | `success` base0B |
| `info` base0C | | | |

`styling.colors.ansi` additionally provides the standard base16 mapping onto
the 16 ANSI terminal colours (`black`, `red`, … `white`, `brightBlack`, …
`brightWhite`), so terminals do not each have to invent their own.

### Options

| Option | Default | Description |
|---|---|---|
| `styling.enable` | `styling.scheme != null` | Whether this wrapper styles itself |
| `styling.scheme` | `null` | Scheme name, path, or derivation |
| `styling.palette.base00`–`base0F` | from the scheme | Individual colours |
| `styling.colors` | derived, read only | Semantic aliases and `colors.ansi` |
| `styling.polarity` | from the scheme | `"light"` or `"dark"` |
| `styling.fonts.{monospace,sansSerif,serif,emoji}` | DejaVu, Noto Color Emoji | `{ package; name; }` |
| `styling.fonts.sizes.{applications,terminal,desktop,popups}` | `12`, `12`, `10`, `10` | Font sizes |
| `styling.fonts.packages` | derived, read only | The configured font packages, deduplicated |
| `styling.fonts.provideFontconfig` | `false` | Set `FONTCONFIG_FILE` so the wrapper carries its own fonts |
| `styling.opacity.{applications,terminal,desktop,popups}` | `1.0` | Opacity, from `0.0` to `1.0` |
| `styling.cursor` | Adwaita, size 24 | `{ package; name; size; }` |

`styling.enable` turns itself on as soon as a scheme is set, so one definition
themes everything. Wrappers that should keep their own look opt out
individually:

```nix
(wrappers.wrapperModules.foot.apply {
  inherit pkgs;
  styling.scheme = "gruvbox-dark-hard";
  styling.enable = false;
}).wrapper
```

With no scheme set anywhere, `styling.enable` is false and no wrapper changes
behaviour. Enabling it without a scheme is fine too — the palette falls back to
`default-dark`, which is useful when you only care about fonts.

### Helpers

`wlib.style` converts a stored colour into whatever shape a program wants:

| Function | Result |
|---|---|
| `withHash "1d2021"` | `"#1d2021"` |
| `toRGB "1d2021"` | `{ r = 29; g = 32; b = 33; }` |
| `rgbCss "1d2021"` | `"rgb(29, 32, 33)"` |
| `rgbaCss "1d2021" 0.9` | `"rgba(29, 32, 33, 0.9)"` |
| `withAlpha "1d2021" 0.9` | `"1d2021e6"` |
| `formatNumber 0.9` | `"0.9"` (`toString` would give `"0.900000"`) |
| `luminance "1d2021"` | approximate brightness, `0.0` to `1.0` |
| `isDark "1d2021"` | `true` |
| `mkDefaults` | lowers every leaf of an attrset to `lib.mkDefault` |

It also exposes `parseScheme`, `resolveScheme` and `slots` for working with
base16 schemes directly. Scheme loading is pure — a small line based parser
rather than a YAML tool — so `nix flake check` never needs import from
derivation. The parser reads the canonical base16 layout, which is what all
303 schemes in `pkgs.base16-schemes` use; a file spelling a slot as `base0a`
is reported as missing `base0A`.

### Adding styling support to a module

A module opts in by deriving settings from `styling`, gated on
`styling.enable`:

```nix
{ config, lib, wlib, ... }:
{
  config.settings = lib.mkIf config.styling.enable (
    let
      inherit (config) styling;
      inherit (wlib.style) withHash;
    in
    wlib.style.mkDefaults {
      font.normal.family = styling.fonts.monospace.name;
      font.size = styling.fonts.sizes.terminal;

      colors.primary.background = withHash styling.colors.background;
      colors.primary.foreground = withHash styling.colors.foreground;
      colors.normal.red = withHash styling.colors.ansi.red;

      window.opacity = styling.opacity.terminal;
    }
  );
}
```

Two rules:

- **Gate on `config.styling.enable`.** It is false until a scheme is set, which
  is what keeps styling from changing the behaviour of wrappers that do not
  want it.
- **Every derived value must be a default**, via `wlib.style.mkDefaults` or an
  explicit `lib.mkDefault`. A `settings` option is declared with `default = { }`,
  which is priority 1500, so a plain `config.settings.x = …` from styling lands
  at priority 100 and would silently outrank the user's own value. Defining it
  as a default puts the user back on top.

Fonts are found through fontconfig, not `PATH`, so there is no point adding
`styling.fonts.*.package` to `extraPackages`. A module only needs the font's
`name`; users who want a self-contained wrapper turn on
`styling.fonts.provideFontconfig`.

Styling is usually worth keeping in its own file, pulled in with a plain
`imports`, so that a module's own configuration stays readable:

```nix
# modules/<name>/module.nix
{
  imports = [ ./styling.nix ];
  # ...
}
```

`modules/alacritty` is the worked example: `styling.nix` derives colours,
fonts and opacity, and `check.nix` shows how to test a styled module by
asserting on the generated config rather than on the built wrapper, which
keeps the check from having to build the program.

## alternatives

- [wrapper-manager](https://github.com/viperML/wrapper-manager) by viperML. This project focuses more on a single module system, configuring wrappers and exporting them. This was an inspiration when building this library, but I wanted to have a more granular approach with a single module per package and a collection of community made modules.

## Long-term Goals

Upstream this schema into nixpkgs with an optional module.nix for every package. NixOS modules could then reuse these wrapper modules for consistent configuration across platforms.
