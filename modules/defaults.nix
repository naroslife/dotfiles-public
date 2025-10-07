# Default Configuration Values
#
# Single source of truth for all default values in the dotfiles.
# These defaults use lib.mkDefault which gives them the lowest priority,
# allowing them to be overridden by:
#   1. User-specific config files (~/.config/dotfiles/user.nix)
#   2. Interactive setup (generates user.nix)
#   3. Flake.nix per-user detection
#   4. modules/user-config.nix overrides
#
# All values here should be sensible defaults that work across all systems.

{ lib, pkgs, config, ... }:

{
  options.dotfiles.defaults = with lib; {
    git = {
      userName = mkOption {
        type = types.str;
        default = "Your Name";
        description = "Default git user name";
      };

      userEmail = mkOption {
        type = types.str;
        default = "you@example.com";
        description = "Default git user email";
      };

      signingEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to sign commits by default";
      };
    };

    shell = {
      default = mkOption {
        type = types.enum [ "bash" "zsh" "elvish" ];
        default = "zsh";
        description = "Default shell";
      };

      available = mkOption {
        type = types.listOf types.str;
        default = [ "bash" "zsh" "elvish" ];
        description = "Available shells";
      };
    };

    editor = {
      terminal = mkOption {
        type = types.enum [ "vim" "nvim" "nano" "emacs" "hx" ];
        default = "hx";
        description = "Default terminal editor (for EDITOR in terminal contexts)";
      };

      visual = mkOption {
        type = types.enum [ "vim" "nvim" "nano" "emacs" "hx" "code" ];
        default = "code";
        description = "Default visual editor (for VISUAL)";
      };

      gui = mkOption {
        type = types.enum [ "code" "nvim" "emacs" "hx" ];
        default = "code";
        description = "Default GUI editor (for desktop contexts)";
      };

      # The actual editor to use - defaults to terminal editor
      # This is what gets set in the EDITOR environment variable
      actual = mkOption {
        type = types.str;
        default = config.dotfiles.defaults.editor.terminal;
        description = "The actual editor to set in EDITOR variable (defaults to terminal editor)";
      };
    };

    environment = {
      timezone = mkOption {
        type = types.str;
        default = "Europe/Budapest";
        description = "Default timezone";
        example = "America/New_York";
      };

      locale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = "Default locale";
      };
    };

    pager = {
      default = mkOption {
        type = types.str;
        default = "less";
        description = "Default pager";
      };

      options = mkOption {
        type = types.str;
        default = "-FRXi";
        description = "Default pager options";
      };
    };

    fileManager = {
      terminal = mkOption {
        type = types.enum [ "ranger" "nnn" "lf" "mc" "nvim" ];
        default = "nvim";
        description = "Default terminal file manager";
      };
    };

    browser = {
      terminal = mkOption {
        type = types.str;
        default = "lynx";
        description = "Terminal-based browser";
      };

      gui = mkOption {
        type = types.str;
        default = "firefox";
        description = "GUI browser";
      };

      wsl = mkOption {
        type = types.str;
        default = "wslview";
        description = "Browser command for WSL";
      };
    };

    terminal = {
      emulator = mkOption {
        type = types.str;
        default = "alacritty";
        description = "Default terminal emulator";
      };

      term = mkOption {
        type = types.str;
        default = "xterm-256color";
        description = "TERM environment variable value";
      };

      colorterm = mkOption {
        type = types.str;
        default = "truecolor";
        description = "COLORTERM environment variable value";
      };
    };
  };
}
