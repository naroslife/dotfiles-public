{ config, pkgs, lib, ... }:
{
  # Import all modules
  imports = [ ./modules ];

  # Home Manager configuration
  home.stateVersion = "25.05";
  # Username and homeDirectory are set by the flake

  # Let home-manager manage itself
  programs.home-manager.enable = true;

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
    ".config/pip/pip.conf".text = ''
      [install]
      user = true

      [list]
      format = columns
    '';

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
  news.display = "silent"
}
