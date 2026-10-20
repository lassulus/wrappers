{
  pkgs,
  self,
}:

let
  inherit (pkgs) lib;

  styled =
    styling:
    (self.lib.wrapModule (
      { config, ... }:
      {
        config.package = config.pkgs.hello;
      }
    )).apply
      { inherit pkgs styling; };

  # A scheme held in a derivation, with no `variant` to read.
  inlineFile = pkgs.writeText "inline-scheme.yaml" ''
    name: "Inline"
    palette:
      base00: "#eeeeee"
      base01: "#222222"
      base02: "#333333"
      base03: "#444444"
      base04: "#555555"
      base05: "#666666"
      base06: "#777777"
      base07: "#888888"
      base08: "#999999"
      base09: "#aaaaaa"
      base0A: "#bbbbbb"
      base0B: "#cccccc"
      base0C: "#dddddd"
      base0D: "#eeeeee"
      base0E: "#ffffff"
      base0F: "#000000"
  '';

  byName = styled { scheme = "gruvbox-dark-hard"; };
  byDerivation = styled { scheme = inlineFile; };
  byPathString = styled { scheme = "${pkgs.base16-schemes}/share/themes/default-light.yaml"; };

  overridden = styled {
    scheme = "gruvbox-dark-hard";
    palette.base0D = "abcdef";
  };

  incomplete = styled {
    scheme = pkgs.writeText "incomplete-scheme.yaml" ''
      palette:
        base00: "#111111"
    '';
  };
  missingSlots = builtins.tryEval incomplete.styling.palette.base00;

  parsedGruvbox = self.lib.style.parseScheme (
    builtins.readFile "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml"
  );

  # Every scheme shipped by nixpkgs must parse into a complete palette. This is
  # what justifies the hand written parser over importing from a derivation.
  themeDir = "${pkgs.base16-schemes}/share/themes";
  allSchemes = builtins.attrNames (builtins.readDir themeDir);
  unparsable = lib.filter (
    file:
    let
      palette = (self.lib.style.parseScheme (builtins.readFile "${themeDir}/${file}")).palette;
    in
    lib.any (slot: !(palette ? ${slot})) self.lib.style.slots
  ) allSchemes;
in
pkgs.runCommand "styling-scheme-test" { } ''
  fail=0
  expect() {
    if [[ "$2" != "$3" ]]; then
      echo "FAIL: $1: expected '$3', got '$2'"
      fail=1
    fi
  }

  echo "Testing styling scheme resolution..."

  # By name, from pkgs.base16-schemes
  expect "by name base00" '${byName.styling.palette.base00}' '1d2021'
  expect "by name base0A" '${byName.styling.palette.base0A}' 'fabd2f'
  expect "by name polarity" '${byName.styling.polarity}' 'dark'

  # Scheme metadata is picked up alongside the palette
  expect "parsed variant" '${parsedGruvbox.variant}' 'dark'

  # A derivation holding a scheme
  expect "by derivation base00" '${byDerivation.styling.palette.base00}' 'eeeeee'
  expect "by derivation base0A" '${byDerivation.styling.palette.base0A}' 'bbbbbb'

  # A store path passed as a string
  expect "by path string base00" '${byPathString.styling.palette.base00}' 'f8f8f8'
  expect "by path string polarity" '${byPathString.styling.polarity}' 'light'

  # No variant to read, so polarity falls back to the brightness of base00
  expect "by derivation polarity" '${byDerivation.styling.polarity}' 'light'

  # An explicit palette entry outranks the scheme
  expect "override base0D" '${overridden.styling.palette.base0D}' 'abcdef'
  expect "override leaves others" '${overridden.styling.palette.base00}' '1d2021'

  # An incomplete scheme is rejected rather than silently yielding gaps
  expect "incomplete scheme fails" '${lib.boolToString missingSlots.success}' 'false'

  # The parser must handle every scheme nixpkgs ships
  expect "all ${toString (builtins.length allSchemes)} schemes parse" \
    '${builtins.toJSON unparsable}' '[]'

  [[ $fail -eq 0 ]] || exit 1
  echo "SUCCESS: styling scheme test passed"
  touch $out
''
