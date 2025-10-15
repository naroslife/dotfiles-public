{ config, pkgs, ... }:
{
  imports = [
    ./git.nix
    ./languages.nix
    ./containers.nix
    ./ssh.nix
  ];

  home.packages = with pkgs; [
    # Text Editors
    helix # Post-modern modal editor

    # Documentation
    # tldr removed - using tealdeer instead (avoids zsh completion conflict)
    cheat # Interactive cheatsheets

    # Code Analysis
    tokei # Code statistics
    cloc # Count lines of code
    scc # Fast code counter

    # Debugging
    gdb # GNU debugger
    lldb # LLVM debugger
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.tmux = {
    enable = true;

    # Keep default Ctrl-b prefix
    prefix = "C-b";

    # Enable mouse support
    mouse = true;

    # Start windows and panes at 1
    baseIndex = 1;

    # Use 256 colors
    terminal = "tmux-256color";

    # History
    historyLimit = 10000;

    # No delay for escape key
    escapeTime = 0;

    # Use vi keybindings
    keyMode = "vi";

    # Plugins
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
      vim-tmux-navigator
    ];

    extraConfig = ''
      # Renumber windows when one is closed
      set -g renumber-windows on

      # True color support
      set -ga terminal-overrides ",*256col*:Tc"

      # Reload config
      bind r source-file ~/.config/tmux.conf \; display "Config reloaded!"

      # Better split bindings
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Navigate panes with vim keys
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes with vim keys (repeatable)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Copy mode bindings
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Pane settings
      setw -g pane-base-index 1

      # Automatic restoration
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '5'
      set -g @continuum-boot 'on'

      # Restore vim/nvim sessions
      set -g @resurrect-strategy-vim 'session'
      set -g @resurrect-strategy-nvim 'session'

      # Restore pane contents
      set -g @resurrect-capture-pane-contents 'on'

      # Restore additional programs
      set -g @resurrect-processes 'ssh psql mysql sqlite3 "git log" "~npm start" "~yarn start"'

      # Quick session save/restore
      bind-key C-s run-shell "tmux display-message 'Saving session...'; ~/.tmux/plugins/tmux-resurrect/scripts/save.sh"
      bind-key C-r run-shell "tmux display-message 'Restoring session...'; ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"

      # Status bar styling
      set -g status on
      set -g status-interval 1
      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'bg=#1e2030 fg=#82aaff'

      # Status left
      set -g status-left-length 30
      set -g status-left '#[bg=#3b4261,fg=#82aaff,bold] #S #[bg=#1e2030] '

      # Status right - with continuum status indicator
      set -g status-right-length 80
      set -g status-right '#[bg=#3b4261,fg=#82aaff] #{continuum_status} | %Y-%m-%d %H:%M '

      # Window status
      setw -g window-status-format '#[bg=#1e2030,fg=#828bb8] #I:#W '
      setw -g window-status-current-format '#[bg=#82aaff,fg=#1e2030,bold] #I:#W '

      # Pane borders
      set -g pane-border-style 'fg=#3b4261'
      set -g pane-active-border-style 'fg=#82aaff'

      # Messages
      set -g message-style 'bg=#82aaff,fg=#1e2030,bold'
    '';
  };
}
