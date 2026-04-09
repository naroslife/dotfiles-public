{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # === Core System Utilities ===
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    which
    file
    tree
    man
    man-pages

    # === Compression & Archives ===
    gzip
    unzip
    zip
    gnutar
    xz
    p7zip

    # === Network Essentials ===
    curl
    wget
    openssh
    netcat
    rsync

    # === Text Editors (Minimal) ===
    vim
    nano

    # === System Monitoring ===
    # htop removed - using htop-vim from modern.nix instead
    lsof
    strace

    # === Essential Build Tools ===
    gnumake
    gcc
    pkg-config

    # === Terminal Multiplexer ===
    tmux

    # === Shell Essentials ===
    bashInteractive
    bash-completion

    # === Fonts ===
    fira-code
    fira-code-symbols
    # Individual nerd fonts (nerdfonts package deprecated)
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono

    # === Nix Tools ===
    nix-tree
    nix-diff
    nixpkgs-fmt
    alejandra # Nix formatter - fast and opinionated
    nil # Nix language server
    nix-output-monitor # Better nix build output
  ];
}
