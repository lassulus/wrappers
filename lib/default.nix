{ lib }:
let
  /**
    flagToArgs {
      flagSeparator: null | str,
      name: str,
      flag: bool | str | [ str | [ str ] ]
    } -> [ str ]

    flagSeparator = null  -> ["--flag" "value"]  (separate argv entries, default)
    flagSeparator = "="   -> ["--flag=value"]     (joined with separator)
    flagSeparator = " "   -> ["--flag value"]     (joined with space, single arg)
  */
  flagToArgs =
    {
      flagSeparator ? null,
      name,
      flag,
    }:
    if flag == false then
      [ ]
    else if flag == true then
      [ name ]
    else if lib.isStringLike flag then
      if flagSeparator == null then
        [
          name
          (toString flag)
        ]
      else
        [ "${name}${flagSeparator}${toString flag}" ]

    else if lib.isList flag then
      lib.concatMap (
        v:
        if lib.isStringLike v then
          if flagSeparator == null then
            [
              name
              (toString v)
            ]
          else
            [ "${name}${flagSeparator}${toString v}" ]
        else if builtins.isList v then
          [ name ]
          ++ (map (
            v_:
            if lib.isStringLike v_ then
              toString v_
            else
              throw "flag ${name} has unsupported list element type ${lib.typeOf v_}, expected path or str"
          ) v)
        else
          throw "flag ${name} has unsupported list element type ${lib.typeOf v}, expected path, str or list"
      ) flag
    else
      throw "flag ${name} has unsupported type ${lib.typeOf flag}, expected bool, path, str, or list";

  # Helper function to generate args list from flags attrset
  generateArgsFromFlags =
    flags: flagSeparator:
    lib.concatLists (
      lib.mapAttrsToList (name: flag: flagToArgs { inherit flagSeparator name flag; }) flags
    );

  /**
    A function to create a wrapper module.
    returns an attribute set with options and apply function.

    Example usage:
      helloWrapper = wrapModule (wlib: { config, ... }: {
        options.greeting = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
        config.package = config.pkgs.hello;
        config.flags = {
          "--greeting" = config.greeting;
        };
        # Or use args directly:
        # config.args = [ "--greeting" config.greeting ];
      };

      helloWrapper.apply {
        pkgs = pkgs;
        greeting = "hi";
      };

      # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
  */

  /**
    Escape a shell argument while preserving environment variable expansion.
    This escapes backslashes and double quotes to prevent injection, then
    wraps the result in double quotes.
    Unlike lib.escapeShellArg which uses single quotes, this allows
    environment variable expansion (e.g., $HOME, ${VAR}).

    # Example

    ```nix
    escapeShellArgWithEnv "$HOME/config.txt"
    => "\"$HOME/config.txt\""

    escapeShellArgWithEnv "/path/with\"quote"
    => "\"/path/with\\\"quote\""

    escapeShellArgWithEnv "/path/with\\backslash"
    => "\"/path/with\\\\backslash\""
    ```
  */
  escapeShellArgWithEnv =
    arg:
    let
      argStr = toString arg;
      # Escape backslashes first, then double quotes
      escaped = lib.replaceStrings [ ''\'' ''"'' ] [ ''\\'' ''\"'' ] argStr;
    in
    ''"${escaped}"'';

  /**
    A collection of types for wrapper modules.
    For now this only contains a file type.
  */
  types = {
    /**
      A type for configuration files in wrapper modules.

      This type creates a submodule with two options:
      - `content`: The text content of the file (type: lines)
      - `path`: The path to the file in the Nix store (type: path, auto-generated)

      # Arguments

      - `pkgs`: The nixpkgs instance to use for writeText

      # Usage

      This type is particularly useful for wrapper modules that need to manage
      configuration files. The `content` option accepts the file contents as a string,
      and the `path` option is automatically derived using `pkgs.writeText` with the
      attribute name and content.

      # Example

      ```nix
      wlib.wrapModule ({ config, wlib, ... }: {
        options = {
          "app.conf" = lib.mkOption {
            type = wlib.types.file config.pkgs;
            default.content = "";
            description = "Configuration file for the application";
          };
        };

        config.flags = {
          "--config" = config."app.conf".path;
        };
      })
      ```

      In the above example:
      - The option name "app.conf" becomes the filename in the store
      - Users can set content via `"app.conf".content = "setting=value";`
      - The generated file path is available via `"app.conf".path`
      - The path can be passed to the wrapped program via flags or environment variables

      # Advanced Usage

      You can override the `path` option if you need to use a different file source.
      When you override `path`, the `content` option is ignored.

      ```nix
      {
        # Default behavior: content written to store
        "app.conf".content = "foo=bar";

        # Custom store path (e.g., a derivation output or local file):
        # "app.conf".path = ./my-config.conf;
        # or
        # "app.conf".path = pkgs.writeText "custom-name" "custom content";

        # Path outside the Nix store (requires quoting as string):
        # Note: This creates an impure path reference
        # "app.conf".path = "/home/user/.config/app.conf";

        # Using an environment variable for the path:
        # Useful for user-specific or runtime-determined paths
        # "app.conf".path = "$HOME/.config/app.conf";
        # or
        # "app.conf".path = "\${XDG_CONFIG_HOME:-$HOME/.config}/app.conf";
      }
      ```

      When using paths outside the Nix store or environment variables:
      - The path must be a string (quoted), not a Nix path literal
      - The path will be passed as-is to the wrapped program
      - Environment variables in the path string will be expanded by the shell at runtime
      - Be aware that this creates impure behavior (path may not exist at build time)

      # Type Signature

      ```
      file: pkgs -> submodule { content: lines, path: path | str }
      ```
    */
    file =
      # we need to pass pkgs here, because writeText is in pkgs
      pkgs:
      lib.types.submodule (
        { name, config, ... }: {
          options = {
            content = lib.mkOption {
              type = lib.types.lines;
              description = ''
                Content of the file. This can be a multi-line string that will be
                written to the Nix store and made available via the path option.
              '';
            };
            path = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.str;
              description = ''
                The path to the file. By default, this is automatically
                generated using pkgs.writeText with the attribute name and content.
                You can override this to provide:
                - A custom Nix path (e.g., ./config.txt or pkgs.writeText "name" "content")
                - An absolute path string outside the store (e.g., "/etc/config.txt")
                - A path with environment variables (e.g., "$HOME/.config/app.conf")
              '';
              default = pkgs.writeText name config.content;
              defaultText = "pkgs.writeText name <content>";
            };
          };
        }
      );
  };

  _evalModules =
    {
      modules,
      class ? "wrapper",
      specialArgs ? {
        wlib = wrapperLib;
      },
    }:
    lib.evalModules { inherit modules class specialArgs; };

  modules = lib.genAttrs [
    "package"
    "flags"
    "command"
    "wrapper"
    "meta"
    "styling"
    "systemd"
  ] (name: import ./modules/${name}.nix);

  /**
    Colour scheme loading and colour formatting helpers, used by the styling
    module and by any wrapper module that derives configuration from it.
  */
  style =
    (import ./style/base16.nix { inherit lib; }) // (import ./style/colors.nix { inherit lib; });

  /**
    Apply the same settings to a set of wrapper modules at once.

    Wrapper modules are evaluated independently, so there is no shared
    configuration for a theme to live in. This maps one settings module over a
    whole set of them, which is how a single `styling` definition reaches
    every program.

    # Type
    ```
    applyStyle :: Module -> AttrsOf WrapperModule -> AttrsOf Config
    ```

    # Example

    ```nix
    themed = wlib.applyStyle {
      inherit pkgs;
      styling.scheme = "gruvbox-dark-hard";
    } { inherit (wrappers.wrapperModules) alacritty foot rofi; };

    # themed.alacritty.wrapper, themed.foot.wrapper, ...
    ```

    The results are ordinary configs, so they can be refined further per
    program with their own `apply`.
  */
  applyStyle =
    settings: wrapperModules: lib.mapAttrs (_: module: module.apply settings) wrapperModules;

  /**
    Create a wrapper configuration using the NixOS module system.

    This function provides a type-safe way to configure wrappers using the same
    module system as NixOS. It evaluates the provided module and returns a
    configuration object that can be incrementally extended.

    # Type
    ```
    wrapModule :: Module -> Config
    ```

    # Arguments
    - `wrapperModule`: A NixOS-style module defining the wrapper configuration.
      Can use options like `package`, `flags`, `env`, etc. from the wrapper module.

    # Returns
    A configuration object containing:
    - All wrapper option values (package, flags, env, etc.)
    - `extend :: Module -> Evaluation` - Returns full module evaluation (has .config, .extendModules, .options)
    - `apply :: Module -> Config` - Returns extended .config (has option values and extend/apply functions)

    # Examples

    Basic usage:
    ```nix
    wrapper = wrapModule {
      package = pkgs.hello;
      flags."--greeting" = "Hello";
    };
    ```

    Using `apply` for incremental configuration:
    ```nix
    wrapper = wrapModule {
      package = pkgs.hello;
    };

    wrapper' = wrapper.apply {
      flags."--greeting" = "Hi";
    };
    # wrapper'.package is pkgs.hello
    # wrapper'.flags."--greeting" is "Hi"
    ```

    Using `extend` to access module system functions:
    ```nix
    wrapper = wrapModule {
      package = pkgs.hello;
    };

    extended = wrapper.extend {
      flags."--greeting" = "Hi";
    };
    # extended.config.package is pkgs.hello
    # extended.options - available for inspection
    # extended.extendModules - available for further extension
    ```
  */
  wrapModule =
    wrapperModule:
    let
      eval = _evalModules {
        modules = [
          ({ config, ... }: {
            options = {
              _appliedModules = lib.mkOption {
                type = lib.types.listOf lib.types.raw;
                internal = true;
                default = [ ];
                description = ''
                  Internal option storing the list of modules applied via extend/apply.
                  Used by extend to re-evaluate with all accumulated modules.
                '';
              };
              extend = lib.mkOption {
                type = lib.types.functionTo lib.types.raw;
                description = ''
                  Function to extend the current configuration with additional settings.
                  Re-evaluates the configuration with the original modules plus the new settings.
                '';
                default =
                  module:
                  let
                    allModules = config._appliedModules ++ [ module ];
                  in
                  eval.extendModules { modules = allModules ++ [ { _appliedModules = lib.mkForce allModules; } ]; };
              };
              apply = lib.mkOption {
                type = lib.types.functionTo lib.types.raw;
                readOnly = true;
                description = ''
                  Function to extend the current configuration with additional modules.
                  Re-evaluates the configuration with the original settings plus the new module.
                '';
                default = module: (config.extend module).config;
              };
            };
          })
          modules.wrapper
          modules.meta
          modules.styling
          wrapperModule
        ];
      };
    in
    eval.config;

  /**
    Create a wrapped application that preserves all original outputs (man pages, completions, etc.)

    # Arguments

    - `pkgs`: The nixpkgs pkgs instance to use
    - `package`: The package to wrap
    - `exePath`: Path to the executable to wrap (optional, defaults to lib.getExe package)
    - `binName`: Name for the wrapped binary (optional, defaults to baseNameOf exePath)
    - `runtimeInputs`: List of packages to add to PATH (optional)
    - `env`: Attribute set of environment variables to export (optional)
    - `flags`: Attribute set of command-line flags to add (optional)
    - `flagSeparator`: Separator between flag names and values when generating args from flags (optional, defaults to null for separate argv entries, use "=" for joined)
    - `args`: List of command-line arguments like argv in execve (optional, auto-generated from flags if not provided)
    - `preHook`: Shell script to run before executing the command (optional)
    - `postHook`: Shell script to run after executing the command, removes the `exec` call. use with care (optional)
    - `passthru`: Attribute set to pass through to the wrapped derivation (optional)
    - `aliases`: List of additional names to symlink to the wrapped executable (optional)
    - `filesToPatch`: List of file paths (glob patterns) to patch for self-references (optional, defaults to ["share/applications/*.desktop"])
    - `filesToExclude`: List of file paths (glob patterns) to exclude from the wrapped package (optional, defaults to [])
    - `patchHook`: Shell script that runs after patchPhase to modify the wrapper package files (optional)
    - `wrapper`: Custom wrapper function (optional, defaults to exec'ing the original binary with args)
      - Called with { env, flags, args, envString, flagsString, exePath, preHook, postHook }

    # Example

    ```nix
    wrapPackage {
      pkgs = pkgs;
      package = pkgs.curl;
      runtimeInputs = [ pkgs.jq ];
      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      flags = {
        "--silent" = { }; # becomes --silent
        "--connect-timeout" = "30"; # becomes --connect-timeout 30
      };
      # Or use args directly:
      # args = [ "--silent" "--connect-timeout" "30" ];
      preHook = ''
        echo "Making request..." >&2
      '';
    }

    # With custom executable path and binary name:
    wrapPackage {
      pkgs = pkgs;
      package = pkgs.coreutils;
      exePath = "${pkgs.coreutils}/bin/ls";
      binName = "my-ls";
      flags = {
        "--color" = "auto";
      };
    }

    # Or with custom wrapper:
    wrapPackage {
      pkgs = pkgs;
      package = pkgs.someProgram;
      wrapper = { exePath, flagsString, envString, preHook, ... }: ''
        ${envString}
        ${preHook}
        echo "Custom logic here"
        exec ${exePath} ${flagsString} "$@"
      '';
    }
    ```
  */
  wrapPackage =
    {
      pkgs,
      package,
      exePath ? lib.getExe package,
      binName ? baseNameOf exePath,
      runtimeInputs ? [ ],
      env ? { },
      flags ? { },
      flagSeparator ? null,
      # null for "--flag" "value" (separate args) or "=" for "--flag=value"
      args ? generateArgsFromFlags flags flagSeparator ++ [ "$@" ],
      preHook ? "",
      postHook ? "",
      passthru ? { },
      aliases ? [ ],
      # List of file paths (glob patterns) relative to package root to patch for self-references (e.g., ["bin/*", "lib/*.sh"])
      filesToPatch ? [
        "nix-support/*"
        "share/applications/*.desktop"
      ],
      # List of file paths (glob patterns) to exclude from the wrapped package (e.g., ["bin/unwanted-*", "share/doc/*"])
      filesToExclude ? [ ],
      patchHook ? "",
      wrapper ? (
        {
          exePath,
          flagsString,
          envString,
          preHook,
          postHook,
          ...
        }:
        ''
          ${envString}
          ${preHook}
          ${lib.optionalString (postHook == "") "exec"} ${exePath}${flagsString}
          ${postHook}
        ''
      ),
    }@funcArgs:
    let
      inherit (pkgs) lndir;

      # Generate environment variable exports
      envString =
        if env == { } then
          ""
        else
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: ''export ${name}="${toString value}"'') env
          )
          + "\n";

      # Generate flag arguments with proper line breaks and indentation
      flagsString =
        if args == [ ] then
          ""
        else
          " \\\n  " + lib.concatStringsSep " \\\n  " (map wrapperLib.escapeShellArgWithEnv args);

      finalWrapper = wrapper {
        inherit
          env
          flags
          args
          envString
          flagsString
          exePath
          preHook
          postHook
          ;
      };

      # Multi-output aware symlink join function with optional file patching
      multiOutputSymlinkJoin =
        {
          name,
          paths,
          outputs ? [ "out" ],
          originalOutputs ? { },
          passthru ? { },
          meta ? { },
          aliases ? [ ],
          binName ? null,
          filesToPatch ? [ ],
          filesToExclude ? [ ],
          patchHook ? "",
          ...
        }@args:
        pkgs.stdenv.mkDerivation (
          {
            inherit name outputs;

            buildCommand = ''
              # Symlink all paths to the main output
              mkdir -p $out
              for path in ${lib.concatStringsSep " " (map toString paths)}; do
                ${lndir}/bin/lndir -silent "$path" $out
              done

              # Exclude specified files
              ${lib.optionalString (filesToExclude != [ ]) ''
                echo "Excluding specified files..."
                ${lib.concatMapStringsSep "\n" (pattern: ''
                  for file in $out/${pattern}; do
                    if [[ -e "$file" ]]; then
                      echo "Removing $file"
                      rm -f "$file"
                    fi
                  done
                '') filesToExclude}
              ''}

              # Handle additional outputs by symlinking from the original package's outputs
              ${lib.concatMapStringsSep "\n" (
                output:
                if output != "out" && originalOutputs ? ${output} && originalOutputs.${output} != null then
                  ''
                    if [[ -n "''${${output}:-}" ]]; then
                      mkdir -p ${"$" + output}
                      # Only symlink from the original package's corresponding output
                      ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
                    fi
                  ''
                else
                  ""
              ) outputs}

              # Patch specified files to replace references to the original package with the wrapped one
              ${lib.optionalString (filesToPatch != [ ]) ''
                echo "Patching self-references in specified files..."
                oldPath="${package}"
                newPath="$out"

                # Process each output
                ${lib.concatMapStringsSep "\n" (
                  output:
                  if originalOutputs ? ${output} && originalOutputs.${output} != null then
                    ''
                      # Process each file pattern
                      ${lib.concatMapStringsSep "\n" (pattern: ''
                        for file in ${"$" + output}/${pattern}; do
                          if [[ -L "$file" ]]; then
                            # It's a symlink, we need to resolve it
                            target=$(readlink -f "$file")

                            # Check if the file contains the old path
                            if grep -qF "$oldPath" "$target" 2>/dev/null; then
                              echo "Patching $file"
                              # Remove symlink and create a real file with patched content
                              rm "$file"
                              # Use replace-literal which works for both text and binary files
                              substitute "$target" "$file" --replace-fail "$oldPath" "$newPath"
                              # Preserve permissions
                              chmod --reference="$target" "$file"
                            fi
                          fi
                        done
                      '') filesToPatch}
                    ''
                  else
                    ""
                ) outputs}
              ''}
              ${patchHook}

              # Create symlinks for aliases
              ${lib.optionalString (aliases != [ ] && binName != null) ''
                mkdir -p $out/bin
                for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
                  ln -sf ${lib.escapeShellArg binName} $out/bin/$alias
                done
              ''}
            '';

            inherit passthru meta;
          }
          // (removeAttrs args [
            "name"
            "paths"
            "outputs"
            "originalOutputs"
            "passthru"
            "meta"
            "aliases"
            "binName"
            "filesToPatch"
            "filesToExclude"
            "patchHook"
          ])
        );

      # Get original package outputs for symlinking
      originalOutputs =
        if package ? outputs then
          lib.listToAttrs (
            map (output: {
              name = output;
              value = if package ? ${output} then package.${output} else null;
            }) package.outputs
          )
        else
          { };

      # Create the wrapper derivation using our multi-output aware symlink join
      wrappedPackage = multiOutputSymlinkJoin (
        {
          name = package.pname or package.name;
          paths = [
            (pkgs.writeShellApplication {
              name = binName;
              runtimeInputs = runtimeInputs;
              text = finalWrapper;
            })
            package
          ];
          outputs = if package ? outputs then package.outputs else [ "out" ];
          inherit
            originalOutputs
            aliases
            binName
            filesToPatch
            filesToExclude
            patchHook
            ;
          passthru =
            (package.passthru or { })
            // passthru
            // {
              inherit
                env
                flags
                args
                preHook
                postHook
                aliases
                ;
              override = overrideArgs: wrapPackage (funcArgs // { package = package.override overrideArgs; });
            };
          meta = (package.meta or { }) // lib.optionalAttrs (binName != null) { mainProgram = binName; };
        }
        // lib.optionalAttrs (package ? version) { inherit (package) version; }
        // lib.optionalAttrs (package ? pname) { inherit (package) pname; }
      );
    in
    wrappedPackage;
  wrapperLib = {
    inherit
      types
      modules
      style
      wrapModule
      wrapPackage
      applyStyle
      escapeShellArgWithEnv
      generateArgsFromFlags
      flagToArgs
      ;
  };
in
wrapperLib
