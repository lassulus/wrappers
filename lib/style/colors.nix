{ lib }:
let
  /**
    Colours are stored as lower case 6 digit hex without a prefix, because
    that is the one form every config format can be derived from. These
    helpers convert a stored colour into whatever shape a given program wants.
  */

  channel = color: offset: lib.fromHexString (builtins.substring offset 2 color);

  # lib.toHexString drops the leading zero, but a hex byte always needs two digits.
  toHexByte =
    n:
    let
      hex = lib.toLower (lib.toHexString n);
    in
    if builtins.stringLength hex < 2 then "0${hex}" else hex;

  # Clamp to [0, 1] and scale to a byte, rounding to nearest.
  toByte = fraction: builtins.floor (lib.min 1.0 (lib.max 0.0 (fraction * 1.0)) * 255 + 0.5);

  # `toString 0.9` yields "0.900000". Trim the padding so that generated CSS
  # reads the way someone would have written it by hand.
  trimFloat =
    value:
    let
      string = toString value;
      whole = builtins.match "(-?[0-9]+)\\.0*" string;
      fraction = builtins.match "(-?[0-9]+\\.[0-9]*[1-9])0*" string;
    in
    if whole != null then
      builtins.head whole
    else if fraction != null then
      builtins.head fraction
    else
      string;
in
rec {
  /**
    Prefix a colour with `#`, the form most config formats want.

    # Example

    ```nix
    withHash "1d2021"
    => "#1d2021"
    ```
  */
  withHash = color: "#${color}";

  /**
    Split a colour into its integer red, green and blue channels.

    # Example

    ```nix
    toRGB "1d2021"
    => { r = 29; g = 32; b = 33; }
    ```
  */
  toRGB = color: {
    r = channel color 0;
    g = channel color 2;
    b = channel color 4;
  };

  /**
    Render a colour as a CSS `rgb()` function, for the GTK stylesheets used by
    waybar, swaync, swayosd and anyrun.

    # Example

    ```nix
    rgbCss "1d2021"
    => "rgb(29, 32, 33)"
    ```
  */
  rgbCss =
    color:
    let
      rgb = toRGB color;
    in
    "rgb(${toString rgb.r}, ${toString rgb.g}, ${toString rgb.b})";

  /**
    Render a colour as a CSS `rgba()` function with the given alpha.

    # Example

    ```nix
    rgbaCss "1d2021" 0.9
    => "rgba(29, 32, 33, 0.9)"
    ```
  */
  rgbaCss =
    color: alpha:
    let
      rgb = toRGB color;
    in
    "rgba(${toString rgb.r}, ${toString rgb.g}, ${toString rgb.b}, ${trimFloat alpha})";

  /**
    Append an alpha channel as a hex byte, the form hyprland, kitty and several
    terminals use for translucency.

    # Example

    ```nix
    withAlpha "1d2021" 0.9
    => "1d2021e6"
    ```
  */
  withAlpha = color: alpha: "${color}${toHexByte (toByte alpha)}";

  /**
    Render a number without the padding `toString` adds to floats, for config
    formats that take a bare float such as an opacity.

    # Example

    ```nix
    formatNumber 0.9
    => "0.9"    # toString would give "0.900000"
    ```
  */
  formatNumber = trimFloat;

  /**
    Approximate relative brightness of a colour, in `[0, 1]`.

    This weights the gamma encoded channels rather than linearising them
    first, which Nix cannot do without a `pow` builtin. That is accurate
    enough for deciding whether a scheme is light or dark, which is all it is
    used for here.

    # Example

    ```nix
    luminance "1d2021"
    => 0.12...
    ```
  */
  luminance =
    color:
    let
      rgb = toRGB color;
    in
    (0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b) / 255;

  /**
    Whether a colour reads as dark. Used to derive `styling.polarity` for
    schemes that do not declare a `variant`.
  */
  isDark = color: luminance color < 0.5;

  /**
    Lower every leaf of an attrset to `lib.mkDefault`.

    Styling has to yield to anything the user set themselves, so every value a
    module derives from `styling` must be a default. This is sugar for the
    common case of a whole generated settings block.

    # Example

    ```nix
    config.settings = lib.mkIf config.styling.enable (
      wlib.style.mkDefaults {
        colors.primary.background = wlib.style.withHash c.background;
      }
    );
    ```
  */
  mkDefaults = lib.mapAttrsRecursive (_: lib.mkDefault);
}
