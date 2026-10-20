{
  config,
  lib,
  wlib,
  ...
}:
let
  cfg = config.settings;
in
{
  _class = "wrapper";
  options = {
    settings = {
      keyMap = lib.mkOption {
        type = lib.types.enum [
          "emacs"
          "viins"
          "vicmd"
        ];
        default = "emacs";
        description = "zsh key map, defaults to emacs mode (bindkey -e).";
      };

      shellAliases = lib.mkOption {
        type = with lib.types; attrsOf str;
        default = { };
        description = "shell aliases (alias -- key=value)";
      };

      autocd = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "cd into a directory just by typing it in";
      };

      plugins = {
        zinit = {
          enable = lib.mkEnableOption "zinit";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.zinit;
          };
          light = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
          };
          load = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
          };
          oh-my-zsh = {
            plugins = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
            };
            themes = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
            };
            libs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
            };
          };
          prezto = {
            plugins = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
            };
          };
        };
      };

      integrations = {
        fzf = {
          enable = lib.mkEnableOption "fzf";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.fzf;
          };
        };
        atuin = {
          enable = lib.mkEnableOption "atuin";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.atuin;
          };
        };
        oh-my-posh = {
          enable = lib.mkEnableOption "oh-my-posh";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.oh-my-posh;
          };
        };
        starship = {
          enable = lib.mkEnableOption "starship";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.starship; # Or self'.packages.starship, assuming you use flake parts
          };
        };
        pay-respects = {
          enable = lib.mkEnableOption "pay-respects";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.pay-respects;
          };
          flags = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
          };
        };
        zoxide = {
          enable = lib.mkEnableOption "zoxide";
          package = lib.mkOption {
            type = lib.types.package;
            default = config.pkgs.zoxide;
          };
          flags = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
          };
        };
      };

      completion = {
        enable = lib.mkEnableOption "completions";
        init = lib.mkOption {
          default = "autoload -U compinit && compinit";
          description = "Initialization commands to run when completion is enabled.";
          type = lib.types.lines;
        };
        extraCompletions = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "enable to add zsh-completions package, it has extra completions for other tools";
        };
        colors = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "make the completions colorful (as if you were using ls --color)";
        };
        caseInsensitive = lib.mkEnableOption "completions";
        fuzzySearch = lib.mkEnableOption "fuzzy-completion";
      };

      autoSuggestions = {
        enable = lib.mkEnableOption "autoSuggestions";
        highlight = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fg=#ff00ff,bg=cyan,bold,underline";
          description = "Custom styles for autosuggestion highlighting";
        };

        strategy = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "history"
              "completion"
              "match_prev_cmd"
            ]
          );
          default = [
            "history"
            "completion"
          ];
        };
      };

      history = {
        append = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "append history for every new session instead of replacing it";
        };
        file = lib.mkOption {
          type = lib.types.str;
          default = "$HOME/.zsh_history";
          description = "location to save the history";
        };
        expanded = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "save timestamps with history";
        };
        share = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "share history between sessions";
        };
        save = lib.mkOption {
          type = lib.types.int;
          default = cfg.history.size;
          description = "the number of history lines to save";
        };
        size = lib.mkOption {
          type = lib.types.int;
          default = 10000;
          description = "the number of lines to keep";
        };
        expireDupsFirst = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "remove duplicates in the history first to make room for new commands";
        };
        findNoDups = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "don't display duplicates when doing a history search";
        };
        ignoreAllDups = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "if you run the same command twice, the newer replaces the old one in history, even if its a different output";
        };

        ignoreDups = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "if you run the same command twice, the newer replaces the old one in history, only if it's the same output";
        };
        ignoreSpace = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "a command is not added to history if a space preceeds it";
        };

        saveNoDups = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "don't write duplicates into the history file.";
        };
      };

      env = lib.mkOption {
        type = with lib.types; attrsOf str;
        default = {
          EXAMPLE = "TRUE";
        };
        description = "environment variables to put in .zshenv as an attribute set of strings just like environment.systemVariables";
      };
    };

    extraRC = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "extra stuff to put in .zshrc, gets appended *after* all of the options";
    };

    ".zshrc" =
      let
        zoxide-flags = lib.concatStringsSep " " cfg.integrations.zoxide.flags;
        pay-respects-flags = lib.concatStringsSep " " cfg.integrations.pay-respects.flags;
        ing = cfg.integrations;
      in
      lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.content = builtins.concatStringsSep "\n" [
          "# KeyMap"
          (
            if cfg.keyMap == "viins" then
              "bindkey -a"
            else if cfg.keyMap == "vicmd" then
              "bindkey -v"
            else
              "bindkey -e"
          )
          (lib.optionalString cfg.autocd "setopt autocd")

          "# Aliases"

          (lib.concatMapAttrsStringSep "\n" (k: v: ''alias -- ${k}="${v}"'') cfg.shellAliases)

          "# Completion"
          (lib.optionalString cfg.completion.enable cfg.completion.init)
          (lib.optionalString cfg.completion.caseInsensitive "zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' ")
          (lib.optionalString cfg.completion.colors "zstyle ':completion:*' list-colors \"$\\{(s.:.)LS_COLORS\\}\" ")
          (lib.optionalString cfg.completion.fuzzySearch ''
            zstyle ':completion:*' menu no
            source ${config.pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
            source ${config.pkgs.fzf-zsh-plugin}/share/zsh/fzf-zsh-plugin/fzf-zsh-plugin.plugin.zsh
          '')

          "#Autosuggestions"
          (lib.optionalString cfg.autoSuggestions.enable ''
            source ${config.pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
              ${lib.optionalString (cfg.autoSuggestions.strategy != [ ]) ''
                ZSH_AUTOSUGGEST_STRATEGY=(${lib.concatStringsSep " " cfg.autoSuggestions.strategy})
              ''}

            ${lib.optionalString (cfg.autoSuggestions.highlight != null) ''
              ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=(${cfg.autoSuggestions.highlight})
            ''}
          '')

          "# Plugins"
          (lib.optionalString cfg.plugins.zinit.enable "source ${config.pkgs.zinit}/share/zinit/zinit.zsh")
          (lib.concatMapStringsSep "\n" (p: "zinit light ${p}") cfg.plugins.zinit.light)
          (lib.concatMapStringsSep "\n" (p: "zinit load${p}") cfg.plugins.zinit.load)
          (lib.concatMapStringsSep "\n" (p: "zinit snippet OMZP::${p}") cfg.plugins.zinit.oh-my-zsh.plugins)
          (lib.concatMapStringsSep "\n" (p: "zinit snippet OMZT::${p}") cfg.plugins.zinit.oh-my-zsh.themes)
          (lib.concatMapStringsSep "\n" (p: "zinit snippet OMZL::${p}") cfg.plugins.zinit.oh-my-zsh.libs)
          (lib.concatMapStringsSep "\n" (p: "zinit snippet PZT::${p}") cfg.plugins.zinit.prezto.plugins)
          "# Integrations"
          (lib.optionalString ing.fzf.enable "source <(fzf --zsh)")
          (lib.optionalString ing.atuin.enable ''eval "$(atuin init zsh)"'')
          (lib.optionalString ing.oh-my-posh.enable ''eval "$(oh-my-posh init zsh)"'')
          (lib.optionalString ing.zoxide.enable ''eval "$(zoxide init zsh ${zoxide-flags})"'')
          (lib.optionalString ing.pay-respects.enable ''eval "$(pay-respects zsh ${pay-respects-flags})"'')
          (lib.optionalString ing.starship.enable ''eval "$(starship init zsh)"'')

          "# History"

          "HISTSIZE=${toString cfg.history.size}"
          "SAVEHIST=${toString cfg.history.save}"
          "HISTFILE=${toString cfg.history.file}"

          (lib.optionalString cfg.history.append "setopt appendhistory")
          (lib.optionalString cfg.history.share "setopt sharehistory")
          (lib.optionalString cfg.history.ignoreSpace "setopt hist_ignore_space")
          (lib.optionalString cfg.history.ignoreAllDups "setopt hist_ignore_all_dups")
          (lib.optionalString cfg.history.ignoreDups "setopt hist_ignore_dups")
          (lib.optionalString cfg.history.saveNoDups "setopt hist_save_no_dups")
          (lib.optionalString cfg.history.findNoDups "setopt histfindnodups")
          (lib.optionalString cfg.history.expanded "setopt extendedhistory")

          "# Extra Content"

          config.extraRC
        ];
      };

    ".zshenv" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content =
        builtins.concatStringsSep "\n" [ (lib.concatMapAttrsStringSep "\n" (k: v: "${k}=${v}") cfg.env) ]
        + (lib.optionalString cfg.integrations.fzf.enable ''
          path+=(${config.pkgs.fzf-zsh-plugin})
        '');
    };
  };

  config = {
    package = config.pkgs.zsh;
    extraPackages =
      let
        ing = cfg.integrations;
      in
      lib.optional ing.fzf.enable ing.fzf.package
      ++ lib.optional ing.fzf.enable config.pkgs.fzf-zsh-plugin
      ++ lib.optional ing.atuin.enable ing.atuin.package
      ++ lib.optional ing.zoxide.enable ing.zoxide.package
      ++ lib.optional ing.oh-my-posh.enable ing.oh-my-posh.package
      ++ lib.optional ing.starship.enable ing.starship.package
      ++ lib.optional ing.pay-respects.enable ing.pay-respects.package
      ++ lib.optional cfg.completion.enable config.pkgs.nix-zsh-completions
      ++ lib.optional cfg.completion.extraCompletions config.pkgs.zsh-completions
      ++ lib.optional cfg.completion.fuzzySearch config.pkgs.zsh-fzf-tab;

    flags = {
      "--histfcntllock" = true;
      "--histexpiredupsfirst" = cfg.history.expireDupsFirst;
    };

    postHook = "
zinit plugins
";

    env.ZDOTDIR = builtins.toString (
      config.pkgs.linkFarm "zsh-merged-config" [
        {
          name = ".zshrc";
          inherit (config.".zshrc") path;
        }
        {
          name = ".zshenv";
          inherit (config.".zshenv") path;
        }
      ]
    );
    meta.maintainers = [
      {
        name = "mrid22";
        github = "mrid22";
        githubId = 153362027;
      }
    ];
  };
}
