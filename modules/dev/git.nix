{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # === Version Control & Git Tools ===
    git
    git-lfs
    lazygit # Terminal UI for git commands
    delta # Syntax-highlighting pager for git diffs
    difftastic # Structural diff that understands syntax trees
    gitui # Blazing fast terminal-ui for git
    gh # GitHub CLI for managing PRs, issues, etc.
    git-absorb # Automatically absorb staged changes into your recent commits

    # Additional useful git tools
    git-crypt # Transparent file encryption in git
    git-filter-repo # Quickly rewrite git repository history
    gitleaks # Detect secrets in git repos
    pre-commit # Framework for managing git hooks
  ];

  programs.git = {
    enable = true;
    # Note: userName and userEmail are set by the flake configuration

    # Aliases for common operations
    aliases = {
      # Basic shortcuts
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      unstage = "reset HEAD --";

      # Pretty logs
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      ll = "log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]' --decorate --numstat";

      # Useful shortcuts
      last = "log -1 HEAD";
      visual = "!gitk";
      amend = "commit --amend --no-edit";
      undo = "reset HEAD~1 --mixed";

      # Show verbose output
      branches = "branch -vv";
      remotes = "remote -v";
      tags = "tag -l";

      # Workflow helpers
      wip = "!git add -A && git commit -m 'WIP: Work in progress'";
      unwip = "!git log -1 --pretty=%B | grep -q '^WIP' && git reset HEAD~1";

      # Find commits
      find = "!git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep";

      # Cleanup
      cleanup = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d";
      prune-branches = "!git remote prune origin && git branch -vv | grep ': gone]' | grep -v '\\*' | awk '{ print $1 }' | xargs -n 1 git branch -d";

      # GitHub integration
      pr = "!gh pr create";
      prs = "!gh pr list";
      issue = "!gh issue create";
      issues = "!gh issue list";
    };

    # Global git ignore patterns
    ignores = [
      # OS generated
      ".DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "ehthumbs.db"
      "Thumbs.db"

      # Editor directories
      ".idea/"
      ".vscode/"
      "*.swp"
      "*.swo"
      "*~"
      ".netrwhist"
      ".history"

      # Language specific
      "__pycache__/"
      "*.py[cod]"
      "*$py.class"
      "node_modules/"
      "*.log"
      ".env"
      ".env.local"

      # Build outputs
      "dist/"
      "build/"
      "target/"
      "out/"
      "*.o"
      "*.so"
      "*.exe"
      "*.dll"

      # Nix
      "result"
      "result-*"

      # Temporary files
      "*.tmp"
      "*.bak"
      "*.backup"
      ".cache/"

      # Secrets (very important!)
      "*.pem"
      "*.key"
      "*.crt"
      "*.p12"
      ".env*"
      "secrets/"
      "*-secret*"
      "*-private*"
    ];

    extraConfig = {
      core = {
        editor = "nvim";
        autocrlf = "input"; # WSL: Handle line endings properly
        safecrlf = true; # WSL: Warn about mixed line endings
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        filemode = false; # Better handling of file permissions
      };

      init = {
        defaultBranch = "main";
        templateDir = "~/.config/git/templates";
      };

      push = {
        autoSetupRemote = true;
        default = "simple";
        followTags = true;
      };

      pull = {
        rebase = false;
        ff = "only";
      };

      merge = {
        conflictstyle = "diff3";
        tool = "vimdiff";
        log = true;
      };

      rebase = {
        autoStash = true;
        autoSquash = true;
      };

      rerere = {
        enabled = true;
        autoUpdate = true;
      };

      diff = {
        colorMoved = "default";
        algorithm = "histogram";
        indentHeuristic = true;
      };

      status = {
        showUntrackedFiles = "all";
        submoduleSummary = true;
      };

      log = {
        date = "relative";
        decorate = true;
      };

      help = {
        autocorrect = 1;
      };

      color = {
        ui = "auto";
        diff = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red bold";
          new = "green bold";
        };
      };

      # URL rewrites for better security
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
        "git@gitlab.com:" = {
          insteadOf = "https://gitlab.com/";
        };
      };

      # Maintenance
      maintenance = {
        auto = false;
        strategy = "incremental";
      };

      # Signing commits (optional - uncomment if you have GPG set up)
      # commit.gpgsign = true;
      # tag.gpgsign = true;
      # gpg.program = "${pkgs.gnupg}/bin/gpg";
    };

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Monokai Extended";
        features = "decorations";

        # Better diff display
        plus-style = "syntax #003800";
        minus-style = "syntax #3f0001";

        # Decoration options
        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-decoration-style = "none";
          file-style = "bold yellow";
          hunk-header-decoration-style = "cyan box ul";
        };

        # Line numbers
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = "red";
        line-numbers-plus-style = "green";
        line-numbers-zero-style = "white";

        whitespace-error-style = "22 reverse";
      };
    };

    lfs = {
      enable = true;
    };
  };

  # Git hooks via pre-commit
  home.file.".config/git/hooks" = {
    source = pkgs.writeTextDir "hooks" ''
      # Global git hooks can be placed here
    '';
    recursive = true;
  };

  # Pre-commit configuration
  home.file.".pre-commit-config.yaml" = {
    text = ''
      # Global pre-commit configuration
      # Project-specific configs will override these
      default_stages: [commit]

      repos:
        - repo: https://github.com/pre-commit/pre-commit-hooks
          rev: v4.5.0
          hooks:
            - id: trailing-whitespace
            - id: end-of-file-fixer
            - id: check-yaml
            - id: check-added-large-files
            - id: check-merge-conflict
            - id: check-case-conflict
            - id: detect-private-key

        - repo: https://github.com/gitleaks/gitleaks
          rev: v8.18.0
          hooks:
            - id: gitleaks
    '';
  };
}
