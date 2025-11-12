{ config, pkgs, lib, ... }:
let
  # Path aliases for improved readability and maintainability
  homeDir = config.home.homeDirectory;
  xdgConfig = "${homeDir}/.config";
  xdgData = "${homeDir}/.local/share";
  xdgState = "${homeDir}/.local/state";
  xdgCache = "${homeDir}/.cache";
in
{
  # Session environment variables
  home.sessionVariables = {
    # === Editor and Pager ===
    EDITOR = "vim";
    VISUAL = "nvim";
    PAGER = "less";
    MANPAGER = "less -R";
    SYSTEMD_PAGER = "less";

    # === Terminal ===
    TERMINAL = "alacritty";
    TERM = "xterm-256color";
    COLORTERM = "truecolor";

    # === Browser ===
    BROWSER =
      if (builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop)
      then "wslview"
      else "firefox";

    # === XDG Base Directory Specification ===
    XDG_CONFIG_HOME = xdgConfig;
    XDG_DATA_HOME = xdgData;
    XDG_STATE_HOME = xdgState;
    XDG_CACHE_HOME = xdgCache;
    XDG_RUNTIME_DIR = "/run/user/$(id -u)";

    # === Development Paths ===
    PROJECTS = "${homeDir}/projects";
    REPOS = "${homeDir}/repos";
    DOTFILES = "${homeDir}/dotfiles";

    # === Language-specific ===
    # Go
    GOPATH = "${homeDir}/go";
    GOBIN = "${homeDir}/go/bin";
    GO111MODULE = "on";

    # Rust
    CARGO_HOME = "${homeDir}/.cargo";
    RUSTUP_HOME = "${homeDir}/.rustup";
    RUST_BACKTRACE = "1";

    # Python
    PYTHONDONTWRITEBYTECODE = "1";
    PYTHONUNBUFFERED = "1";
    PIP_DISABLE_PIP_VERSION_CHECK = "1";
    PIP_NO_CACHE_DIR = "1";
    VIRTUAL_ENV_DISABLE_PROMPT = "1";

    # Node.js
    NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
    NODE_ENV = "development";

    # Ruby
    GEM_HOME = "${homeDir}/.gem";
    BUNDLE_USER_HOME = "${homeDir}/.bundle";

    # Java
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
    MAVEN_OPTS = "-Xmx1024m";

    # === Security ===
    GPG_TTY = "$(tty)";
    SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$(gpgconf --list-dirs agent-ssh-socket)}";

    # === History ===
    HISTSIZE = "100000";
    HISTFILESIZE = "100000";
    HISTCONTROL = "ignoreboth:erasedups";
    HISTIGNORE = "ls:cd:cd -:pwd:exit:date:* --help:man *:history:clear:fg";
    HISTTIMEFORMAT = "%F %T ";

    # === Less configuration ===
    LESS = "-FRXi";
    LESSHISTFILE = "${xdgCache}/less/history";
    LESSKEY = "${xdgConfig}/less/lesskey";
    LESSCHARSET = "utf-8";

    # Color in less for man pages
    LESS_TERMCAP_mb = "$(tput bold; tput setaf 2)"; # begin blinking
    LESS_TERMCAP_md = "$(tput bold; tput setaf 6)"; # begin bold
    LESS_TERMCAP_me = "$(tput sgr0)"; # end mode
    LESS_TERMCAP_so = "$(tput bold; tput setaf 3; tput setab 4)"; # begin standout
    LESS_TERMCAP_se = "$(tput rmso; tput sgr0)"; # end standout
    LESS_TERMCAP_us = "$(tput smul; tput bold; tput setaf 7)"; # begin underline
    LESS_TERMCAP_ue = "$(tput rmul; tput sgr0)"; # end underline
    LESS_TERMCAP_mr = "$(tput rev)";
    LESS_TERMCAP_mh = "$(tput dim)";
    LESS_TERMCAP_ZN = "$(tput ssubm)";
    LESS_TERMCAP_ZV = "$(tput rsubm)";
    LESS_TERMCAP_ZO = "$(tput ssupm)";
    LESS_TERMCAP_ZW = "$(tput rsupm)";

    # === FZF configuration ===
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
    FZF_DEFAULT_OPTS = ''
      --height=60%
      --layout=reverse
      --border=rounded
      --prompt='❯ '
      --pointer='▶'
      --marker='✓'
      --preview-window=right:60%:wrap
      --bind='ctrl-/:toggle-preview'
      --bind='ctrl-u:preview-page-up'
      --bind='ctrl-d:preview-page-down'
      --bind='ctrl-a:select-all'
      --bind='ctrl-y:execute-silent(echo {+} | xclip -selection clipboard)'
      --color=dark
      --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
      --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
    '';
    FZF_CTRL_T_OPTS = "--preview '(bat --color=always {} || tree -C {}) 2> /dev/null | head -200'";
    FZF_CTRL_R_OPTS = "--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'";
    FZF_ALT_C_OPTS = "--preview 'tree -C {} | head -200'";

    # === Ripgrep configuration ===
    RIPGREP_CONFIG_PATH = "${xdgConfig}/ripgrep/config";

    # === Docker ===
    DOCKER_BUILDKIT = "1";
    BUILDKIT_PROGRESS = "plain";
    COMPOSE_DOCKER_CLI_BUILD = "1";

    # === Locale ===
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    LC_CTYPE = "C.UTF-8";

    # === Nix ===
    NIX_SHELL_PRESERVE_PROMPT = "1";
    NIXPKGS_ALLOW_UNFREE = "1";

    # === Performance ===
    MAKEFLAGS = "-j$(nproc)";

    # === Security ===
    GNUPGHOME = "${homeDir}/.gnupg";
    PASSWORD_STORE_DIR = "${homeDir}/.password-store";

    # === Application-specific ===
    BAT_THEME = "Monokai Extended";
    BAT_STYLE = "numbers,changes,header";

    # EZA (ls replacement)
    EZA_COLORS = "uu=33:gu=33:sn=32:sb=32:da=34:ur=33:uw=31:ux=32:ue=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32";

    # Zoxide
    _ZO_DATA_DIR = "${xdgData}/zoxide";
    _ZO_ECHO = "1";
    _ZO_RESOLVE_SYMLINKS = "1";

    # Starship
    STARSHIP_CONFIG = "${xdgConfig}/starship.toml";
    STARSHIP_CACHE = "${xdgCache}/starship";

    # Man pages
    MANWIDTH = "120";

    # === Custom ===
    # Add any custom environment variables here
    DOTFILES_VERSION = "2.0";
    DOTFILES_MANAGED = "home-manager";
  };

  # Session path
  # Note: Home Manager automatically appends system PATH after these entries
  home.sessionPath = [
    "${homeDir}/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/go/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/.npm-global/bin"
    "${homeDir}/.gem/bin"
    "${homeDir}/.dotnet/tools"
    "${pkgs.poetry}/bin"
  ];

  # Create necessary directories
  home.activation.createEnvDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${xdgCache}/less
    mkdir -p ${xdgConfig}/ripgrep
    mkdir -p ${xdgData}/zoxide
    mkdir -p ${xdgCache}/starship
    mkdir -p ${homeDir}/projects
    mkdir -p ${homeDir}/repos
    mkdir -p ${homeDir}/go/bin
    mkdir -p ${homeDir}/.npm-global
  '';

  # Ripgrep config file
  home.file.".config/ripgrep/config" = {
    text = ''
      # Ripgrep configuration

      # Search hidden files and directories
      --hidden

      # Follow symlinks
      --follow

      # Exclude directories
      --glob=!.git/
      --glob=!node_modules/
      --glob=!target/
      --glob=!dist/
      --glob=!build/
      --glob=!.cache/
      --glob=!.vscode/
      --glob=!.idea/

      # Set the colors
      --colors=line:style:bold
      --colors=line:fg:yellow
      --colors=match:bg:magenta
      --colors=match:fg:white
      --colors=match:style:nobold

      # Smart case
      --smart-case

      # Sort by path
      --sort=path

      # Max columns
      --max-columns=150
      --max-columns-preview
    '';
  };
}
