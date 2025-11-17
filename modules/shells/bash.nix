{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.bash = {
    enable = true;
    # shellAliases are configured in aliases.nix

    bashrcExtra = ''
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

      # KUBECONFIG
      export KUBECONFIG=~/.kube/config

      # FZF configuration
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'

      # stdlib.sh disabled - was causing grep errors
      # if [ -f "$HOME/dotfiles-public/stdlib.sh/stdlib.sh" ]; then
      #   source "$HOME/dotfiles-public/stdlib.sh/stdlib.sh"
      # fi

      # Lazy-load carapace completion (only when needed)
      _lazy_load_carapace() {
        if command -v carapace >/dev/null 2>&1; then
          source <(carapace _carapace)
          unset -f _lazy_load_carapace
        fi
      }
      # Trigger on first tab completion
      complete -F _lazy_load_carapace -D

      # WSL-specific initialization
      # if [ -z "''${CLAUDE:-}" ] && [ -f "$HOME/dotfiles-public/wsl-init.sh" ]; then
      #   source "$HOME/dotfiles-public/wsl-init.sh"
      # fi

      # Lazy-load custom functions (only source if directory exists and has files)
      if [ -d "$HOME/dotfiles-public/scripts/functions" ] && [ -n "$(ls -A "$HOME/dotfiles-public/scripts/functions"/*.sh 2>/dev/null)" ]; then
        for func_file in "$HOME/dotfiles-public/scripts/functions"/*.sh; do
          if [ -f "$func_file" ]; then
            source "$func_file"
          fi
        done
      fi

      # History tool aliases (consistent with zsh)
      alias use-atuin='switch_history atuin'
      alias use-mcfly='switch_history mcfly'
      alias history-status='switch_history status'
      set +u
    '';
  };
}
