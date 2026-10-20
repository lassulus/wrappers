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

### Environment Variables

Each `env.<NAME>` entry is either a plain string or a small
submodule:

```nix
{
  env = {
    # Literal:
    FOO = "bar";

    # Prepend to PATH using a list and `wlib.env.ref`. The ref
    # expands to the caller's existing PATH at runtime; if it's
    # unset or empty, the ref drops out and no stray separators
    # are left behind.
    PATH.value = [ "/opt/bin" (wrappers.lib.env.ref "PATH") ];

    # Only set EDITOR if the caller hasn't already picked one.
    EDITOR = { value = "vim"; ifUnset = true; };
  };

  # To unset a variable inherited from the caller, drop a line in
  # preHook — the env option is for declarative assignments only:
  preHook = ''
    unset LD_PRELOAD
  '';
}
```

Submodule options:
- `value`: a list of parts joined with `separator`. Plain strings
  coerce to singleton lists, so `env.FOO = "bar"` works, but
  reading back always gives a list. Parts can be plain strings or
  `wlib.env.ref "NAME"` runtime references.
- `separator`: join separator (default `:`).
- `ifUnset`: only apply when the caller's environment doesn't
  already have the variable set (empty counts as unset).

`value` is always a list when read back, so consumers inspecting
another wrapper's config don't need to safeguard against two
types. To read a literal entry as a joined string, use
`lib.concatStringsSep entry.separator entry.value`.

List `value`s merge by concatenation when composed via `apply`, so
multiple modules stack contributions onto the same variable without
fighting over a single string.

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

## alternatives

- [wrapper-manager](https://github.com/viperML/wrapper-manager) by viperML. This project focuses more on a single module system, configuring wrappers and exporting them. This was an inspiration when building this library, but I wanted to have a more granular approach with a single module per package and a collection of community made modules.

## Long-term Goals

Upstream this schema into nixpkgs with an optional module.nix for every package. NixOS modules could then reuse these wrapper modules for consistent configuration across platforms.
