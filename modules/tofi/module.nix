{
  config,
  wlib,
  lib,
  ...
}:
let
  inherit (lib.types)
    oneOf
    str
    int
    bool
    attrsOf
    ;

  renderSettings =
    settings:
    lib.generators.toINIWithGlobalSection { } {
      globalSection = settings;
    };

  primitive = (
    oneOf [
      str
      int
      bool
    ]
  );

  configType = attrsOf primitive;
in
{
  _class = "wrapper";
  options = {
    "config" = lib.mkOption {
      type = wlib.types.file config.pkgs;
    };

    settings = lib.mkOption {
      type = configType;
      default = { };
      description = "Configuration settings for tofi.";
    };
  };
  config."config".content = renderSettings config.settings;
  config.flags = {
    "--config" = config."config".path;
  };
  config.package = config.pkgs.tofi;
  config.wrapper =
    {
      envString,
      exePath,
      flagsString,
      ...
    }:
    ''
      ${envString}

      exec -a "$(basename "$0")" ${exePath}${flagsString} "$@"
    '';

  config.meta.maintainers = [
    lib.maintainers.randomdude
  ];
  config.meta.platforms = lib.platforms.linux;
}
