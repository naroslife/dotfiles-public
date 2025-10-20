{ config, pkgs, lib, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Interactive completion with fzf
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "v1.1.2";
          sha256 = "sha256-Qv8zAiMtrr67CbLRrFjGaPzFZcOiMVEFLg1Z+N6VMhg=";
        };
      }
    ];

    # Performance optimizations
    autosuggestion.strategy = [ "history" "completion" ];
    historySubstringSearch.enable = true;

    # History settings for better performance
    history = {
      size = 50000;
      save = 50000;
      path = "${config.home.homeDirectory}/.cache/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    # shellAliases are configured in aliases.nix

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Performance: Skip system-wide compinit
        skip_global_compinit=1

        # Source Nix
        if [ -e "$HOME/.nix-profile/etc/profile.d/nix-daemon.sh" ]; then
          source "$HOME/.nix-profile/etc/profile.d/nix-daemon.sh"
        elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
          source "$HOME/.nix-profile/etc/profile.d/nix.sh"
        fi

        # Load Home Manager session variables (needed for non-login interactive shells)
        if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        fi

        unset PKG_CONFIG_LIBDIR
      '')
      ''
        # Key bindings
        bindkey '^a' beginning-of-line
        bindkey '^w' autosuggest-execute
        bindkey '^e' autosuggest-accept
        bindkey '^u' autosuggest-toggle
        bindkey '^L' vi-forward-word
        bindkey '^k' up-line-or-search
        bindkey '^j' down-line-or-search
        bindkey '^W' backward-kill-word

        # Home/End keys (multiple variations for different terminals)
        bindkey "^[[H" beginning-of-line      # Home (standard)
        bindkey "^[[1~" beginning-of-line     # Home (alternate)
        bindkey "^[[F" end-of-line            # End (standard)
        bindkey "^[[4~" end-of-line           # End (alternate)

        # Ctrl + Arrow keys for word navigation (multiple variations)
        bindkey "^[[1;5C" forward-word        # Ctrl+Right (standard)
        bindkey "^[[1;5D" backward-word       # Ctrl+Left (standard)
        bindkey "^[^[[C" forward-word         # Ctrl+Right (alternate)
        bindkey "^[^[[D" backward-word        # Ctrl+Left (alternate)

        # KUBECONFIG
        export KUBECONFIG=~/.kube/config

        # FZF configuration
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
        export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"

        # fzf-tab configuration for interactive completion
        # Disable sort when completing `git checkout`
        zstyle ':completion:*:git-checkout:*' sort false
        # Set descriptions format to enable group support
        zstyle ':completion:*:descriptions' format '[%d]'
        # Set list-colors to enable filename colorizing
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        # Show completion descriptions (important for carapace)
        zstyle ':completion:*' verbose yes
        zstyle ':completion:*' group-name '''
        # Preview directory's content with eza when completing cd
        zstyle ':fzf-tab:complete:cd:*' fzf-preview '/home/uif58593/.nix-profile/bin/eza -1 --color=always $realpath'
        # Switch group using `,` and `.`
        zstyle ':fzf-tab:*' switch-group ',' '.'
        # Use tmux popup for fzf-tab (if in tmux)
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
        # Enable continuous completion trigger
        zstyle ':fzf-tab:*' continuous-trigger '/'

        # === AI Agent Detection and Smart Aliases ===
        # Source the agent detection library for context-aware command selection
        if [ -f "$HOME/dotfiles-public/lib/agent-detection.sh" ]; then
          source "$HOME/dotfiles-public/lib/agent-detection.sh"

          # Create smart aliases that use POSIX tools for AI agents, modern tools for humans
          # These functions check context at runtime, not at alias definition time

          # Smart cat - bat for humans, cat for agents
          function cat() {
            _smart_alias "bat" "cat" "$@"
          }

          # Smart ls - eza for humans, ls for agents
          function ls() {
            _smart_alias "eza" "ls" "$@"
          }

          # Smart ll - eza -l for humans, ls -l for agents
          function ll() {
            if is_agent_context; then
              command ls -l "$@"
            else
              if command -v eza >/dev/null 2>&1; then
                eza -l "$@"
              else
                command ls -l "$@"
              fi
            fi
          }

          # Smart la - eza -la for humans, ls -la for agents
          function la() {
            if is_agent_context; then
              command ls -la "$@"
            else
              if command -v eza >/dev/null 2>&1; then
                eza -la "$@"
              else
                command ls -la "$@"
              fi
            fi
          }

          # Smart grep - ripgrep for humans, grep for agents
          function grep() {
            _smart_alias "rg" "grep" "$@"
          }

          # Smart find - fd for humans, find for agents
          function find() {
            _smart_alias "fd" "find" "$@"
          }
        fi
        # === End AI Agent Detection ===

        # Initialize carapace completion for zsh
        if command -v carapace >/dev/null 2>&1; then
          source <(carapace _carapace zsh)
        fi

        # WSL-specific initialization
        if [ -z "''${CLAUDE:-}" ] && [ -f "$HOME/dotfiles-public/wsl-init.sh" ]; then
          source "$HOME/dotfiles-public/wsl-init.sh"
        fi

        # Lazy-load custom functions (only source if directory exists and has files)
        if [ -d "$HOME/dotfiles-public/scripts/functions" ] && [ -n "$(ls -A "$HOME/dotfiles-public/scripts/functions"/*.sh 2>/dev/null)" ]; then
          for func_file in "$HOME/dotfiles-public/scripts/functions"/*.sh; do
            if [[ -f "$func_file" && "$func_file" != *"history-tools.sh" ]]; then
              source "$func_file"
            fi
          done

          # Source zsh-specific history tools
          if [ -f "$HOME/dotfiles-public/scripts/functions/history-tools-zsh.sh" ]; then
            source "$HOME/dotfiles-public/scripts/functions/history-tools-zsh.sh"
          fi
        fi

        # Override cd function for zsh (similar to bash but with zsh syntax)
        function cd() {
          if [ -z "''${CLAUDE:-}" ]; then
            show_reminder "cd" "br" "interactive directory navigation with broot"
            if command -v __zoxide_z >/dev/null 2>&1; then
              __zoxide_z "$@"
            else
              builtin cd "$@"
            fi
          else
            builtin cd "$@"
          fi
        }

        set +u
      ''
    ];
  };
}
