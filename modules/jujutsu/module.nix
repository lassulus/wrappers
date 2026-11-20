{ config, lib, ... }:

let
  tomlFmt = config.pkgs.formats.toml { };
in
{
  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      description = ''
        Configuration for jujutsu.
        See <https://jj-vcs.github.io/jj/latest/config/>
      '';
    };
    extraFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        A list of paths to include after the main config generated
        from the 'settings' option. This can be a list of paths to TOML files
        or directories of TOML files, which will be loaded in lexicographic
        order and merged.

        See <https://docs.jj-vcs.dev/latest/config/#user-config-files>
      '';
    };
  };

  config = {
    package = config.pkgs.jujutsu;
    env = {
      JJ_CONFIG = builtins.concatStringsSep ":" (
        lib.singleton (toString (tomlFmt.generate "jujutsu.toml" config.settings)) ++ config.extraFiles
      );
    };

    meta = {
      maintainers = [ lib.maintainers.dav-wolff ];
    };
  };
}
