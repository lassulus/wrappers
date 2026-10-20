{
  config,
  lib,
  wlib,
  ...
}:
let
  cfg = config.styling;

  # Used when styling is enabled without a scheme, so that reading a colour
  # never throws. Programs styled with this alone still get a coherent theme.
  fallbackScheme = "default-dark";

  scheme = wlib.style.resolveScheme config.pkgs (
    if cfg.scheme == null then fallbackScheme else cfg.scheme
  );

  /**
    Semantic names for the base16 slots, following the base16 styling
    guidelines. Modules should prefer these over raw slot numbers: reading
    `colors.background` says what a value means, `palette.base00` does not.
  */
  aliases = {
    background = "base00";
    backgroundAlt = "base01";
    selection = "base02";
    comment = "base03";
    foregroundAlt = "base04";
    foreground = "base05";
    foregroundBright = "base06";
    backgroundBright = "base07";

    red = "base08";
    orange = "base09";
    yellow = "base0A";
    green = "base0B";
    cyan = "base0C";
    blue = "base0D";
    magenta = "base0E";
    brown = "base0F";

    accent = "base0D";
    error = "base08";
    warning = "base0A";
    success = "base0B";
    info = "base0C";
  };

  /**
    The standard base16 mapping onto the 16 ANSI terminal colours. base16 has
    no distinct bright variants for the six hues, so those repeat; only the
    greys differ. Terminals are the main consumer, and deriving this once here
    keeps them from each inventing their own mapping.
  */
  ansiAliases = {
    black = "base00";
    red = "base08";
    green = "base0B";
    yellow = "base0A";
    blue = "base0D";
    magenta = "base0E";
    cyan = "base0C";
    white = "base05";

    brightBlack = "base03";
    brightRed = "base08";
    brightGreen = "base0B";
    brightYellow = "base0A";
    brightBlue = "base0D";
    brightMagenta = "base0E";
    brightCyan = "base0C";
    brightWhite = "base07";
  };

  mkFont = attr: fontName: {
    package = lib.mkOption {
      type = lib.types.package;
      default = config.pkgs.${attr};
      defaultText = lib.literalExpression "config.pkgs.${attr}";
      description = "Package providing the font.";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = fontName;
      description = "Family name of the font, as fontconfig reports it.";
    };
  };

  mkSize =
    default: what:
    lib.mkOption {
      type = lib.types.numbers.positive;
      inherit default;
      description = "Font size to use for ${what}.";
    };

  mkOpacity =
    what:
    lib.mkOption {
      type = lib.types.numbers.between 0.0 1.0;
      default = 1.0;
      description = "Opacity to use for ${what}, from 0.0 (transparent) to 1.0 (opaque).";
    };

  fontRoles = [
    "monospace"
    "sansSerif"
    "serif"
    "emoji"
  ];
in
{
  _file = "lib/modules/styling.nix";

  options.styling = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.scheme != null;
      defaultText = lib.literalExpression "config.styling.scheme != null";
      description = ''
        Whether this wrapper should style itself from `styling`.

        Defaults to true as soon as a scheme is set, so that setting one
        theme applies it everywhere. Set it to false on an individual wrapper
        to leave that program's own configuration alone.

        Modules that support styling must gate their generated settings on
        this option, and must define them with `lib.mkDefault` so that
        anything the user configured explicitly still wins.
      '';
    };

    scheme = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
      default = null;
      example = "gruvbox-dark-hard";
      description = ''
        The base16 colour scheme to derive `styling.palette` from.

        Accepts the name of a scheme in `pkgs.base16-schemes` or a path to a
        base16 YAML file.

        Individual colours are set through `styling.palette.<slot>`, which
        takes precedence over the scheme.
      '';
    };

    palette = lib.genAttrs wlib.style.slots (
      slot:
      lib.mkOption {
        type = lib.types.str;
        description = "The base16 `${slot}` colour, as lower case 6 digit hex without a `#` prefix.";
      }
    );

    colors = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.attrsOf lib.types.str));
      readOnly = true;
      default = lib.mapAttrs (_: slot: cfg.palette.${slot}) aliases // {
        ansi = lib.mapAttrs (_: slot: cfg.palette.${slot}) ansiAliases;
      };
      defaultText = lib.literalMD "semantic aliases for `styling.palette`, plus `colors.ansi`";
      description = ''
        The palette under semantic names, e.g. `colors.background` for
        `palette.base00`, plus `colors.ansi` holding the standard base16
        mapping onto the 16 ANSI terminal colours.
      '';
    };

    polarity = lib.mkOption {
      type = lib.types.enum [
        "light"
        "dark"
      ];
      default =
        if scheme.variant == "light" || scheme.variant == "dark" then
          scheme.variant
        else if wlib.style.isDark cfg.palette.base00 then
          "dark"
        else
          "light";
      defaultText = lib.literalMD "the scheme's `variant`, or derived from the brightness of `base00`";
      description = ''
        Whether the theme is light or dark. Programs that ship separate light
        and dark variants can select between them with this.
      '';
    };

    fonts = {
      monospace = mkFont "dejavu_fonts" "DejaVu Sans Mono";
      sansSerif = mkFont "dejavu_fonts" "DejaVu Sans";
      serif = mkFont "dejavu_fonts" "DejaVu Serif";
      emoji = mkFont "noto-fonts-color-emoji" "Noto Color Emoji";

      sizes = {
        applications = mkSize 12 "regular application windows";
        terminal = mkSize 12 "terminal emulators";
        desktop = mkSize 10 "bars, docks and other desktop chrome";
        popups = mkSize 10 "notifications, launchers and other popups";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        readOnly = true;
        default = lib.unique (map (role: cfg.fonts.${role}.package) fontRoles);
        defaultText = lib.literalMD "the packages of the configured fonts, deduplicated";
        description = "The packages providing the configured fonts, deduplicated.";
      };

      provideFontconfig = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to point the wrapped program at a generated fontconfig
          configuration covering `styling.fonts.packages`, via
          `FONTCONFIG_FILE`.

          Off by default: a wrapper normally wants to see the fonts installed
          on the system it runs on. Turn this on when a wrapper has to be
          self-contained.
        '';
      };
    };

    opacity = {
      applications = mkOpacity "regular application windows";
      terminal = mkOpacity "terminal emulators";
      desktop = mkOpacity "bars, docks and other desktop chrome";
      popups = mkOpacity "notifications, launchers and other popups";
    };

    cursor = {
      package = lib.mkOption {
        type = lib.types.package;
        default = config.pkgs.adwaita-icon-theme;
        defaultText = lib.literalExpression "config.pkgs.adwaita-icon-theme";
        description = "Package providing the cursor theme.";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "Adwaita";
        description = "Name of the cursor theme.";
      };
      size = lib.mkOption {
        type = lib.types.ints.positive;
        default = 24;
        description = "Cursor size in pixels.";
      };
    };
  };

  # The scheme seeds the palette at the same priority as an option default, so
  # that setting styling.palette.<slot> directly overrides it.
  #
  # The keys come from the static slot list rather than from the parsed scheme:
  # the module system forces the key set of every definition while checking for
  # unmatched definitions, which would resolve the scheme (and so read
  # config.pkgs) even for wrappers that never look at a colour.
  config.styling.palette = lib.genAttrs wlib.style.slots (
    slot: lib.mkOptionDefault scheme.palette.${slot}
  );

  config.env.FONTCONFIG_FILE = lib.mkIf (cfg.enable && cfg.fonts.provideFontconfig) (
    lib.mkDefault "${config.pkgs.makeFontsConf { fontDirectories = cfg.fonts.packages; }}"
  );
}
