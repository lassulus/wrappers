{
  pkgs,
  self,
}:
let
  yaziWrapped =
    (self.wrapperModules.yazi.apply {
      inherit pkgs;
    }).wrapper;
in
pkgs.runCommand "yazi-test" { } ''
  "${yaziWrapped}/bin/yazi" --version | grep -q "${yaziWrapped.version}"
  touch $out
''
