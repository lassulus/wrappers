{ wlib, lib, ... }:
wlib.wrapModule (
  { config, wlib, ... }:
  let
    jsonFormat = config.pkgs.formats.json { };
    weechatLib = rec {
      attrPaths =
        let
          recurse =
            path: value:
            if builtins.isAttrs value then
              lib.mapAttrsToList (name: recurse (path ++ [ name ])) value
            else
              [ (lib.nameValuePair path value) ];
        in
        attrs: lib.flatten (recurse [ ] attrs);

      attrPathsSep =
        sep: attrs:
        lib.listToAttrs (map (x: x // { name = lib.concatStringsSep sep x.name; }) (attrPaths attrs));

      toWeechatValue =
        x:
        {
          bool = builtins.toJSON x;
          string = x;
          list = lib.concatMapStringsSep "," toWeechatValue x;
          int = toString x;
        }
        .${builtins.typeOf x};

      setCommand = name: value: "/set ${name} \"${toWeechatValue value}\"";

      filterAddreplace =
        name: filter:
        "/filter addreplace ${name} ${filter.buffer} ${toWeechatValue filter.tags} ${filter.regex}";
    };
  in
  {
    meta.maintainers = [ lib.maintainers.kmein ];

    options = {
      scripts = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          List of WeeChat script packages to load. Scripts can be found in pkgs.weechatScripts.
        '';
      };
      files = lib.mkOption {
        type = lib.types.attrsOf (wlib.types.file config.pkgs);
        default = { };
        example = lib.literalExpression ''
          {
            "sec.conf".content = '''
              [crypt]
              cipher = aes256
              hash_algo = sha256
              passphrase_command = ""
              salt = on

              [data]
              __passphrase__ = off
              foo = "bar"
            ''';
          }
        '';
      };
      extraCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      settings = lib.mkOption {
        type = jsonFormat.type;
        default = { };
        description = ''
          Your WeeChat configuration in Nix-style syntax.
          Secrets can be defined with \''${my.secret.value}
        '';
        example = {
          irc.server_default.nicks = "rick_\\\${sec.data.foo}";
          irc.server_default.msg_part = "ciao kakao";
          irc.server_default.msg_quit = "tschö mit \\\${sec.data.foo}";
          irc.look.color_nicks_in_nicklist = true;
          matrix.server.nibbana = {
            addresses = "nibbana.jp";
          };
          irc.server.hackint = {
            addresses = "irc.hackint.org/6697";
            ssl = true;
            autoconnect = true;
            autojoin = [ "#krebs" ];
          };
          weechat.bar.buflist.hidden = true;
          irc.server.hackint.command = lib.concatStringsSep "\\;" [
            "/msg nickserv IDENTIFY \\\${sec.data.hackint_password}"
            "/msg nickserv SET CLOAK ON"
          ];
          filters.playlist_topic = {
            buffer = "irc.*.#the_playlist";
            tags = [ "irc_topic" ];
            regex = "*";
          };
          relay = {
            port.weechat = 9000;
            network.password = "hunter2";
          };
          alias.cmd.mod = "quote omode $channel +o $nick";
          secure.test.passphrase_command = "echo lol1234123124";
        };
      };
    };

    config =
      let
        setFile = config.pkgs.writeText "weechat.set" (
          lib.optionalString (config.settings != { }) (
            lib.concatStringsSep "\n" (
              lib.optionals (config.settings.irc or { } != { }) (
                lib.mapAttrsToList (
                  name: server: "/server add ${name} ${weechatLib.toWeechatValue server.addresses}"
                ) config.settings.irc.server
              )
              ++ lib.optionals (config.settings.matrix or { } != { }) (
                lib.mapAttrsToList (
                  name: server: "/matrix server add ${name} ${server.address}"
                ) config.settings.matrix.server
              )
              ++ lib.mapAttrsToList weechatLib.setCommand (weechatLib.attrPathsSep "." config.settings)
              ++ lib.optionals (config.settings.filters or { } != { }) (
                lib.mapAttrsToList weechatLib.filterAddreplace config.settings.filters
              )
              ++ lib.singleton config.extraCommands
            )
          )
        );
      in
      {
        flags = {
          "--dir" = config.pkgs.linkFarm "weechat-config-dir" (
            lib.mapAttrsToList (name: file: {
              inherit name;
              inherit (file) path;
            }) config.files
          );
        };
        package = config.pkgs.weechat.override {
          configure = _: {
            init = "/exec -oc cat ${setFile}";
            scripts = config.scripts;
          };
        };
      };
  }
)
