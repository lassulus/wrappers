{
  pkgs,
  self,
}:

let
  inherit (pkgs) lib;

  plain = self.wrapperModules.alacritty.apply {
    inherit pkgs;
    settings.window.dynamic_title = false;
  };

  styled = self.wrapperModules.alacritty.apply {
    inherit pkgs;
    styling = {
      scheme = "gruvbox-dark-hard";
      fonts.monospace.name = "JetBrains Mono";
      fonts.sizes.terminal = 14;
      opacity.terminal = 0.9;
    };
  };

  # Styling yields to anything set explicitly, down to a single colour.
  overridden = styled.apply {
    settings.colors.primary.background = "#000000";
    settings.font.size = 20;
  };

  optedOut = self.wrapperModules.alacritty.apply {
    inherit pkgs;
    styling.scheme = "gruvbox-dark-hard";
    styling.enable = false;
  };

  # Asserting on the generated config rather than the built wrapper keeps this
  # check from pulling in alacritty itself.
  configOf = wrapper: wrapper."alacritty.toml".path;
in
pkgs.runCommand "alacritty-test" { } ''
  fail=0

  plain='${configOf plain}'
  styled='${configOf styled}'
  overridden='${configOf overridden}'
  optedOut='${configOf optedOut}'

  has() {
    if ! grep -qF "$2" "$1"; then
      echo "FAIL: $3"
      echo "--- $1"
      cat "$1"
      fail=1
    fi
  }
  hasNot() {
    if grep -qF "$2" "$1"; then
      echo "FAIL: $3"
      echo "--- $1"
      cat "$1"
      fail=1
    fi
  }

  echo "Testing alacritty configuration..."

  has "$plain" 'dynamic_title = false' "plain settings should reach the config"
  hasNot "$plain" '[colors' "an unstyled config should carry no colours"

  echo "Testing alacritty styling..."

  # Colours, from the gruvbox-dark-hard palette
  has "$styled" 'background = "#1d2021"' "primary background should be base00"
  has "$styled" 'foreground = "#d5c4a1"' "primary foreground should be base05"
  has "$styled" 'bright_foreground = "#fbf1c7"' "bright foreground should be base07"

  # normal and bright are the 16 ANSI colours; base16 has no separate bright
  # hues, so only the greys differ between the two blocks
  has "$styled" '[colors.normal]' "there should be a normal colour block"
  has "$styled" '[colors.bright]' "there should be a bright colour block"
  has "$styled" 'red = "#fb4934"' "ansi red should be base08"
  has "$styled" 'black = "#1d2021"' "normal black should be base00"
  has "$styled" 'black = "#665c54"' "bright black should be base03"

  # Selection and cursor
  has "$styled" 'text = "#d5c4a1"' "selection text should be base05"
  has "$styled" 'cursor = "#d5c4a1"' "cursor should be base05"

  # Fonts and opacity
  has "$styled" 'family = "JetBrains Mono"' "the monospace font should be used"
  has "$styled" 'style = "Regular"' "the font style should be set"
  has "$styled" 'size = 14' "the terminal font size should be used"
  has "$styled" 'opacity = 0.9' "the terminal opacity should be used"

  # Styling defines defaults, so explicit settings win
  has "$overridden" 'background = "#000000"' "an explicit background should win"
  has "$overridden" 'size = 20' "an explicit font size should win"
  has "$overridden" 'foreground = "#d5c4a1"' "overriding one value should keep the rest"

  # A wrapper can opt out even with a scheme set
  hasNot "$optedOut" '[colors' "an opted out config should carry no colours"

  [[ $fail -eq 0 ]] || exit 1
  echo "SUCCESS: alacritty test passed"
  touch $out
''
