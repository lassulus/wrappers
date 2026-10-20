{
  pkgs,
  self,
}:

let
  inherit (pkgs) lib;

  # One theme, defined once, mapped over several wrapper modules. This is the
  # whole point of applyStyle: wrapper modules are evaluated independently, so
  # without it a shared theme has to be repeated at every call site.
  themed = self.lib.applyStyle {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
    styling.fonts.monospace.name = "JetBrains Mono";
    styling.opacity.terminal = 0.9;
  } { inherit (self.wrapperModules) alacritty kitty btop; };

  # The results are ordinary configs, so a single program can still be refined
  # afterwards without losing the shared theme.
  refined = themed.alacritty.apply { styling.palette.base00 = "000000"; };

  names = lib.attrNames themed;

  differing = lib.filter (name: themed.${name}.styling.colors.background != "1d2021") names;

  # A wrapper built without any styling must be unchanged by all of this.
  before = (self.wrapperModules.btop.apply { inherit pkgs; }).wrapper;
in
pkgs.runCommand "styling-apply-test" { } ''
  fail=0
  expect() {
    if [[ "$2" != "$3" ]]; then
      echo "FAIL: $1: expected '$3', got '$2'"
      fail=1
    fi
  }

  echo "Testing applyStyle..."

  expect "applies to every module" '${builtins.toJSON names}' '${
    builtins.toJSON [
      "alacritty"
      "btop"
      "kitty"
    ]
  }'
  expect "shares one palette" '${builtins.toJSON differing}' '[]'
  expect "shares fonts" '${themed.kitty.styling.fonts.monospace.name}' 'JetBrains Mono'
  expect "shares opacity" '${toString themed.alacritty.styling.opacity.terminal}' '0.900000'
  expect "enabled everywhere" '${lib.boolToString themed.btop.styling.enable}' 'true'

  # Refining one program keeps the shared theme underneath
  expect "refined overrides" '${refined.styling.palette.base00}' '000000'
  expect "refined keeps the rest" '${refined.styling.palette.base05}' 'd5c4a1'
  expect "refined keeps the package" '${refined.package.pname}' 'alacritty'

  # Styling changes nothing until a module opts into consuming it, so an
  # unstyled wrapper still builds exactly as before
  test -x '${before}/bin/btop' || { echo "FAIL: unstyled wrapper is broken"; fail=1; }

  [[ $fail -eq 0 ]] || exit 1
  echo "SUCCESS: applyStyle test passed"
  touch $out
''
