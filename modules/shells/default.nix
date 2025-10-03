{ config, pkgs, lib, ... }:
{
  imports = [
    ./bash.nix
    ./zsh.nix
    ./elvish.nix
    ./aliases.nix
    ./readline.nix
  ];

  home.packages = with pkgs; [
    # Shell essentials
    zsh
    elvish

    # Completions
    zsh-completions
    carapace

    # Shell enhancements
    # thefuck removed - incompatible with python 3.12+
    mcfly # Smart command history
  ];

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      # Performance optimizations
      command_timeout = 500; # Reduced from 2000ms
      scan_timeout = 30; # Timeout for scanning files
      format = ''
        [░▒▓](#a3aed2)[  ](bg:#a3aed2 fg:#090c0c)[](bg:#769ff0 fg:#a3aed2)$directory[](fg:#769ff0 bg:#394260)$git_branch[](fg:#394260 bg:#212736)$nodejs$rust$golang$php[](fg:#212736 bg:#1d2230)$time[ ](fg:#1d2230)
        $character'';

      directory = {
        style = "fg:#e3e5e5 bg:#769ff0";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:#394260";
        format = "[[ $symbol $branch \\$ ](fg:#769ff0 bg:#394260)]($style)";
      };

      git_status = {
        style = "bg:#394260";
        format = "[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#1d2230";
        format = "[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)";
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      # General settings
      auto_sync = false; # Disable auto-sync for faster startup
      update_check = false;
      sync_frequency = "1h"; # Reduced from 5m
      sync_address = "https://api.atuin.sh";

      # Search settings
      search_mode = "fuzzy";
      filter_mode = "host";
      filter_mode_shell_up_key_binding = "session";
      style = "compact";
      inline_height = 10;
      show_preview = true;

      # Performance settings
      max_preview_height = 4; # Limit preview height for faster rendering
      prefers_reduced_motion = false;

      # History settings
      history_filter = [
        "^ls"
        "^cd"
        "^pwd"
        "^exit"
        "^clear"
      ];

      # Key bindings
      enter_accept = false;

      # Stats settings
      common_prefix = [ "sudo" ];
      common_subcommands = [ "docker" "git" "npm" "cargo" ];

      # Sync settings
      key_path = "~/.local/share/atuin/key";
      session_path = "~/.local/share/atuin/session";

      # UI settings
      show_help = true;
      exit_mode = "return-original";
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.broot = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.mcfly = {
    enable = false; # Disabled by default in favor of atuin
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
}
