{
  wlib,
  lib,
  config,
  ...
}:
let
  tomlFmt = config.pkgs.formats.toml { };
in
{
  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        General settings.
        See <https://yazi-rs.github.io/docs/configuration/yazi>
      '';
    };

    keymap = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Keymap settings.
        See <https://yazi-rs.github.io/docs/configuration/keymap>
      '';
    };

    theme = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Theming.
        See <https://yazi-rs.github.io/docs/configuration/theme>
      '';
    };

    "yazi.toml" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = tomlFmt.generate "yazi.toml" config.settings;
    };
    "keymap.toml" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = tomlFmt.generate "keymap.toml" config.keymap;
    };
    "theme.toml" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = tomlFmt.generate "theme.toml" config.theme;
    };

    extraFiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.nonEmptyStr;
              description = "File name in the config directory";
            };
            file = lib.mkOption {
              type = wlib.types.file config.pkgs;
              description = "File or path to add into the config directory";
            };
          };
        }
      );
      default = [ ];
      description = "Additional files to be placed in the config directory";
    };
  };

  config = {
    package = lib.mkDefault config.pkgs.yazi;
    env.YAZI_CONFIG_HOME = toString (
      config.pkgs.linkFarm "yazi-merged-config" (
        let
          entry = name: path: { inherit name path; };
        in
        [
          (entry "yazi.toml" config."yazi.toml".path)
          (entry "keymap.toml" config."keymap.toml".path)
          (entry "theme.toml" config."theme.toml".path)
        ]
        ++ (map (f: {
          inherit (f) name;
          path = f.file.path;
        }) config.extraFiles)
      )
    );
    meta.maintainers = [
      {
        name = "holly";
        github = "hollymlem";
        githubId = 35699052;
      }
    ];
  };
}
