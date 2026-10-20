{
  pkgs,
  self,
}:

# End-to-end test for list-valued `env.<VAR>.value` with
# `wlib.env.ref` to prepend to an existing variable. Also exercises
# composition via `apply`: lists merge by concatenation.
let
  wlib = self.lib;

  showVar = pkgs.writeShellScriptBin "show-var" ''
    printf 'TEST_VAR=%s\n' "''${TEST_VAR-<unset>}"
  '';

  base = wlib.wrapModule (
    { config, ... }:
    {
      config.package = showVar;
      config.env.TEST_VAR.value = [
        "/base-front"
        (wlib.env.ref "TEST_VAR")
        "/base-back"
      ];
    }
  );

  extended = (base.apply { pkgs = pkgs; }).apply {
    # List merging via the module system: apply concatenates.
    env.TEST_VAR.value = [ "/extra" ];
  };

  wrapped = extended.wrapper;
in
pkgs.runCommand "env-list-value-test" { } ''
  set -eu
  script="${wrapped}/bin/show-var"

  # Case 1: TEST_VAR unset — envRef drops out, no stray colons.
  r1=$(unset TEST_VAR && "$script" | grep '^TEST_VAR=' | cut -d= -f2-)
  case "$r1" in
    *::*)
      echo "FAIL: unset case has stray separator: '$r1'"
      cat "$script"; exit 1 ;;
    :*|*:)
      echo "FAIL: unset case has leading/trailing colon: '$r1'" ; exit 1 ;;
  esac
  case "$r1" in
    */base-front*) ;;
    *) echo "FAIL: base-front missing: '$r1'"; exit 1 ;;
  esac
  case "$r1" in
    */base-back*) ;;
    *) echo "FAIL: base-back missing: '$r1'"; exit 1 ;;
  esac
  case "$r1" in
    */extra*) ;;
    *) echo "FAIL: extra missing (list merge via apply): '$r1'"; exit 1 ;;
  esac
  echo "PASS: unset case: $r1"

  # Case 2: TEST_VAR=/mid — envRef expands in place.
  r2=$(TEST_VAR=/mid "$script" | grep '^TEST_VAR=' | cut -d= -f2-)
  case "$r2" in
    */mid*) ;;
    *) echo "FAIL: existing value lost: '$r2'"; exit 1 ;;
  esac
  echo "PASS: set case: $r2"

  touch $out
''
