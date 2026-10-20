{
  pkgs,
  self,
}:

# `ifUnset`: only apply when the caller's env doesn't have the
# variable set (or has it empty).
let
  wlib = self.lib;

  showEnv = pkgs.writeShellScriptBin "show-env" ''
    printf 'EDITOR=%s\n' "''${EDITOR-<unset>}"
  '';

  wrapped =
    (wlib.wrapModule (
      { config, ... }:
      {
        config.package = showEnv;
        config.env.EDITOR = {
          value = "vim";
          ifUnset = true;
        };
      }
    ).apply { pkgs = pkgs; }).wrapper;
in
pkgs.runCommand "env-if-unset-test" { } ''
  set -eu
  script="${wrapped}/bin/show-env"

  # ifUnset applies when EDITOR is unset.
  r=$(unset EDITOR && "$script" | grep '^EDITOR=' | cut -d= -f2-)
  [ "$r" = "vim" ] || { echo "FAIL: ifUnset unset: '$r'"; cat "$script"; exit 1; }
  echo "PASS: ifUnset applies when unset"

  # ifUnset yields to an existing value.
  r=$(EDITOR=nano "$script" | grep '^EDITOR=' | cut -d= -f2-)
  [ "$r" = "nano" ] || { echo "FAIL: ifUnset overrode existing: '$r'"; exit 1; }
  echo "PASS: ifUnset preserves existing"

  # Empty counts as unset.
  r=$(EDITOR="" "$script" | grep '^EDITOR=' | cut -d= -f2-)
  [ "$r" = "vim" ] || { echo "FAIL: ifUnset empty: '$r'"; exit 1; }
  echo "PASS: ifUnset treats empty as unset"

  touch $out
''
