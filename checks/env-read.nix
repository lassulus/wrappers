{
  pkgs,
  self,
}:

# Verify that `env.<VAR>.value` is always a list when read from
# another wrapper's config, regardless of whether the user wrote
# the input as a string or a list. This is the invariant that lets
# consumers inspect env entries without safeguarding against two
# types.
let
  lib = pkgs.lib;
  wlib = self.lib;

  producer = wlib.wrapModule (
    { config, ... }:
    {
      config.package = pkgs.hello;
      # Plain string input.
      config.env.EDITOR = "vim";
      # Already-a-list input.
      config.env.PATH.value = [
        "/opt/bin"
        (wlib.env.ref "PATH")
      ];
    }
  );

  applied = producer.apply { inherit pkgs; };

  editorValue = applied.env.EDITOR.value;
  pathValue = applied.env.PATH.value;

  # Literal read helper: joins the parts with separator. Works as
  # long as all parts are plain strings (no envRefs).
  readLiteral = e: lib.concatStringsSep e.separator e.value;

  editorString = readLiteral applied.env.EDITOR;

  checks = [
    (
      if builtins.isList editorValue then
        "PASS: string input is a list when read back"
      else
        throw "FAIL: editor value is ${builtins.typeOf editorValue}, expected list"
    )
    (
      if editorValue == [ "vim" ] then
        "PASS: string coerced to singleton [ \"vim\" ]"
      else
        throw "FAIL: editor value = ${builtins.toJSON editorValue}"
    )
    (
      if editorString == "vim" then
        "PASS: readLiteral round-trips the string"
      else
        throw "FAIL: readLiteral gave ${editorString}"
    )
    (
      if builtins.isList pathValue && lib.length pathValue == 2 then
        "PASS: list input preserved as list"
      else
        throw "FAIL: path value = ${builtins.toJSON pathValue}"
    )
    (
      if builtins.isString (lib.head pathValue) then
        "PASS: string parts stay strings"
      else
        throw "FAIL: path first part = ${builtins.toJSON (lib.head pathValue)}"
    )
    (
      let
        second = lib.elemAt pathValue 1;
      in
      if builtins.isAttrs second && second._type or null == "envRef" && second.name == "PATH" then
        "PASS: envRef round-trips"
      else
        throw "FAIL: path second part = ${builtins.toJSON second}"
    )
  ];
in
pkgs.runCommand "env-read-test" { } ''
  cat <<'EOF'
  ${lib.concatStringsSep "\n" checks}
  EOF
  touch $out
''
