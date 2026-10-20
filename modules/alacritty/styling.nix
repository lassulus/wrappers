{
  config,
  lib,
  wlib,
  ...
}:
let
  inherit (config) styling;
  inherit (wlib.style) withHash;

  ansiNames = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];

  upperFirst =
    string:
    lib.toUpper (builtins.substring 0 1 string)
    + builtins.substring 1 (builtins.stringLength string) string;

  # alacritty's normal and bright blocks are exactly the 16 ANSI colours, which
  # styling.colors.ansi already provides in the standard base16 mapping.
  ansiBlock = pick: lib.genAttrs ansiNames (name: withHash styling.colors.ansi.${pick name});
in
{
  _class = "wrapper";

  config.settings = lib.mkIf styling.enable (
    wlib.style.mkDefaults {
      colors = {
        primary = {
          background = withHash styling.colors.background;
          foreground = withHash styling.colors.foreground;
          bright_foreground = withHash styling.colors.ansi.brightWhite;
        };
        selection = {
          background = withHash styling.colors.selection;
          text = withHash styling.colors.foreground;
        };
        cursor = {
          cursor = withHash styling.colors.foreground;
          text = withHash styling.colors.background;
        };
        normal = ansiBlock (name: name);
        bright = ansiBlock (name: "bright${upperFirst name}");
      };

      font = {
        normal = {
          family = styling.fonts.monospace.name;
          style = "Regular";
        };
        size = styling.fonts.sizes.terminal;
      };

      window.opacity = styling.opacity.terminal;
    }
  );
}
