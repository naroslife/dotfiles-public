# User Configuration Module for Nix
#
# This module imports user-specific configuration from the interactive setup
# and applies it to the Home Manager configuration.

{ config, lib, pkgs, ... }:

let
  # Try to import user configuration if it exists
  userConfigFile = "${config.home.homeDirectory}/.config/dotfiles/user.nix";

  # Default configuration using centralized defaults from config.dotfiles.defaults
  # Note: Only includes required fields. Optional fields like editor
  # should not have defaults here - let them fall through to environment.nix
  defaultConfig = {
    username = config.home.username or "user";

    git = {
      userName = config.dotfiles.defaults.git.userName;
      userEmail = config.dotfiles.defaults.git.userEmail;
    };

    shell = {
      default = config.dotfiles.defaults.shell.default;
      # No editor default - use environment.nix default
    };

    environment = {
      timezone = config.dotfiles.defaults.environment.timezone;
    };
  };

  # Load user config if it exists, otherwise use defaults
  userConfig =
    if builtins.pathExists userConfigFile
    then import userConfigFile
    else defaultConfig;

in
{
  # Define profile configuration option
  options.dotfiles.profile = lib.mkOption {
    type = lib.types.enum [ "auto" "fast" "balanced" "full" "agent" ];
    default = "auto";
    description = ''
      Shell profile to use:
      - auto: Detects context automatically (recommended)
      - fast: Minimal features for maximum speed
      - balanced: Optimized features (current default)
      - full: All features enabled, AI-aware
      - agent: POSIX-only tools for AI agents/automation
    '';
  };

  # Apply user configuration
  config = {
    # Git configuration
    # Use mkDefault so flake.nix per-user config can override
    programs.git = {
      userName = lib.mkDefault userConfig.git.userName;
      userEmail = lib.mkDefault userConfig.git.userEmail;
      signing = lib.mkIf (userConfig.git ? signingKey) {
        signByDefault = true;
        key = userConfig.git.signingKey;
      };
    };

    # Shell configuration
    home.sessionVariables = lib.optionalAttrs (userConfig.shell ? editor) {
      # Only set EDITOR if user explicitly configured it
      # Use mkOverride 900 to place between mkDefault (1000) and normal (100)
      # This allows flake.nix to override but still overrides environment.nix defaults
      EDITOR = lib.mkOverride 900 userConfig.shell.editor;
    } // {
      # Timezone uses mkDefault so it can be overridden
      TZ = lib.mkDefault userConfig.environment.timezone;
    } // lib.optionalAttrs (userConfig.environment ? httpProxy) {
      HTTP_PROXY = userConfig.environment.httpProxy;
      http_proxy = userConfig.environment.httpProxy;
    } // lib.optionalAttrs (userConfig.environment ? httpsProxy) {
      HTTPS_PROXY = userConfig.environment.httpsProxy;
      https_proxy = userConfig.environment.httpsProxy;
    } // lib.optionalAttrs (userConfig.environment ? noProxy) {
      NO_PROXY = userConfig.environment.noProxy;
      no_proxy = userConfig.environment.noProxy;
    } // lib.optionalAttrs (userConfig.environment ? corpTestIps) {
      CORP_TEST_IPS = userConfig.environment.corpTestIps;
    };

    # Default shell selection - don't override existing settings
    # These are just preferences, the actual shell configs are in modules/shells/

    # Editor configuration - don't override existing settings
    # The actual editor configs are managed elsewhere
  };
}
