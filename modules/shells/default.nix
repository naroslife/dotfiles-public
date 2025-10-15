{ config, pkgs, lib, ... }:
let
  # Import shell integration helpers
  shellHelpers = import ../../lib/shell-helpers.nix { inherit lib; };

  # Default shells to integrate with
  defaultShells = [ "bash" "zsh" ];
in
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

  programs.starship = shellHelpers.withShells defaultShells {
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

  programs.zoxide = shellHelpers.enableWithShells defaultShells;

  programs.atuin = shellHelpers.withShells defaultShells {
    settings = {
      # General settings
      auto_sync = false; # Disable auto-sync for faster startup
      update_check = false;
      sync_frequency = "1h"; # Reduced from 5m
      sync_address = "https://api.atuin.sh";

      # Search settings
      search_mode = "skim";
      filter_mode = "global";
      filter_mode_shell_up_key_binding = "global";
      style = "full";
      inline_height = 20;
      show_preview = true;

      # Performance settings
      max_preview_height = 10; # Limit preview height for faster rendering
      prefers_reduced_motion = false;

      # Groups command history by Git repository root
      workspaces = true;
# Shows N lines above/below the selected command in preview
      scroll_context_lines = 1;

      # History settings
      history_filter = [
        # Navigation (replaced by modern tools)
  "^ls" "^ll" "^la" "^l"  # You use eza
  "^cd"                    # You use zoxide (z)
  "^pwd"

  # Shell management
  "^exit" "^logout"
  "^clear" "^cls"

  # History tools themselves
  "^atuin"
  "^mcfly"
  "^history"
  "^switch_history"        # Your custom function from home.nix

  # Nix evaluation commands (not reproducible outside context)
  "^nix repl"
  "^nix eval"
      ];

      # Key bindings
      enter_accept = false;

      # Stats settings
      common_prefix = [
  "sudo"
  "nsudo"      # Your custom Nix-preserving sudo
  "sudo-nix"   # Alias from home.nix
  "doas"       # If you use doas
];

common_subcommands = [
  # Version control
  "git"

  # Package managers
  "npm" "pnpm" "yarn"
  "cargo"

  # Nix ecosystem (critical for your dotfiles)
  "nix"           # nix build, nix run, nix develop
  "home-manager"  # Your primary deployment tool
  "nix-env"
  "nix-shell"

  # Containers
  "docker"
  "podman"        # If you use podman

  # System management
  "systemctl"
  "journalctl"

  # Modern CLI tools with subcommands
  "gh"            # GitHub CLI
  "kubectl"       # If using Kubernetes
];
      # Sync settings
      key_path = "~/.local/share/atuin/key";
      session_path = "~/.local/share/atuin/session";

      # UI settings
      show_help = true;
      exit_mode = "return-original";
    };
  };

  programs.fzf = shellHelpers.enableWithShells defaultShells;

  programs.direnv = shellHelpers.enableWithShells defaultShells;

  programs.broot = shellHelpers.enableWithShells defaultShells;

  programs.mcfly = {
    enable = false; # Disabled by default in favor of atuin
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
}
