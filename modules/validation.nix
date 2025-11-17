{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Build-time validation assertions to catch configuration errors early
  # These assertions run during 'nix build' or 'home-manager switch', not at runtime

  config.assertions = [
    # Validate that environment variable file configurations reference installed packages
    {
      assertion =
        let
          hasRipgrep = lib.any (p: lib.hasPrefix "ripgrep" (p.name or "")) config.home.packages;
          hasRipgrepConfig = config.home.file ? ".config/ripgrep/config";
        in
        hasRipgrepConfig -> hasRipgrep;
      message = "Ripgrep configuration file defined but ripgrep is not in home.packages";
    }

    # Validate tool integrations match enabled programs
    {
      assertion =
        config.programs.starship.enable
        -> (
          config.programs.starship.enableBashIntegration || config.programs.starship.enableZshIntegration
        );
      message = "Starship is enabled but no shell integrations are active. Enable at least one shell integration.";
    }

    {
      assertion =
        config.programs.zoxide.enable
        -> (config.programs.zoxide.enableBashIntegration || config.programs.zoxide.enableZshIntegration);
      message = "Zoxide is enabled but no shell integrations are active. Enable at least one shell integration.";
    }

    {
      assertion =
        config.programs.atuin.enable
        -> (config.programs.atuin.enableBashIntegration || config.programs.atuin.enableZshIntegration);
      message = "Atuin is enabled but no shell integrations are active. Enable at least one shell integration.";
    }

    {
      assertion =
        config.programs.fzf.enable
        -> (config.programs.fzf.enableBashIntegration || config.programs.fzf.enableZshIntegration);
      message = "FZF is enabled but no shell integrations are active. Enable at least one shell integration.";
    }

    {
      assertion =
        config.programs.direnv.enable
        -> (config.programs.direnv.enableBashIntegration || config.programs.direnv.enableZshIntegration);
      message = "Direnv is enabled but no shell integrations are active. Enable at least one shell integration.";
    }

    # Validate XDG directories are properly configured
    {
      assertion = config.xdg.enable;
      message = "XDG base directory support should be enabled for proper directory organization";
    }

    # Validate session variables reference valid paths
    {
      assertion =
        let
          javaHomeSet = config.home.sessionVariables ? "JAVA_HOME";
          javaInPackages = lib.any (p: lib.hasInfix "jdk" (p.name or "")) config.home.packages;
        in
        javaHomeSet -> javaInPackages;
      message = "JAVA_HOME environment variable set but no JDK package found in home.packages";
    }

    # Validate Go environment consistency
    {
      assertion =
        let
          goPathSet = config.home.sessionVariables ? "GOPATH";
          goInPath = lib.any (path: lib.hasInfix "/go/bin" path) config.home.sessionPath;
        in
        goPathSet -> goInPath;
      message = "GOPATH is set but Go bin directory is not in sessionPath. Add ${config.home.homeDirectory}/go/bin to sessionPath.";
    }

    # Validate Cargo/Rust environment consistency
    {
      assertion =
        let
          cargoHomeSet = config.home.sessionVariables ? "CARGO_HOME";
          cargoInPath = lib.any (path: lib.hasInfix "/.cargo/bin" path) config.home.sessionPath;
        in
        cargoHomeSet -> cargoInPath;
      message = "CARGO_HOME is set but Cargo bin directory is not in sessionPath. Add ${config.home.homeDirectory}/.cargo/bin to sessionPath.";
    }

    # Validate NPM environment consistency
    {
      assertion =
        let
          npmPrefixSet = config.home.sessionVariables ? "NPM_CONFIG_PREFIX";
          npmInPath = lib.any (path: lib.hasInfix ".npm-global" path) config.home.sessionPath;
        in
        npmPrefixSet -> npmInPath;
      message = "NPM_CONFIG_PREFIX is set but NPM global bin directory is not in sessionPath. Add ${config.home.homeDirectory}/.npm-global/bin to sessionPath.";
    }

    # Validate tmux is configured if tmux package or program is enabled
    {
      assertion =
        let
          tmuxPackage = lib.any (p: lib.hasPrefix "tmux" (p.name or "")) config.home.packages;
          tmuxProgram = config.programs.tmux.enable or false;
        in
        tmuxPackage -> tmuxProgram;
      message = "Tmux package installed but programs.tmux not enabled. Enable programs.tmux for proper configuration.";
    }

    # Validate neovim/vim configuration consistency
    {
      assertion =
        let
          nvimPackage = lib.any (p: lib.hasPrefix "neovim" (p.name or "")) config.home.packages;
          nvimProgram = config.programs.neovim.enable or false;
        in
        nvimPackage -> nvimProgram;
      message = "Neovim package installed but programs.neovim not enabled. Enable programs.neovim for proper configuration.";
    }
  ];

  # Validation warnings (non-fatal, just informational)
  config.warnings = [
    # Warn if using deprecated packages or patterns
    (lib.mkIf (lib.any (p: p.name or "" == "thefuck") config.home.packages)
      "Package 'thefuck' may be incompatible with Python 3.12+. Consider removing or using alternative."
    )

    # Warn about potential PATH ordering issues
    (lib.mkIf (
      lib.elem "${config.home.homeDirectory}/.local/bin" config.home.sessionPath
      && lib.elem "${config.home.homeDirectory}/bin" config.home.sessionPath
      && (lib.elemAt config.home.sessionPath 0) != "${config.home.homeDirectory}/bin"
    ) "Personal bin directory (~/bin) should typically be first in PATH for user script precedence.")
  ];
}
