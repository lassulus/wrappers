{
  pkgs,
  self,
}:

let
  inherit (pkgs) lib;

  # Stands in for a wrapper module that has grown styling support, following
  # the pattern documented in the README: gate on styling.enable, and define
  # every derived value as a default so the user still wins.
  themed = self.lib.wrapModule (
    {
      config,
      lib,
      wlib,
      ...
    }:
    {
      options.settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };

      config.package = config.pkgs.hello;
      config.settings = lib.mkIf config.styling.enable (
        wlib.style.mkDefaults {
          background = wlib.style.withHash config.styling.colors.background;
          foreground = wlib.style.withHash config.styling.colors.foreground;
        }
      );
    }
  );

  unstyled = themed.apply { inherit pkgs; };
  scheme = themed.apply {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
  };
  optedOut = themed.apply {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
    styling.enable = false;
  };
  userOverride = themed.apply {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
    settings.background = "#000000";
  };
  fontsOnly = themed.apply {
    inherit pkgs;
    styling.enable = true;
  };
  fontconfig = themed.apply {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
    styling.fonts.provideFontconfig = true;
  };
in
pkgs.runCommand "styling-enable-test" { } ''
  fail=0
  expect() {
    if [[ "$2" != "$3" ]]; then
      echo "FAIL: $1: expected '$3', got '$2'"
      fail=1
    fi
  }

  echo "Testing styling enablement and priority..."

  # Without a scheme, styling is inert: existing wrappers are unaffected
  expect "off by default" '${lib.boolToString unstyled.styling.enable}' 'false'
  expect "no settings when off" '${builtins.toJSON unstyled.settings}' '{}'

  # Setting a scheme turns styling on everywhere, without a per-module opt-in
  expect "on with a scheme" '${lib.boolToString scheme.styling.enable}' 'true'
  expect "styles background" '${scheme.settings.background}' '#1d2021'
  expect "styles foreground" '${scheme.settings.foreground}' '#d5c4a1'

  # A single wrapper can opt out again
  expect "opt out" '${lib.boolToString optedOut.styling.enable}' 'false'
  expect "no settings when opted out" '${builtins.toJSON optedOut.settings}' '{}'

  # THE contract every styled module depends on: styling defines defaults, so
  # anything the user set explicitly wins.
  expect "user beats styling" '${userOverride.settings.background}' '#000000'
  expect "user override is narrow" '${userOverride.settings.foreground}' '#d5c4a1'

  # Enabling styling without a scheme still yields a usable palette rather
  # than an error, so fonts alone can be themed
  expect "fallback palette" '${fontsOnly.settings.background}' '#181818'
  expect "fallback polarity" '${fontsOnly.styling.polarity}' 'dark'

  # Fonts are not wired into the environment unless asked for
  expect "no fontconfig by default" '${lib.boolToString (scheme.env ? FONTCONFIG_FILE)}' 'false'
  expect "fontconfig when asked" '${lib.boolToString (fontconfig.env ? FONTCONFIG_FILE)}' 'true'

  if ! grep -q '${pkgs.dejavu_fonts}' '${fontconfig.env.FONTCONFIG_FILE or "/dev/null"}'; then
    echo "FAIL: generated fontconfig should reference the configured font packages"
    fail=1
  fi

  [[ $fail -eq 0 ]] || exit 1
  echo "SUCCESS: styling enable test passed"
  touch $out
''
