{
  pkgs,
  self,
}:

# Pure tests for `wlib.env.render`. No wrapper build, just string
# comparison so iteration on escaping stays fast.
let
  lib = pkgs.lib;
  wlib = self.lib;

  cases = [
    {
      name = "empty";
      input = { };
      expected = "";
    }
    {
      name = "literal";
      input.FOO = "bar";
      expected = ''
        export FOO="bar"
      '';
    }
    {
      name = "if-unset";
      input.EDITOR = {
        value = "vim";
        ifUnset = true;
      };
      expected = ''
        if [ -z "''${EDITOR:-}" ]; then
          export EDITOR="vim"
        fi
      '';
    }
    {
      name = "escaped";
      input.MSG = ''He said "hi" and went \home'';
      expected = ''
        export MSG="He said \"hi\" and went \\home"
      '';
    }
  ];

  run =
    { name, input, expected }:
    let
      actual = wlib.env.render input;
    in
    if actual == expected then
      "PASS: ${name}"
    else
      throw ''
        FAIL: ${name}
        expected: ${builtins.toJSON expected}
        actual:   ${builtins.toJSON actual}
      '';

  results = map run cases;

  # Structural checks for list values: the join helper and all
  # literal parts must show up somewhere in the rendered snippet.
  listOut = wlib.env.render {
    PATH.value = [
      "/opt/bin"
      (wlib.env.ref "PATH")
      "/extra/bin"
    ];
  };
  listAssert =
    if
      lib.hasInfix "_wrapper_env_join" listOut
      && lib.hasInfix ''"/opt/bin"'' listOut
      && lib.hasInfix ''"''${PATH-}"'' listOut
      && lib.hasInfix ''"/extra/bin"'' listOut
    then
      "PASS: list-value renders helper + literals + envRef"
    else
      throw "FAIL: list-value rendering:\n${listOut}";

  all = results ++ [ listAssert ];
in
pkgs.runCommand "env-render-test" { } ''
  cat <<'EOF'
  ${lib.concatStringsSep "\n" all}
  EOF
  touch $out
''
