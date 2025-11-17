{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./modern.nix
    ./productivity.nix
  ];

  home.packages = with pkgs; [
    # === Network Essentials ===
    curl
    wget

    # === Terminal Multiplexer ===
    tmux
  ];

  # Additional configurations shared across CLI tools
  home.file = {
    # Tmuxinator configs
    ".config/tmuxinator" = {
      source = ../../tmuxinator;
      recursive = true;
    };

    # Neovim config (not yet migrated to native Nix)
    ".config/nvim" = {
      source = ../../nvim;
      recursive = true;
    };
  };

  # WSL-specific optimizations are in modules/wsl.nix
}
