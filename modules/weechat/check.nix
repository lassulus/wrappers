{
  pkgs,
  self,
}:

let
  lib = pkgs.lib;
  weechatWrapped = self.wrapperModules.weechat.apply {
    scripts = [
      pkgs.weechatScripts.weechat-autosort
      pkgs.weechatScripts.colorize_nicks
    ];
    settings = {
      weechat = {
        look.mouse = true;
        color.chat_nick_colors = lib.lists.subtractLists (lib.range 52 69 ++ lib.range 231 248) (
          lib.range 31 254
        );
      };
      irc.look.color_nicks_in_nicklist = true;
      irc.server.libera = {
        autoconnect = true;
        addresses = "irc.libera.chat/6697";
        tls = true;
        autojoin = [ "#vim" ];
      };
    };
    extraCommands = ''
      /save
      /connect -all
    '';
    inherit pkgs;
  };
in
pkgs.runCommand "weechat-test" { } ''
  ${weechatWrapped.wrapper}/bin/weechat --version > $out
''
