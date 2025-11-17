{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # === File Management & Navigation ===
    tree
    ranger # Console file manager with vi-like keybindings
    broot # Interactive tree view, file manager, and launcher
    stow # Symlink farm manager for dotfiles
    termscp # Terminal file transfer client (SCP/SFTP/FTP/S3)
    rclone # Sync files with cloud storage providers (S3, Drive, Dropbox, etc.)
    restic # Fast, secure, and efficient backup program
    qdirstat # Fast directory statistics and disk usage analyzer

    # === Learning & Productivity ===
    tealdeer # Fast tldr pages implementation (command examples)
    cheat # Create and view interactive cheatsheets
    navi # Interactive cheatsheet tool with shell integration

    # === Security & Encryption ===
    gnupg # GNU Privacy Guard
    pass # Unix password manager using GPG

    # === Utilities ===
    xclip # X11 clipboard interface
    wl-clipboard # Wayland clipboard utilities
    nix-prefetch-git # Prefetch git repos for Nix expressions
    gettext # Internationalization tools
    file # Determine file types
    hexdump # Display file contents in hex
    xxd # Hex dump and reverse
    unzip
    p7zip # 7-Zip file archiver

    # === Custom Scripts ===
    (writeShellScriptBin "claude-code" ''
      # Use npx to run the package (downloads/caches on first run)
      exec ${nodejs}/bin/npx -y @anthropic-ai/claude-code "$@"
    '')
  ];

  # Configuration files for productivity tools
  home.file = {
    # Termscp config
    ".config/termscp" = {
      source = ../../termscp;
      recursive = true;
    };

    # Carapace completion specs
    ".config/carapace/specs" = {
      source = ../../carapace/specs;
      recursive = true;
    };
  };

  # Environment variables are configured in modules/environment.nix
}
