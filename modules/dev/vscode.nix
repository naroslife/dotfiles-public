{ config, pkgs, lib, ... }:
{
  programs.vscode = {
    enable = true;

    # User settings
    profiles.default.userSettings = {
      # Editor settings
      "editor.fontFamily" = "'FiraCode Nerd Font', 'MesloLGS NF', 'Cascadia Code', monospace";
      "editor.fontSize" = 14;
      "editor.fontLigatures" = true;
      "editor.tabSize" = 2;
      "editor.insertSpaces" = true;
      "editor.detectIndentation" = true;
      "editor.renderWhitespace" = "selection";
      "editor.rulers" = [ 80 120 ];
      "editor.wordWrap" = "off";
      "editor.formatOnSave" = true;
      "editor.formatOnPaste" = false;
      "editor.suggestSelection" = "first";
      "editor.snippetSuggestions" = "top";
      "editor.cursorBlinking" = "smooth";
      "editor.smoothScrolling" = true;
      "editor.minimap.enabled" = true;
      "editor.minimap.maxColumn" = 80;
      "editor.bracketPairColorization.enabled" = true;
      "editor.inlineSuggest.enabled" = true;
      "editor.stickyScroll.enabled" = true;

      # Terminal settings
      "terminal.integrated.fontFamily" = "'FiraCode Nerd Font', 'MesloLGS NF', monospace";
      "terminal.integrated.fontSize" = 14;
      "terminal.integrated.cursorStyle" = "line";
      "terminal.integrated.cursorBlinking" = true;
      "terminal.integrated.defaultProfile.linux" = "bash";
      "terminal.integrated.persistentSessionReviveProcess" = "never";
      "terminal.integrated.enableMultiLinePasteWarning" = false;

      # File settings
      "files.autoSave" = "afterDelay";
      "files.autoSaveDelay" = 1000;
      "files.trimTrailingWhitespace" = true;
      "files.trimFinalNewlines" = true;
      "files.insertFinalNewline" = true;
      "files.exclude" = {
        "**/.git" = true;
        "**/.svn" = true;
        "**/.hg" = true;
        "**/CVS" = true;
        "**/.DS_Store" = true;
        "**/Thumbs.db" = true;
        "**/node_modules" = true;
        "**/__pycache__" = true;
        "**/.pytest_cache" = true;
        "**/target" = true;
        "**/result" = true;
        "**/result-*" = true;
      };

      # Search settings
      "search.exclude" = {
        "**/node_modules" = true;
        "**/bower_components" = true;
        "**/*.code-search" = true;
        "**/target" = true;
        "**/build" = true;
        "**/dist" = true;
        "**/.git" = true;
        "**/.history" = true;
      };

      # Git settings
      "git.enableSmartCommit" = true;
      "git.confirmSync" = false;
      "git.autofetch" = true;
      "git.defaultCloneDirectory" = "~/repos";

      # Language-specific settings
      "[python]" = {
        "editor.tabSize" = 4;
        "editor.defaultFormatter" = "ms-python.black-formatter";
      };

      "[javascript][typescript][javascriptreact][typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.tabSize" = 2;
      };

      "[json][jsonc]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.tabSize" = 2;
      };

      "[yaml]" = {
        "editor.tabSize" = 2;
        "editor.autoIndent" = "advanced";
      };

      "[markdown]" = {
        "editor.wordWrap" = "on";
        "editor.quickSuggestions" = {
          "comments" = "off";
          "strings" = "off";
          "other" = "off";
        };
      };

      "[nix]" = {
        "editor.tabSize" = 2;
        "editor.defaultFormatter" = "kamadorueda.alejandra";
      };

      "[rust]" = {
        "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        "editor.tabSize" = 4;
      };

      # Workbench settings
      "workbench.colorTheme" = "Monokai";
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.startupEditor" = "none";
      "workbench.editor.enablePreview" = false;
      "workbench.editor.enablePreviewFromQuickOpen" = true;
      "workbench.sideBar.location" = "left";
      "workbench.activityBar.visible" = true;
      "workbench.tree.indent" = 16;

      # Extension settings
      "extensions.ignoreRecommendations" = false;
      "extensions.autoUpdate" = true;

      # Telemetry
      "telemetry.telemetryLevel" = "off";

      # Security
      "security.workspace.trust.untrustedFiles" = "prompt";

      # Remote development
      "remote.SSH.remotePlatform" = {
        "*" = "linux";
      };

      # Custom settings from original
      "evo.excecutable" = "./evo.sh";

      # Additional productivity settings
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "explorer.compactFolders" = false;

      # Better defaults
      "diffEditor.ignoreTrimWhitespace" = false;
      "merge-conflict.autoNavigateNextConflict.enabled" = true;

      # Performance
      "search.followSymlinks" = false;
      "files.watcherExclude" = {
        "**/.git/objects/**" = true;
        "**/.git/subtree-cache/**" = true;
        "**/node_modules/**" = true;
        "**/.hg/store/**" = true;
      };
    };

    # VS Code extensions
    profiles.default.extensions = with pkgs.vscode-extensions; [
      # General development
      editorconfig.editorconfig
      streetsidesoftware.code-spell-checker
      christian-kohler.path-intellisense
      gruntfuggly.todo-tree
      usernamehw.errorlens

      # Git
      eamodio.gitlens
      donjayamanne.githistory
      mhutchie.git-graph

      # Themes and icons
      pkief.material-icon-theme

      # Language support
      ms-python.python
      ms-python.vscode-pylance
      ms-python.black-formatter
      rust-lang.rust-analyzer
      golang.go
      hashicorp.terraform
      redhat.vscode-yaml
      timonwong.shellcheck
      foxundermoon.shell-format

      # Nix
      jnoortheen.nix-ide
      kamadorueda.alejandra

      # Containers
      ms-azuretools.vscode-docker
      ms-kubernetes-tools.vscode-kubernetes-tools

      # Remote development
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers
      ms-vscode.remote-explorer

      # Formatters
      esbenp.prettier-vscode

      # Markdown
      yzhang.markdown-all-in-one
      bierner.markdown-mermaid

      # AI assistants (optional)
      github.copilot
      github.copilot-chat

      # Additional productivity
      vscodevim.vim
      formulahendry.auto-rename-tag
      naumovs.color-highlight
    ] ++ pkgs.lib.optionals (pkgs.stdenv.isDarwin) [
      # macOS-specific extensions
    ] ++ pkgs.lib.optionals (pkgs.stdenv.isLinux) [
      # Linux-specific extensions
      ms-vscode.cpptools
    ];

    # Keybindings
    profiles.default.keybindings = [
      {
        key = "ctrl+shift+/";
        command = "editor.action.blockComment";
        when = "editorTextFocus";
      }
      {
        key = "ctrl+d";
        command = "editor.action.deleteLines";
        when = "editorTextFocus";
      }
      {
        key = "ctrl+shift+d";
        command = "editor.action.copyLinesDownAction";
        when = "editorTextFocus";
      }
      {
        key = "alt+up";
        command = "editor.action.moveLinesUpAction";
        when = "editorTextFocus";
      }
      {
        key = "alt+down";
        command = "editor.action.moveLinesDownAction";
        when = "editorTextFocus";
      }
    ];
  };
}
