{
  config,
  pkgs,
  lib,
  ...
}: {
  # Import all modules
  imports = [./modules];

  # Home Manager configuration
  home.stateVersion = "25.05";
  # Username and homeDirectory are set by the flake

  # Let home-manager manage itself
  programs.home-manager.enable = true;

# Control whether Home Manager modifies shell RC files
# Set to "false" (default) to use dev shell mode (recommended)
# Set to "true" for traditional Home Manager behavior that modifies RC files
home.sessionVariables = lib.mkDefault {
HM_MODIFY_SHELL = "false";
};

  # Session variables and paths are now managed in modules/environment.nix

  # File management
  home.file = {
    # Elvish configuration
    ".config/elvish/rc.elv".source = ./elvish/rc.elv;
    ".config/elvish/lib".source = ./elvish/lib;
    ".config/elvish/aliases".source = ./elvish/aliases;

    # Tmux scripts (configuration now in modules/dev/default.nix)
    ".config/tmux/scripts".source = ./tmux/scripts;

    # Carapace configuration
    ".config/carapace".source = ./carapace;

# Helper script to enter the Home Manager dev environment
".local/bin/hm-dev-shell" = lib.mkIf (config.home.sessionVariables.HM_MODIFY_SHELL == "false") {
text = ''
        #!/usr/bin/env bash
        # Enter Home Manager development shell
        DOTFILES_DIR="''${DOTFILES_DIR:-$HOME/dotfiles-public}"

        if [ -d "$DOTFILES_DIR" ]; then
          cd "$DOTFILES_DIR" && nix develop .#hm-env
        else
          echo "Error: dotfiles-public directory not found at $DOTFILES_DIR"
          echo "Set DOTFILES_DIR environment variable to the correct path"
          exit 1
        fi
      '';
executable = true;
};

    # Note: starship, tmux, and atuin configurations are now managed
    # via Nix modules in modules/shells/default.nix and modules/dev/default.nix

    # SSH configuration is now managed in modules/dev/ssh.nix

    # Tool versions for asdf
    ".tool-versions".source = ./.tool-versions;

    # Git and VS Code configurations are managed in:
    # - modules/dev/git.nix
    # - modules/dev/vscode.nix

    # Package manager configurations

    # Python pip configuration
    # ".config/pip/pip.conf".text = ''
    #   [install]
    #   user = true

    #   [ global ]
    #   # Respect virtual environments
    #   no-user-when-venv = true


    #   [list]
    #   format = columns
    # '';

    # Create directory markers for package managers
    ".npm-global/.keep".text = "";
    ".gem/.keep".text = "";
  };

  # XDG configuration
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";
    cacheHome = "${config.home.homeDirectory}/.cache";

    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      download = "${config.home.homeDirectory}/Downloads";
      documents = "${config.home.homeDirectory}/Documents";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
      publicShare = "${config.home.homeDirectory}/Public";
      templates = "${config.home.homeDirectory}/Templates";
    };
  };

  # News - notify about home-manager news
  news.display = "silent";
}
