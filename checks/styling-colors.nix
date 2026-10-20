{
  pkgs,
  self,
}:

let
  inherit (pkgs) lib;
  inherit (self.lib) style;

  # A palette where every slot holds a distinct, recognisable value, so that an
  # alias pointing at the wrong slot cannot pass unnoticed.
  probe = lib.listToAttrs (
    lib.imap0 (
      index: slot:
      lib.nameValuePair slot "0000${lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString index))}"
    ) style.slots
  );

  cfg =
    (self.lib.wrapModule (
      { config, ... }:
      {
        config.package = config.pkgs.hello;
      }
    )).apply
      {
        inherit pkgs;
        styling.palette = probe;
      };

  colors = cfg.styling.colors;

  expected = {
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

  expectedAnsi = {
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

  # Each alias must resolve to the value sitting in the slot it claims.
  wrongAliases = lib.attrNames (
    lib.filterAttrs (alias: slot: colors.${alias} != probe.${slot}) expected
  );

  wrongAnsi = lib.attrNames (
    lib.filterAttrs (alias: slot: colors.ansi.${alias} != probe.${slot}) expectedAnsi
  );
in
pkgs.runCommand "styling-colors-test" { } ''
  fail=0
  expect() {
    if [[ "$2" != "$3" ]]; then
      echo "FAIL: $1: expected '$3', got '$2'"
      fail=1
    fi
  }

  echo "Testing styling colour aliases and helpers..."

  expect "semantic aliases" '${builtins.toJSON wrongAliases}' '[]'
  expect "ansi aliases" '${builtins.toJSON wrongAnsi}' '[]'
  expect "alias count" '${toString (builtins.length (builtins.attrNames expected))}' '21'
  expect "ansi count" '${toString (builtins.length (builtins.attrNames colors.ansi))}' '16'

  # Colours are stored bare, so that each consumer can pick its own form
  expect "stored bare" '${colors.background}' '000000'

  expect "withHash" '${style.withHash "1d2021"}' '#1d2021'
  expect "rgbCss" '${style.rgbCss "1d2021"}' 'rgb(29, 32, 33)'
  expect "rgbaCss" '${style.rgbaCss "1d2021" 0.9}' 'rgba(29, 32, 33, 0.9)'
  expect "rgbaCss opaque" '${style.rgbaCss "1d2021" 1.0}' 'rgba(29, 32, 33, 1)'

  expect "toRGB" '${builtins.toJSON (style.toRGB "1d2021")}' '${
    builtins.toJSON {
      r = 29;
      g = 32;
      b = 33;
    }
  }'
  expect "toRGB white" '${builtins.toJSON (style.toRGB "ffffff")}' '${
    builtins.toJSON {
      r = 255;
      g = 255;
      b = 255;
    }
  }'

  expect "withAlpha" '${style.withAlpha "1d2021" 0.9}' '1d2021e6'
  expect "withAlpha opaque" '${style.withAlpha "1d2021" 1.0}' '1d2021ff'
  expect "withAlpha transparent" '${style.withAlpha "1d2021" 0.0}' '1d202100'
  # A small alpha still has to produce two hex digits
  expect "withAlpha pads" '${style.withAlpha "1d2021" 0.02}' '1d202105'

  expect "formatNumber" '${style.formatNumber 0.9}' '0.9'
  expect "formatNumber whole" '${style.formatNumber 1.0}' '1'

  expect "isDark dark" '${lib.boolToString (style.isDark "1d2021")}' 'true'
  expect "isDark light" '${lib.boolToString (style.isDark "fbf1c7")}' 'false'

  [[ $fail -eq 0 ]] || exit 1
  echo "SUCCESS: styling colours test passed"
  touch $out
''
