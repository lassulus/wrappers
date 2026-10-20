{ config, lib, ... }:
let
  cfg = config.systemd;
  pkgs = config.pkgs;

  serviceName = config.binName;

  # Import the systemd unit generation helpers directly from nixpkgs.
  systemdLib = import (pkgs.path + "/nixos/lib/systemd-lib.nix") {
    inherit lib pkgs;
    config.systemd = {
      globalEnvironment = { };
      enableStrictShellChecks = true;
      package = pkgs.systemd;
    };
    utils = { };
  };

  unitOptions = import (pkgs.path + "/nixos/lib/systemd-unit-options.nix") {
    inherit lib;
    systemdUtils.lib = systemdLib;
  };

  # Evaluate a single service using the same submodule composition as
  # NixOS (stage2ServiceOptions + unitConfig + stage2ServiceConfig).
  svcEval = lib.evalModules {
    modules = [
      unitOptions.stage2ServiceOptions
      systemdLib.unitConfig
      systemdLib.stage2ServiceConfig
      { _module.args.name = serviceName; }
      { config = cfg; }
    ];
  };

  svc = svcEval.config;

  hasTimer = cfg ? startAt && cfg.startAt != [ ] && cfg.startAt != "";

  timerEval = lib.evalModules {
    modules = [
      unitOptions.stage2TimerOptions
      systemdLib.unitConfig
      systemdLib.timerConfig
      { _module.args.name = serviceName; }
      {
        config = {
          wantedBy = [ "timers.target" ];
          timerConfig.OnCalendar = cfg.startAt;
        };
      }
    ];
  };

  timer = timerEval.config;

  mkOutput =
    type:
    let
      unitDir = if type == "user" then "lib/systemd/user" else "lib/systemd/system";

      serviceFile = pkgs.writeTextDir "${unitDir}/${serviceName}.service" (systemdLib.serviceToUnit svc)
      .text;

      timerFile = pkgs.writeTextDir "${unitDir}/${serviceName}.timer" (systemdLib.timerToUnit timer).text;
    in
    if hasTimer then
      pkgs.symlinkJoin {
        name = "${serviceName}-${type}-units";
        paths = [
          serviceFile
          timerFile
        ];
      }
    else
      serviceFile;
in
{
  _file = "lib/modules/systemd.nix";

  options.systemd = lib.mkOption {
    type = lib.types.submodule { freeformType = with lib.types; attrsOf anything; };
    default = { };
    description = ''
      Systemd service configuration.
      Accepts the same options as systemd.services.<name> in NixOS.

      ExecStart, Environment, PATH, preStart and postStop are set from the
      wrapper by default. If startAt is set, a .timer unit is included in
      the output.
    '';
  };

  config.systemd = {
    enableDefaultPath = lib.mkDefault false;
    serviceConfig.ExecStart = lib.mkDefault (
      let
        # Systemd parses ExecStart using its own unquoting rules: bare
        # words are split on whitespace, double-quoted strings preserve
        # spaces. Backslash and double-quote inside a quoted word must
        # be escaped with a backslash.
        escapeForSystemd =
          s:
          let
            escaped = lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s;
          in
          if lib.hasInfix " " s || lib.hasInfix "\t" s || lib.hasInfix "\"" s then
            "\"${escaped}\""
          else
            escaped;
      in
      lib.concatStringsSep " " ([ config.exePath ] ++ map escapeForSystemd config.args)
    );
    environment = lib.mkDefault config.outputs.staticEnv;
    path = lib.mkDefault config.extraPackages;
    preStart = lib.mkIf (config.preHook != "") (lib.mkDefault config.preHook);
    postStop = lib.mkIf (config.postHook != "") (lib.mkDefault config.postHook);
  };

  options.outputs.systemd-user = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "The generated systemd user unit files.";
    default = mkOutput "user";
  };

  options.outputs.systemd-system = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "The generated systemd system unit files.";
    default = mkOutput "system";
  };
}
