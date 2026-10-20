{
  lib,
  wlib,
  config,
  ...
}:
{
  _file = "lib/modules/command.nix";
  imports = [
    wlib.modules.package
    wlib.modules.flags
    wlib.modules.env
  ];
  options.args = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Command-line arguments to pass to the wrapper (like argv in execve).
      This is a list of strings representing individual arguments.
      If not specified, will be automatically generated from flags.
    '';
  };
  options.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional packages to add to the wrapper's runtime dependencies.
      This is useful if the wrapped program needs additional libraries or tools to function correctly.
      These packages will be added to the wrapper's runtime dependencies, ensuring they are available when the wrapped program is executed.
    '';
  };
  options.preHook = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Shell script to run before executing the command.
      Multiple definitions are concatenated with newlines.
    '';
  };
  options.postHook = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Shell script to run after executing the command.
      Removes the `exec` call in the wrapper script which will leave a bash process
      in the background, therefore use with care.
      Multiple definitions are concatenated with newlines.
    '';
  };
  options.exePath = lib.mkOption {
    type = lib.types.path;
    description = ''
      Path to the executable within the package to be wrapped.
      If not specified, the main executable of the package will be used.
    '';
    default = lib.getExe config.package;
    defaultText = "lib.getExe config.package";
  };
  options.binName = lib.mkOption {
    type = lib.types.str;
    description = ''
      Name of the binary in the resulting wrapper package.
      If not specified, the base name of exePath will be used.
    '';
    default = builtins.baseNameOf config.exePath;
    defaultText = "builtins.baseNameOf config.exePath";
  };
}
