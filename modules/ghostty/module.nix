{
  config,
  lib,
  wlib,
  ...
}:
let
  kvFmt = config.pkgs.formats.keyValue { listsAsDuplicateKeys = true; };
in
{
  _class = "wrapper";
  options = {
    settings = lib.mkOption {
      type = kvFmt.type;
      default = { };
      example = {
        cursor-color = "ffffff";
        cursor-text = "000000";
        background = "272822";
        foreground = "ffffff";
        palette = [
          "0=#272822"
          "1=#F92672"
          "2=#82B414"
          "3=#FD971F"
          "4=#268BD2"
          "5=#8C54FE"
          "6=#56C2D5"
          "7=#FFFFFF"

          "8=#5C5C5C"
          "9=#FF5995"
          "10=#A6E22E"
          "11=#E6DB74"
          "12=#62ADE3"
          "13=#AE81FF"
          "14=#66D9EF"
          "15=#CCCCCC"
        ];
      };
      description = ''
        Configuration of ghostty.
        See {manpage}`ghostty(5)` or <https://ghostty.org/docs/config/reference>
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = kvFmt.generate "ghostty-config" config.settings;
      description = ''
        Configuration of ghostty.
        See {manpage}`ghostty(5)` or <https://ghostty.org/docs/config/reference>
      '';
    };
  };
  config = {
    filesToPatch = [
      "share/dbus-1/services/com.mitchellh.ghostty.service"
      "share/systemd/user/app-com.mitchellh.ghostty.service"
    ];
    flagSeparator = "=";
    flags = {
      "--config-file" = config.configFile.path;
      "--config-default-files" = "false";
    };
    package = config.pkgs.ghostty;
    meta = {
      platforms = lib.platforms.linux;
      maintainers = [
        {
          name = "turbio";
          github = "turbio";
          githubId = 1428207;
        }
      ];
    };
  };
}
