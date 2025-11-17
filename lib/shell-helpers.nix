{lib}: rec {
  # Helper to generate shell integration attributes for common shells
  # Usage: mkShellIntegrations ["bash" "zsh"]
  # Returns: { enableBashIntegration = true; enableZshIntegration = true; }
  mkShellIntegrations = shells:
    lib.listToAttrs (
      map (
        shell: let
          # Capitalize first letter: bash -> Bash, zsh -> Zsh
          capitalized = lib.toUpper (lib.substring 0 1 shell) + lib.substring 1 (-1) shell;
        in {
          name = "enable${capitalized}Integration";
          value = true;
        }
      )
      shells
    );

  # Helper to enable a program with default shell integrations
  # Usage: withShells ["bash" "zsh"] { settings = { ... }; }
  # Returns: { enable = true; enableBashIntegration = true; enableZshIntegration = true; settings = { ... }; }
  withShells = shells: config: {enable = true;} // (mkShellIntegrations shells) // config;

  # Convenience function for programs with just enable + shell integrations
  # Usage: enableWithShells ["bash" "zsh"]
  # Returns: { enable = true; enableBashIntegration = true; enableZshIntegration = true; }
  enableWithShells = shells: {enable = true;} // (mkShellIntegrations shells);
}
