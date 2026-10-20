{
  config,
  lib,
  wlib,
  ...
}:
let
  tomlFmt = config.pkgs.formats.toml { };
in
{
  _class = "wrapper";
  imports = [ ./styling.nix ];
  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Configuration of alacritty.
        See {manpage}`alacritty(5)` or <https://alacritty.org/config-alacritty.html>
      '';
    };
    "alacritty.toml" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      # TODO add a pure toTOML function
      default.path = tomlFmt.generate "alacritty.toml" config.settings;
      description = "alacritty.toml configuration file.";
    };
  };
  config.flags = {
    "--config-file" = config."alacritty.toml".path;
  };
  config.package = config.pkgs.alacritty;
  config.meta.maintainers = [ lib.maintainers.zimward ];
}
