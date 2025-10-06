# User Configuration Module for Nix
#
# This module imports user-specific configuration from the interactive setup
# and applies it to the Home Manager configuration.

{ config, lib, pkgs, ... }:

let
  # Try to import user configuration if it exists
  userConfigFile = "${config.home.homeDirectory}/.config/dotfiles/user.nix";

  # Default configuration
  defaultConfig = {
    username = config.home.username or "user";

    git = {
      userName = "Your Name";
      userEmail = "you@example.com";
    };

    shell = {
      default = "bash";
      editor = "vim";
    };

    environment = {
      timezone = "UTC";
    };
  };

  # Load user config if it exists, otherwise use defaults
  userConfig =
    if builtins.pathExists userConfigFile
    then import userConfigFile
    else defaultConfig;

in {
  # Apply user configuration
  config = {
    # Git configuration
    programs.git = {
      userName = userConfig.git.userName;
      userEmail = userConfig.git.userEmail;
      signing = lib.mkIf (userConfig.git ? signingKey) {
        signByDefault = true;
        key = userConfig.git.signingKey;
      };
    };

    # Shell configuration
    home.sessionVariables = {
      EDITOR = userConfig.shell.editor;
      TZ = userConfig.environment.timezone;
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