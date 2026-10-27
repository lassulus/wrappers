{
  config,
  lib,
  wlib,
  ...
}:
let
  yamlFmt = config.pkgs.formats.yaml { };
in
{
  _class = "wrapper";
  options = {
    processConfig = lib.mkOption {
      inherit (yamlFmt) type;
      default = {
        version = "0.5";
        is_strict = true;
        shell = {
          shell_command = lib.getExe config.pkgs.bash;
          shell_argument = "-c";
        };
      };
      description = "See <https://f1bonacc1.github.io/process-compose/configuration/>";
      example = {
        version = "0.5";
        processes = {
          process1 = {
            command = "sleep 3";
            depends_on = {
              process2 = {
                condition = "process_completed_successfully"; # or "process_completed" if you don't care about errors
              };
            };
          };
          process2 = {
            command = "sleep 3";
          };
        };
      };
    };
  };
  config = {
    package = lib.mkDefault config.pkgs.process-compose;
    env = {
      PC_CONFIG_FILES = "${yamlFmt.generate "config.yml" config.processConfig}";
    };
    meta.maintainers = [ lib.maintainers.RTUnreal ];
  };
  config.flagSeparator = "=";
}
